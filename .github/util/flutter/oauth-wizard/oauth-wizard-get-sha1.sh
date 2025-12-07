#!/bin/bash
# =============================================================================
# OAuth 설정 마법사 - SHA-1 인증서 지문 생성 스크립트
# =============================================================================
# 이 스크립트는 Android Keystore에서 SHA-1 인증서 지문을 추출합니다.
# 카카오 키 해시 및 Google/Firebase SHA-1 지문 생성에 사용됩니다.
# Debug keystore 자동 생성 및 Release keystore 생성 옵션 지원
# Usage: bash oauth-wizard-get-sha1.sh [keystore_type] [keystore_path] [alias] [password]
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get parameters
KEYSTORE_TYPE="${1:-}"
KEYSTORE_PATH="${2:-}"
KEY_ALIAS="${3:-}"
KEYSTORE_PASSWORD="${4:-}"

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if keytool is available
if ! command -v keytool &> /dev/null; then
    print_error "keytool을 찾을 수 없습니다."
    echo ""
    echo "Java JDK가 설치되어 있는지 확인하세요:"
    echo "  Mac: brew install openjdk"
    echo "  Linux: sudo apt-get install default-jdk"
    exit 1
fi

# Function to create debug keystore
create_debug_keystore() {
    local debug_keystore_path="$HOME/.android/debug.keystore"
    local debug_dir="$HOME/.android"
    
    # Create .android directory if it doesn't exist
    if [ ! -d "$debug_dir" ]; then
        mkdir -p "$debug_dir"
        print_info ".android 디렉토리 생성: $debug_dir"
    fi
    
    # Check if debug keystore already exists
    if [ -f "$debug_keystore_path" ]; then
        print_info "Debug keystore가 이미 존재합니다: $debug_keystore_path"
        return 0
    fi
    
    print_info "Debug keystore 생성 중..."
    
    # Create debug keystore with standard Android debug credentials
    keytool -genkey -v \
        -keystore "$debug_keystore_path" \
        -alias androiddebugkey \
        -storepass android \
        -keypass android \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "CN=Android Debug,O=Android,C=US" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Debug keystore 생성 완료: $debug_keystore_path"
        # Set permissions (read/write for owner only)
        chmod 600 "$debug_keystore_path"
        return 0
    else
        print_error "Debug keystore 생성 실패"
        return 1
    fi
}

# Function to create release keystore
create_release_keystore() {
    local keystore_path="$1"
    local alias="$2"
    local password="$3"
    
    print_info "Release keystore 생성 중..."
    echo ""
    
    # Get certificate information
    local cn="${4:-Unknown}"
    local o="${5:-Unknown}"
    local l="${6:-Unknown}"
    local c="${7:-KR}"
    local dname="CN=${cn}, O=${o}, L=${l}, C=${c}"
    
    # Create directory if it doesn't exist
    local keystore_dir=$(dirname "$keystore_path")
    if [ ! -d "$keystore_dir" ]; then
        mkdir -p "$keystore_dir"
        print_info "디렉토리 생성: $keystore_dir"
    fi
    
    # Create release keystore
    keytool -genkey -v \
        -keystore "$keystore_path" \
        -alias "$alias" \
        -storepass "$password" \
        -keypass "$password" \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -dname "$dname" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        print_success "Release keystore 생성 완료: $keystore_path"
        # Set permissions (read/write for owner only)
        chmod 600 "$keystore_path"
        return 0
    else
        print_error "Release keystore 생성 실패"
        return 1
    fi
}

# Keystore type selection
if [ -z "$KEYSTORE_TYPE" ]; then
    echo ""
    print_info "Keystore 타입을 선택하세요:"
    echo "  1) Debug keystore (개발/테스트용, 자동 생성)"
    echo "  2) Release keystore (배포용)"
    echo ""
    read -p "선택 (1 또는 2): " KEYSTORE_TYPE
    
    if [ "$KEYSTORE_TYPE" != "1" ] && [ "$KEYSTORE_TYPE" != "2" ]; then
        print_error "잘못된 선택입니다."
        exit 1
    fi
