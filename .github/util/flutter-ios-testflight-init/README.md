# Flutter iOS TestFlight 설정 마법사

Flutter 프로젝트를 iOS TestFlight에 배포하기 위한 설정을 자동화하는 도구입니다.

## 📋 개요

이 마법사는 다음 작업을 자동화합니다:

1. **Fastlane 설정 파일 생성**
   - `ios/Gemfile` - Ruby 의존성
   - `ios/fastlane/Appfile` - 앱 정보
   - `ios/fastlane/Fastfile` - 빌드 및 배포 설정

2. **GitHub Secrets 설정 가이드**
   - 필요한 인증서 및 키 생성 방법
   - Base64 인코딩 명령어 제공

3. **CI/CD 워크플로우 연동**
   - GitHub Actions 기반 자동 배포

## 🚀 빠른 시작

### 방법 1: HTML 마법사 사용 (권장)

```bash
# Mac에서 브라우저로 열기
open .github/util/flutter-ios-testflight-init/index.html
```

마법사의 Step-by-Step 가이드를 따라 진행하세요.

### 방법 2: 스크립트 직접 실행

```bash
# 실행 권한 부여
chmod +x .github/util/flutter-ios-testflight-init/init.sh

# 스크립트 실행
./.github/util/flutter-ios-testflight-init/init.sh \
  /path/to/project \
  com.example.myapp \
  ABC1234DEF \
  "MyApp Distribution"
```

**매개변수:**
- `PROJECT_PATH`: Flutter 프로젝트 루트 경로
- `BUNDLE_ID`: iOS Bundle ID (예: com.example.myapp)
- `TEAM_ID`: Apple Developer Team ID (10자리)
- `PROFILE_NAME`: Provisioning Profile 이름

## 📁 파일 구조

```
.github/util/flutter-ios-testflight-init/
├── index.html          # 마법사 UI
├── wizard.ts           # 마법사 로직 (TypeScript)
├── style.css           # 스타일
├── init.sh             # 설정 파일 생성 스크립트
├── templates/
│   ├── Gemfile         # Ruby 의존성 템플릿
│   ├── Appfile         # Fastlane 앱 설정 템플릿
│   └── Fastfile        # Fastlane 빌드 설정 템플릿
└── README.md           # 이 문서
```

## 🔐 필요한 GitHub Secrets

| Secret 이름 | 설명 | 가져오는 곳 |
|------------|------|-----------|
| `APPLE_CERTIFICATE_BASE64` | 배포 인증서 (.p12) Base64 | 키체인 접근 → Apple Distribution 인증서 내보내기 |
| `APPLE_CERTIFICATE_PASSWORD` | .p12 비밀번호 | 인증서 내보내기 시 설정한 비밀번호 |
| `APPLE_PROVISIONING_PROFILE_BASE64` | 프로비저닝 프로파일 Base64 | Apple Developer → Profiles |
| `APPLE_TEAM_ID` | Team ID (10자리) | Apple Developer → Membership |
| `IOS_BUNDLE_ID` | 앱 Bundle ID | Apple Developer → Identifiers |
| `IOS_PROVISIONING_PROFILE_NAME` | 프로파일 정확한 이름 | Apple Developer → Profiles |
| `APP_STORE_CONNECT_API_KEY_ID` | API Key ID | App Store Connect → Keys |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID | App Store Connect → Keys |
| `APP_STORE_CONNECT_API_KEY_BASE64` | API Key (.p8) Base64 | App Store Connect → Keys (다운로드) |

## 💻 Base64 인코딩 명령어 (Mac)

```bash
# 인증서 (.p12)
base64 -i ~/Desktop/Certificates.p12 | pbcopy

# 프로비저닝 프로파일 (.mobileprovision)
base64 -i ~/Desktop/profile.mobileprovision | pbcopy

# API Key (.p8)
base64 -i ~/Desktop/AuthKey_XXXXXX.p8 | pbcopy
```

실행 후 클립보드에 복사되므로 GitHub Secrets에 바로 붙여넣기 하면 됩니다.

## 🔧 생성되는 파일 설명

### ios/Gemfile

Ruby 의존성을 관리합니다. Fastlane과 CocoaPods가 포함됩니다.

```ruby
source "https://rubygems.org"
gem "fastlane", "~> 2.225"
gem "cocoapods", "~> 1.15"
```

### ios/fastlane/Appfile

앱 식별 정보를 설정합니다. 환경변수로 값을 주입받습니다.

```ruby
app_identifier(ENV["IOS_BUNDLE_ID"] || "com.example.myapp")
team_id(ENV["APPLE_TEAM_ID"] || "ABC1234DEF")
```

### ios/fastlane/Fastfile

빌드 및 배포 로직을 정의합니다.

주요 Lane:
- `deploy_testflight`: IPA 빌드 + TestFlight 업로드
- `build_only`: IPA 빌드만 수행 (테스트용)
- `debug_info`: 환경변수 및 인증 정보 출력

## 📱 워크플로우 연동

`.github/workflows/PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` 파일이 Fastlane을 호출합니다.

```yaml
- name: Build and Deploy with Fastlane
  env:
    IOS_BUNDLE_ID: ${{ secrets.IOS_BUNDLE_ID }}
    APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
    # ... 기타 환경변수
  run: |
    cd ios
    bundle install
    bundle exec fastlane deploy_testflight
```

## ❓ 문제 해결

### 1. "Pods-Runner does not support provisioning profiles" 오류

**원인**: xcconfig 설정이 Pods 타겟에도 적용됨

**해결**: Fastlane의 `build_app`이 자동으로 Runner 타겟에만 서명 설정을 적용합니다. 이 마법사로 생성된 Fastfile을 사용하면 이 문제가 해결됩니다.

### 2. "No profile for team matching found" 오류

**원인**: Provisioning Profile이 CI 환경에 제대로 설치되지 않음

**해결**:
1. `APPLE_PROVISIONING_PROFILE_BASE64` 값이 올바른지 확인
2. Profile 이름이 정확한지 확인 (대소문자 포함)
3. Profile이 만료되지 않았는지 확인

### 3. 인증서 관련 오류

**확인 사항**:
1. 인증서와 프로파일이 매칭되는지 확인
2. 인증서가 "Apple Distribution" 타입인지 확인
3. 인증서가 만료되지 않았는지 확인

## 📚 참고 자료

- [Fastlane 공식 문서](https://docs.fastlane.tools/)
- [Apple Developer 인증서 관리](https://developer.apple.com/account/resources/certificates)
- [App Store Connect API](https://developer.apple.com/documentation/appstoreconnectapi)

## 🤝 기여

버그 리포트나 기능 제안은 이슈로 등록해주세요.
