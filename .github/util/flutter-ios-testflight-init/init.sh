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

# Fastfile 생성
create_fastfile() {
    print_step "Fastfile 생성 중..."

    local fastlane_dir="$PROJECT_PATH/ios/fastlane"
    local fastfile_path="$fastlane_dir/Fastfile"

    cat > "$fastfile_path" << 'FASTFILE_EOF'
# ===================================================================
# Fastlane Fastfile - iOS 빌드 및 배포 자동화
# ===================================================================
#
# 사용법:
#   bundle exec fastlane deploy_testflight
#
# 필요한 환경변수 (GitHub Secrets):
#   - IOS_BUNDLE_ID: 앱 Bundle ID
#   - APPLE_TEAM_ID: Apple Developer Team ID
#   - IOS_PROVISIONING_PROFILE_NAME: Provisioning Profile 이름
#   - APP_STORE_CONNECT_API_KEY_ID: API Key ID
#   - APP_STORE_CONNECT_ISSUER_ID: Issuer ID
#   - API_KEY_PATH: API Key 파일 경로
#
# ===================================================================

default_platform(:ios)

platform :ios do

  # ─────────────────────────────────────────────────────────────────
  # TestFlight 배포 Lane
  # ─────────────────────────────────────────────────────────────────
  desc "TestFlight에 앱 업로드"
  lane :deploy_testflight do

    # 환경변수 검증
    UI.user_error!("IOS_BUNDLE_ID가 설정되지 않았습니다") unless ENV["IOS_BUNDLE_ID"]
    UI.user_error!("APPLE_TEAM_ID가 설정되지 않았습니다") unless ENV["APPLE_TEAM_ID"]
    UI.user_error!("IOS_PROVISIONING_PROFILE_NAME이 설정되지 않았습니다") unless ENV["IOS_PROVISIONING_PROFILE_NAME"]
    UI.user_error!("APP_STORE_CONNECT_API_KEY_ID가 설정되지 않았습니다") unless ENV["APP_STORE_CONNECT_API_KEY_ID"]
    UI.user_error!("APP_STORE_CONNECT_ISSUER_ID가 설정되지 않았습니다") unless ENV["APP_STORE_CONNECT_ISSUER_ID"]
    UI.user_error!("API_KEY_PATH가 설정되지 않았습니다") unless ENV["API_KEY_PATH"]

    UI.message("🚀 TestFlight 배포 시작")
    UI.message("   Bundle ID: #{ENV['IOS_BUNDLE_ID']}")
    UI.message("   Team ID: #{ENV['APPLE_TEAM_ID']}")
    UI.message("   Profile: #{ENV['IOS_PROVISIONING_PROFILE_NAME']}")

    # App Store Connect API Key 설정
    api_key = app_store_connect_api_key(
      key_id: ENV["APP_STORE_CONNECT_API_KEY_ID"],
      issuer_id: ENV["APP_STORE_CONNECT_ISSUER_ID"],
      key_filepath: ENV["API_KEY_PATH"],
      duration: 1200,
      in_house: false
    )

    # Archive 및 IPA 생성
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store",
      output_directory: "build/ipa",
      output_name: "Runner.ipa",
      clean: true,

      # 코드 서명 설정 (Runner 타겟에만 적용)
      export_options: {
        method: "app-store",
        teamID: ENV["APPLE_TEAM_ID"],
        signingStyle: "manual",
        signingCertificate: "Apple Distribution",
        provisioningProfiles: {
          ENV["IOS_BUNDLE_ID"] => ENV["IOS_PROVISIONING_PROFILE_NAME"]
        }
      },

      # xcargs로 빌드 설정 전달
      xcargs: "-allowProvisioningUpdates"
    )

    UI.success("✅ IPA 빌드 완료")

    # TestFlight 업로드
    upload_to_testflight(
      api_key: api_key,
      ipa: "build/ipa/Runner.ipa",
      changelog: ENV["RELEASE_NOTES"] || "새로운 빌드가 업로드되었습니다.",
      skip_waiting_for_build_processing: true,
      distribute_external: false,
      notify_external_testers: false,
      uses_non_exempt_encryption: false
    )

    UI.success("✅ TestFlight 업로드 완료!")
  end

  # ─────────────────────────────────────────────────────────────────
  # 빌드만 수행 (업로드 없음)
  # ─────────────────────────────────────────────────────────────────
  desc "IPA 빌드만 수행 (테스트용)"
  lane :build_only do

    UI.user_error!("IOS_BUNDLE_ID가 설정되지 않았습니다") unless ENV["IOS_BUNDLE_ID"]
    UI.user_error!("APPLE_TEAM_ID가 설정되지 않았습니다") unless ENV["APPLE_TEAM_ID"]
    UI.user_error!("IOS_PROVISIONING_PROFILE_NAME이 설정되지 않았습니다") unless ENV["IOS_PROVISIONING_PROFILE_NAME"]

    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store",
      output_directory: "build/ipa",
      output_name: "Runner.ipa",
      clean: true,
      export_options: {
        method: "app-store",
        teamID: ENV["APPLE_TEAM_ID"],
        signingStyle: "manual",
        signingCertificate: "Apple Distribution",
        provisioningProfiles: {
          ENV["IOS_BUNDLE_ID"] => ENV["IOS_PROVISIONING_PROFILE_NAME"]
        }
      }
    )

    UI.success("✅ IPA 빌드 완료: build/ipa/Runner.ipa")
  end

  # ─────────────────────────────────────────────────────────────────
  # 인증서 및 프로파일 정보 출력 (디버깅용)
  # ─────────────────────────────────────────────────────────────────
  desc "현재 설정된 환경변수 및 인증 정보 출력"
  lane :debug_info do
    UI.header("환경변수 정보")
    UI.message("IOS_BUNDLE_ID: #{ENV['IOS_BUNDLE_ID'] || '(not set)'}")
    UI.message("APPLE_TEAM_ID: #{ENV['APPLE_TEAM_ID'] || '(not set)'}")
    UI.message("IOS_PROVISIONING_PROFILE_NAME: #{ENV['IOS_PROVISIONING_PROFILE_NAME'] || '(not set)'}")
    UI.message("APP_STORE_CONNECT_API_KEY_ID: #{ENV['APP_STORE_CONNECT_API_KEY_ID'] || '(not set)'}")
    UI.message("APP_STORE_CONNECT_ISSUER_ID: #{ENV['APP_STORE_CONNECT_ISSUER_ID'] || '(not set)'}")
    UI.message("API_KEY_PATH: #{ENV['API_KEY_PATH'] || '(not set)'}")

    # 설치된 프로파일 확인
    UI.header("설치된 Provisioning Profiles")
    profiles_path = File.expand_path("~/Library/MobileDevice/Provisioning Profiles")
    if Dir.exist?(profiles_path)
      Dir.glob("#{profiles_path}/*.mobileprovision").each do |profile|
        UI.message("  - #{File.basename(profile)}")
      end
    else
      UI.important("Provisioning Profiles 디렉토리가 없습니다")
    end
  end

end
FASTFILE_EOF

    print_success "Fastfile 생성 완료: $fastfile_path"
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

# 완료 메시지
print_completion() {
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 Fastlane 설정 완료! 🎉                             ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}생성된 파일:${NC}"
    echo "  ✅ ios/Gemfile"
    echo "  ✅ ios/fastlane/Appfile"
    echo "  ✅ ios/fastlane/Fastfile"
    echo ""
    echo -e "${CYAN}설정된 정보:${NC}"
    echo "  • Bundle ID: $BUNDLE_ID"
    echo "  • Team ID: $TEAM_ID"
    echo "  • Profile Name: $PROFILE_NAME"
    echo ""
    echo -e "${YELLOW}다음 단계:${NC}"
    echo "  1. GitHub Secrets 설정 (마법사 Step 4 참고)"
    echo "  2. 변경사항 커밋:"
    echo "     git add ios/Gemfile ios/fastlane/"
    echo "     git commit -m \"chore: iOS Fastlane 설정 추가\""
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

    # 파일 생성
    create_gemfile
    create_appfile
    create_fastfile
    update_gitignore

    # 완료
    print_completion
}

# 스크립트 실행
main "$@"