fi

# Handle Debug keystore
if [ "$KEYSTORE_TYPE" = "1" ] || [ "$KEYSTORE_TYPE" = "debug" ] || [ "$KEYSTORE_TYPE" = "Debug" ]; then
    KEYSTORE_TYPE="debug"
    KEYSTORE_PATH="$HOME/.android/debug.keystore"
    KEY_ALIAS="androiddebugkey"
    KEYSTORE_PASSWORD="android"
    
    # Create debug keystore if it doesn't exist
    if [ ! -f "$KEYSTORE_PATH" ]; then
        if ! create_debug_keystore; then
            exit 1
        fi
    fi
    
    print_info "Debug keystore 사용: $KEYSTORE_PATH"
    
# Handle Release keystore
elif [ "$KEYSTORE_TYPE" = "2" ] || [ "$KEYSTORE_TYPE" = "release" ] || [ "$KEYSTORE_TYPE" = "Release" ]; then
    KEYSTORE_TYPE="release"
    
    # Get keystore path
    if [ -z "$KEYSTORE_PATH" ]; then
        echo ""
        print_info "Release keystore 파일 경로를 입력하세요:"
        echo "  예시: android/app/keystore/key.jks"
        read -p "Keystore 경로: " KEYSTORE_PATH
    fi
    
    # Expand ~ to home directory
    KEYSTORE_PATH="${KEYSTORE_PATH/#\~/$HOME}"
    
    # Check if keystore exists, if not, ask to create
    if [ ! -f "$KEYSTORE_PATH" ]; then
        echo ""
        print_warning "Keystore 파일을 찾을 수 없습니다: $KEYSTORE_PATH"
        read -p "새로 생성하시겠습니까? (y/n): " CREATE_KEYSTORE
        
        if [ "$CREATE_KEYSTORE" = "y" ] || [ "$CREATE_KEYSTORE" = "Y" ]; then
            # Get alias
            if [ -z "$KEY_ALIAS" ]; then
                read -p "Key alias (기본값: release-key): " KEY_ALIAS
                KEY_ALIAS="${KEY_ALIAS:-release-key}"
            fi
            
            # Get password
            if [ -z "$KEYSTORE_PASSWORD" ]; then
                read -s -p "Keystore 비밀번호: " KEYSTORE_PASSWORD
                echo ""
                read -s -p "비밀번호 확인: " PASSWORD_CONFIRM
                echo ""
                
                if [ "$KEYSTORE_PASSWORD" != "$PASSWORD_CONFIRM" ]; then
                    print_error "비밀번호가 일치하지 않습니다."
                    exit 1
                fi
            fi
            
            # Get certificate info
            read -p "인증서 CN (Common Name, 기본값: Unknown): " CN
            CN="${CN:-Unknown}"
            read -p "인증서 O (Organization, 기본값: Unknown): " O
            O="${O:-Unknown}"
            read -p "인증서 L (Location, 기본값: Unknown): " L
            L="${L:-Unknown}"
            read -p "인증서 C (Country, 기본값: KR): " C
            C="${C:-KR}"
            
            if ! create_release_keystore "$KEYSTORE_PATH" "$KEY_ALIAS" "$KEYSTORE_PASSWORD" "$CN" "$O" "$L" "$C"; then
                exit 1
            fi
        else
            print_error "Keystore 파일이 필요합니다."
            exit 1
        fi
    else
        # Get alias if not provided
        if [ -z "$KEY_ALIAS" ]; then
            echo ""
            print_info "Key alias를 입력하세요:"
            read -p "Key alias: " KEY_ALIAS
        fi
        
        # Get password if not provided
        if [ -z "$KEYSTORE_PASSWORD" ]; then
            echo ""
            print_info "Keystore 비밀번호를 입력하세요:"
            echo "  (입력 내용이 화면에 표시되지 않습니다)"
            read -s -p "Keystore 비밀번호: " KEYSTORE_PASSWORD
            echo ""
        fi
    fi
