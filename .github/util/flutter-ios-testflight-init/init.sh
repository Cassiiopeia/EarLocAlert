#!/bin/bash

# ===================================================================
# Flutter iOS TestFlight 초기화 스크립트
# ===================================================================
#
# 이 스크립트는 Flutter 프로젝트에 iOS TestFlight 배포를 위한
# Fastlane 설정 파일들을 자동으로 생성합니다.
#
# 사용법:
#   ./init.sh PROJECT_PATH BUNDLE_ID TEAM_ID PROFILE_NAME
#
# 예시:
#   ./init.sh /Users/suh/projects/MyApp com.example.myapp ABC1234DEF "MyApp Distribution"
#
# 생성되는 파일:
#   - ios/Gemfile
#   - ios/fastlane/Appfile
#   - ios/fastlane/Fastfile
#
# ===================================================================

set -e  # 에러 발생 시 스크립트 중단

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 출력 함수
print_step() {
    echo -e "${CYAN}▶${NC} $1"
}

print_info() {
    echo -e "  ${BLUE}→${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# 도움말
show_help() {
    cat << EOF
${CYAN}Flutter iOS TestFlight 초기화 스크립트${NC}

${BLUE}사용법:${NC}
  ./init.sh PROJECT_PATH BUNDLE_ID TEAM_ID PROFILE_NAME

${BLUE}매개변수:${NC}
  PROJECT_PATH    Flutter 프로젝트 루트 경로
  BUNDLE_ID       iOS 앱 Bundle ID (예: com.example.myapp)
  TEAM_ID         Apple Developer Team ID (10자리)
  PROFILE_NAME    Provisioning Profile 이름

${BLUE}예시:${NC}
  ./init.sh /Users/suh/projects/MyApp com.example.myapp ABC1234DEF "MyApp Distribution"

${BLUE}생성되는 파일:${NC}
  - ios/Gemfile           Ruby 의존성 (Fastlane)
  - ios/fastlane/Appfile  앱 정보 설정
  - ios/fastlane/Fastfile 빌드 및 배포 설정

EOF
}

# 매개변수 검증
validate_params() {
    if [ "$#" -lt 4 ]; then
        print_error "매개변수가 부족합니다."
        echo ""
        show_help
        exit 1
    fi

    PROJECT_PATH="$1"
    BUNDLE_ID="$2"
    TEAM_ID="$3"
    PROFILE_NAME="$4"

    # 프로젝트 경로 확인
    if [ ! -d "$PROJECT_PATH" ]; then
        print_error "프로젝트 경로가 존재하지 않습니다: $PROJECT_PATH"
        exit 1
    fi

    # pubspec.yaml 확인 (Flutter 프로젝트)
    if [ ! -f "$PROJECT_PATH/pubspec.yaml" ]; then
        print_error "Flutter 프로젝트가 아닙니다 (pubspec.yaml 없음)"
        exit 1
    fi

    # ios 폴더 확인
    if [ ! -d "$PROJECT_PATH/ios" ]; then
        print_error "iOS 폴더가 없습니다. 'flutter create .' 명령을 먼저 실행하세요."
        exit 1
    fi

    # Bundle ID 형식 확인
    if [[ ! "$BUNDLE_ID" =~ \. ]]; then
        print_error "Bundle ID 형식이 올바르지 않습니다: $BUNDLE_ID"
        print_error "예시: com.example.myapp"
        exit 1
    fi

    # Team ID 길이 확인
    if [ ${#TEAM_ID} -ne 10 ]; then
        print_error "Team ID는 10자리여야 합니다: $TEAM_ID"
        exit 1
    fi
}

# 템플릿 디렉토리 찾기
find_template_dir() {
    # 스크립트 위치 기준
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    TEMPLATE_DIR="$SCRIPT_DIR/templates"

    if [ ! -d "$TEMPLATE_DIR" ]; then
        print_error "템플릿 디렉토리를 찾을 수 없습니다: $TEMPLATE_DIR"
        exit 1
    fi

    print_info "템플릿 디렉토리: $TEMPLATE_DIR"
}

# Gemfile 생성
create_gemfile() {
    print_step "Gemfile 생성 중..."

    local gemfile_path="$PROJECT_PATH/ios/Gemfile"

    # 기존 파일 백업
    if [ -f "$gemfile_path" ]; then
        print_warning "기존 Gemfile 백업: ${gemfile_path}.bak"
        cp "$gemfile_path" "${gemfile_path}.bak"
    fi

    cat > "$gemfile_path" << 'EOF'
# frozen_string_literal: true

source "https://rubygems.org"

# Fastlane - iOS 빌드 자동화
gem "fastlane", "~> 2.225"

# CocoaPods - iOS 의존성 관리
gem "cocoapods", "~> 1.15"
EOF

    print_success "Gemfile 생성 완료: $gemfile_path"
}

# Appfile 생성
create_appfile() {
    print_step "Appfile 생성 중..."

    local fastlane_dir="$PROJECT_PATH/ios/fastlane"
    local appfile_path="$fastlane_dir/Appfile"

    # fastlane 디렉토리 생성
    mkdir -p "$fastlane_dir"

    cat > "$appfile_path" << EOF
# ===================================================================
# Fastlane Appfile - 앱 정보 설정
# ===================================================================
#
# 이 파일은 환경변수를 통해 앱 정보를 설정합니다.
# GitHub Actions에서 Secrets를 통해 값이 주입됩니다.
#
# ===================================================================

# App Identifier (Bundle ID)
# GitHub Secret: IOS_BUNDLE_ID
app_identifier(ENV["IOS_BUNDLE_ID"] || "$BUNDLE_ID")

# Apple Developer Team ID
# GitHub Secret: APPLE_TEAM_ID
team_id(ENV["APPLE_TEAM_ID"] || "$TEAM_ID")

# App Store Connect Team ID (일반적으로 team_id와 동일)
# 여러 팀에 속한 경우에만 별도 설정 필요
# itc_team_id(ENV["ITC_TEAM_ID"])

# Apple ID (App Store Connect API Key 사용 시 불필요)
# apple_id(ENV["APPLE_ID"])
EOF

    print_success "Appfile 생성 완료: $appfile_path"
}

# Fastfile 생성 (템플릿에서 복사)
create_fastfile() {
    print_step "Fastfile 생성 중..."

    local fastlane_dir="$PROJECT_PATH/ios/fastlane"
    local fastfile_path="$fastlane_dir/Fastfile"
    local template_fastfile="$TEMPLATE_DIR/Fastfile"

    # 템플릿 파일 존재 확인
    if [ ! -f "$template_fastfile" ]; then
        print_error "Fastfile 템플릿을 찾을 수 없습니다: $template_fastfile"
        exit 1
    fi

    # 템플릿에서 복사
    cp "$template_fastfile" "$fastfile_path"

    print_success "Fastfile 생성 완료: $fastfile_path"
    print_info "  → 템플릿에서 복사됨: $template_fastfile"
}

# .gitignore 업데이트 (선택사항)
update_gitignore() {
    print_step ".gitignore 확인 중..."

    local gitignore_path="$PROJECT_PATH/ios/.gitignore"

    # Gemfile.lock은 일반적으로 커밋하지 않음
    if [ -f "$gitignore_path" ]; then
        if ! grep -q "Gemfile.lock" "$gitignore_path"; then
            echo "" >> "$gitignore_path"
            echo "# Fastlane" >> "$gitignore_path"
            echo "Gemfile.lock" >> "$gitignore_path"
            print_info "Gemfile.lock을 .gitignore에 추가했습니다"
        fi
    fi

    print_success ".gitignore 확인 완료"
}

# Xcode 프로젝트에 DEVELOPMENT_TEAM 및 Manual Signing 추가 (CI 빌드에 필수)
patch_xcode_project() {
    print_step "Xcode 프로젝트에 DEVELOPMENT_TEAM 및 Manual Signing 설정 중..."

    local pbxproj_path="$PROJECT_PATH/ios/Runner.xcodeproj/project.pbxproj"

    if [ ! -f "$pbxproj_path" ]; then
        print_error "project.pbxproj 파일을 찾을 수 없습니다: $pbxproj_path"
        return 1
    fi

    # 백업 생성
    cp "$pbxproj_path" "${pbxproj_path}.bak"
    print_info "백업 생성: ${pbxproj_path}.bak"

    # 이미 DEVELOPMENT_TEAM이 있는지 확인
    if grep -q "DEVELOPMENT_TEAM = $TEAM_ID" "$pbxproj_path"; then
        print_info "DEVELOPMENT_TEAM이 이미 설정되어 있습니다"
        # CODE_SIGN_STYLE도 확인하고 필요시 추가
        if ! grep -q "CODE_SIGN_STYLE = Manual" "$pbxproj_path"; then
            print_info "CODE_SIGN_STYLE = Manual 추가 중..."
            # Automatic을 Manual로 변경하거나 새로 추가
            if grep -q "CODE_SIGN_STYLE = Automatic" "$pbxproj_path"; then
                sed -i '' "s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g" "$pbxproj_path"
            else
                # DEVELOPMENT_TEAM 라인 다음에 CODE_SIGN_STYLE 추가
                sed -i '' "s/DEVELOPMENT_TEAM = $TEAM_ID;/DEVELOPMENT_TEAM = $TEAM_ID;\\
				CODE_SIGN_STYLE = Manual;/g" "$pbxproj_path"
            fi
            print_success "CODE_SIGN_STYLE = Manual 설정 완료"
        fi
        rm "${pbxproj_path}.bak"
        print_success "Xcode 프로젝트 확인 완료"
        return 0
    fi

    # DEVELOPMENT_TEAM이 있지만 다른 값이면 교체
    if grep -q "DEVELOPMENT_TEAM = " "$pbxproj_path"; then
        print_info "기존 DEVELOPMENT_TEAM 값을 업데이트합니다"
        sed -i '' "s/DEVELOPMENT_TEAM = [^;]*;/DEVELOPMENT_TEAM = $TEAM_ID;/g" "$pbxproj_path"
        print_success "DEVELOPMENT_TEAM 업데이트 완료"
        
        # CODE_SIGN_STYLE = Manual 설정
        if grep -q "CODE_SIGN_STYLE = Automatic" "$pbxproj_path"; then
            sed -i '' "s/CODE_SIGN_STYLE = Automatic;/CODE_SIGN_STYLE = Manual;/g" "$pbxproj_path"
            print_success "CODE_SIGN_STYLE = Manual 설정 완료"
        elif ! grep -q "CODE_SIGN_STYLE = Manual" "$pbxproj_path"; then
            sed -i '' "s/DEVELOPMENT_TEAM = $TEAM_ID;/DEVELOPMENT_TEAM = $TEAM_ID;\\
				CODE_SIGN_STYLE = Manual;/g" "$pbxproj_path"
            print_success "CODE_SIGN_STYLE = Manual 추가 완료"
        fi
        
        # CODE_SIGN_IDENTITY 설정
        if ! grep -q 'CODE_SIGN_IDENTITY = "Apple Distribution"' "$pbxproj_path"; then
            sed -i '' "s/CODE_SIGN_STYLE = Manual;/CODE_SIGN_STYLE = Manual;\\
				CODE_SIGN_IDENTITY = \"Apple Distribution\";/g" "$pbxproj_path"
            print_success "CODE_SIGN_IDENTITY = Apple Distribution 추가 완료"
        fi
        
        # PROVISIONING_PROFILE_SPECIFIER 설정 (핵심!)
        if ! grep -q "PROVISIONING_PROFILE_SPECIFIER" "$pbxproj_path"; then
            sed -i '' "s/CODE_SIGN_IDENTITY = \"Apple Distribution\";/CODE_SIGN_IDENTITY = \"Apple Distribution\";\\
				\"PROVISIONING_PROFILE_SPECIFIER\" = \"$PROFILE_NAME\";/g" "$pbxproj_path"
            print_success "PROVISIONING_PROFILE_SPECIFIER = $PROFILE_NAME 추가 완료"
        else
            # 기존 값이 있으면 업데이트
            sed -i '' "s/\"PROVISIONING_PROFILE_SPECIFIER\" = \"[^\"]*\";/\"PROVISIONING_PROFILE_SPECIFIER\" = \"$PROFILE_NAME\";/g" "$pbxproj_path"
            print_success "PROVISIONING_PROFILE_SPECIFIER 업데이트 완료"
        fi
        
        # 구버전 CODE_SIGN_IDENTITY 설정 업데이트
        if grep -q '"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer"' "$pbxproj_path"; then
            sed -i '' 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer"/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"/g' "$pbxproj_path"
            print_success "CODE_SIGN_IDENTITY[sdk=iphoneos*] 업데이트 완료"
        fi
        
        rm "${pbxproj_path}.bak"
        return 0
    fi

    # Runner 타겟의 buildSettings에 DEVELOPMENT_TEAM 추가
    # PRODUCT_BUNDLE_IDENTIFIER 라인 다음에 추가
    print_info "DEVELOPMENT_TEAM 추가 중..."

    # 입력한 Bundle ID가 project.pbxproj에 존재하는지 먼저 확인
    if ! grep -q "PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;" "$pbxproj_path"; then
        print_error "Bundle ID를 project.pbxproj에서 찾을 수 없습니다!"
        echo ""
        print_error "┌─────────────────────────────────────────────────────────────────┐"
        print_error "│ 입력한 Bundle ID: $BUNDLE_ID"
        print_error "├─────────────────────────────────────────────────────────────────┤"
        print_error "│ project.pbxproj에 존재하는 Bundle ID들:"
        # 실제 존재하는 Bundle ID 목록 출력
        grep "PRODUCT_BUNDLE_IDENTIFIER = " "$pbxproj_path" | sed 's/.*= /  • /' | sed 's/;$//' | sort -u | while read line; do
            print_error "│ $line"
        done
        print_error "└─────────────────────────────────────────────────────────────────┘"
        echo ""
        print_error "해결 방법:"
        print_info "1. 위 목록에서 정확한 Bundle ID를 확인하세요 (대소문자 구분!)"
        print_info "2. 올바른 Bundle ID로 스크립트를 다시 실행하세요"
        print_info "   예: ./init.sh \"$PROJECT_PATH\" \"정확한.번들.아이디\" \"$TEAM_ID\" \"$PROFILE_NAME\""
        mv "${pbxproj_path}.bak" "$pbxproj_path"
        return 1
    fi

    # macOS sed 사용 (BSD sed)
    # Runner 앱의 Bundle ID 라인 다음에 Manual Signing 관련 설정 모두 추가
    # - DEVELOPMENT_TEAM: Apple 팀 ID
    # - CODE_SIGN_STYLE: Manual (자동 서명 비활성화)
    # - CODE_SIGN_IDENTITY: Apple Distribution (배포용 인증서)
    # - PROVISIONING_PROFILE_SPECIFIER: 프로비저닝 프로파일 이름
    sed -i '' "s/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;\\
				DEVELOPMENT_TEAM = $TEAM_ID;\\
				CODE_SIGN_STYLE = Manual;\\
				CODE_SIGN_IDENTITY = \"Apple Distribution\";\\
				\"PROVISIONING_PROFILE_SPECIFIER\" = \"$PROFILE_NAME\";/g" "$pbxproj_path"

    # 구버전 CODE_SIGN_IDENTITY 설정이 있으면 Apple Distribution으로 변경
    if grep -q '"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer"' "$pbxproj_path"; then
        sed -i '' 's/"CODE_SIGN_IDENTITY\[sdk=iphoneos\*\]" = "iPhone Developer"/"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution"/g' "$pbxproj_path"
        print_success "CODE_SIGN_IDENTITY[sdk=iphoneos*] 업데이트 완료"
    fi

    # 변경 확인
    if grep -q "DEVELOPMENT_TEAM = $TEAM_ID" "$pbxproj_path" && grep -q "CODE_SIGN_STYLE = Manual" "$pbxproj_path"; then
        print_success "DEVELOPMENT_TEAM 추가 완료: $TEAM_ID"
        print_success "CODE_SIGN_STYLE = Manual 설정 완료"
        rm "${pbxproj_path}.bak"
    else
        print_error "DEVELOPMENT_TEAM 또는 CODE_SIGN_STYLE 추가 실패!"
        echo ""
        print_error "디버그 정보:"
        print_info "  • 입력한 Bundle ID: $BUNDLE_ID"
        print_info "  • 입력한 Team ID: $TEAM_ID"
        print_info "  • project.pbxproj 경로: $pbxproj_path"
        echo ""
        print_error "가능한 원인:"
        print_info "  1. sed 명령어 실행 중 오류 발생"
        print_info "  2. 파일 쓰기 권한 문제"
        echo ""
        print_warning "수동 설정 방법:"
        print_info "  Xcode 열기 → Runner 타겟 → Signing & Capabilities → Team 선택"
        mv "${pbxproj_path}.bak" "$pbxproj_path"
        return 1
    fi

    print_success "Xcode 프로젝트 설정 완료 (Manual Signing 적용됨)"
}

# 완료 메시지
print_completion() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 Fastlane 설정 완료! 🎉                             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}생성/수정된 파일:${NC}"
    echo "  ✅ ios/Gemfile"
    echo "  ✅ ios/fastlane/Appfile"
    echo "  ✅ ios/fastlane/Fastfile (Manual Signing 설정 포함)"
    echo "  ✅ ios/Runner.xcodeproj/project.pbxproj (DEVELOPMENT_TEAM + CODE_SIGN_STYLE=Manual)"
    echo ""
    echo -e "${CYAN}설정된 정보:${NC}"
    echo "  • Bundle ID: $BUNDLE_ID"
    echo "  • Team ID: $TEAM_ID"
    echo "  • Profile Name: $PROFILE_NAME"
    echo "  • Code Sign Style: Manual (CI 환경 최적화)"
    echo ""
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "  1. GitHub Secrets 설정 (마법사 Step 4 참고)"
    echo "  2. 변경사항 커밋:"
    echo "     git add ios/Gemfile ios/fastlane/ ios/Runner.xcodeproj/project.pbxproj"
    echo "     git commit -m \"chore: iOS Fastlane 및 코드 서명 설정 추가\""
    echo "  3. deploy 브랜치로 푸시하여 빌드 테스트"
    echo ""
}

# ===================================================================
# 메인 실행
# ===================================================================

main() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║       Flutter iOS TestFlight 초기화 스크립트                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""

    # 도움말 옵션 확인
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        show_help
        exit 0
    fi

    # 매개변수 검증
    validate_params "$@"

    echo -e "${BLUE}프로젝트 경로:${NC} $PROJECT_PATH"
    echo -e "${BLUE}Bundle ID:${NC} $BUNDLE_ID"
    echo -e "${BLUE}Team ID:${NC} $TEAM_ID"
    echo -e "${BLUE}Profile Name:${NC} $PROFILE_NAME"
    echo ""

    # 템플릿 디렉토리 찾기
    find_template_dir

    # 파일 생성
    create_gemfile
    create_appfile
    create_fastfile
    update_gitignore
    patch_xcode_project

    # 완료
    print_completion
}

# 스크립트 실행
main "$@"