else
    print_error "잘못된 keystore 타입입니다: $KEYSTORE_TYPE"
    exit 1
fi

# Extract SHA-1 fingerprint
print_info "SHA-1 인증서 지문 추출 중..."

SHA1_OUTPUT=$(keytool -list -v -keystore "$KEYSTORE_PATH" -alias "$KEY_ALIAS" -storepass "$KEYSTORE_PASSWORD" 2>/dev/null | grep -i "SHA1:")

if [ -z "$SHA1_OUTPUT" ]; then
    print_error "SHA-1 지문을 추출할 수 없습니다."
    echo ""
    echo "확인 사항:"
    echo "  1. Keystore 파일 경로가 올바른지 확인"
    echo "  2. Key alias가 올바른지 확인"
    echo "  3. Keystore 비밀번호가 올바른지 확인"
    exit 1
fi

# Extract SHA-1 value (remove "SHA1: " prefix and spaces)
SHA1_VALUE=$(echo "$SHA1_OUTPUT" | sed 's/.*SHA1: *//' | tr -d ' ' | tr '[:lower:]' '[:upper:]')

if [ -z "$SHA1_VALUE" ]; then
    print_error "SHA-1 값을 파싱할 수 없습니다."
    exit 1
fi

# Convert to formats
SHA1_WITH_COLONS="$SHA1_VALUE"  # Already has colons from keytool output
SHA1_WITHOUT_COLONS=$(echo "$SHA1_VALUE" | tr -d ':')

# Generate Kakao Key Hash (Base64 encoded SHA-1 without colons)
# Convert hex to binary, then to base64
KAKAO_KEY_HASH=$(echo "$SHA1_WITHOUT_COLONS" | xxd -r -p | base64)

# Set display name for keystore type (Bash 3.x compatible)
if [ "$KEYSTORE_TYPE" = "debug" ]; then
    KEYSTORE_TYPE_DISPLAY="Debug"
else
    KEYSTORE_TYPE_DISPLAY="Release"
fi

print_success "인증서 지문 추출 완료!"
echo ""
echo "=========================================="
echo "Keystore 정보"
echo "=========================================="
echo "타입: $KEYSTORE_TYPE_DISPLAY keystore"
echo "경로: $KEYSTORE_PATH"
echo "Alias: $KEY_ALIAS"
echo ""
echo "=========================================="
echo "카카오 개발자 콘솔용 키 해시 (Key Hash)"
echo "=========================================="
echo ""
echo "$KAKAO_KEY_HASH"
echo ""
echo "설정 위치:"
echo "1. https://developers.kakao.com 접속"
echo "2. 내 애플리케이션 → 앱 선택"
echo "3. 플랫폼 → Android"
echo "4. 키 해시 추가에 위 값 입력"
echo ""
if [ "$KEYSTORE_TYPE" = "debug" ]; then
    echo "💡 참고: 이 값은 개발 중 테스트용입니다."
    echo "   실제 배포 시 Release keystore의 키 해시도 등록해야 합니다."
    echo ""
fi
echo "=========================================="
echo "구글/Firebase용 SHA-1 인증서 지문"
echo "=========================================="
echo ""
echo "SHA1: $SHA1_WITH_COLONS"
echo ""
echo "콜론 없는 버전 (Firebase Console):"
echo "$SHA1_WITHOUT_COLONS"
echo ""
echo "설정 위치:"
echo "1. Firebase Console (https://console.firebase.google.com)"
echo "2. 프로젝트 설정 → 일반 → 내 앱 → Android 앱"
echo "3. SHA 인증서 지문 추가에 위 SHA-1 값 입력"
echo ""
if [ "$KEYSTORE_TYPE" = "debug" ]; then
    echo "💡 참고: 이 값은 개발 중 테스트용입니다."
    echo "   실제 배포 시 Release keystore의 SHA-1 지문도 등록해야 합니다."
    echo ""
fi
echo "=========================================="

