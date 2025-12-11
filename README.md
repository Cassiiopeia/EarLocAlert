# EarLocAlert

[![Version](https://img.shields.io/badge/version-1.2.6-blue.svg)](https://github.com/Cassiiopeia/EarLocAlert)
[![Flutter](https://img.shields.io/badge/Flutter-3.35.5-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web-lightgrey)](https://flutter.dev/multi-platform)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Flutter 앱 배포 자동화를 위한 웹 기반 설정 마법사 모음**

iOS TestFlight, Android Play Store 배포에 필요한 복잡한 설정을 단계별 마법사로 간소화합니다.

---

## 주요 기능

| 기능 | 설명 |
|------|------|
| **iOS TestFlight 마법사** | 9단계 마법사로 인증서, 프로비저닝 프로필, App ID 설정 자동화 |
| **Android Play Store 마법사** | 키스토어 생성, 앱 서명 설정, Fastlane 자동화 |
| **OAuth 설정 마법사** | Google, Facebook, GitHub 등 OAuth 프로바이더 자동 설정 |
| **드래그앤드롭 파일 업로드** | 인증서, 프로비저닝 프로필, API 키 파일 간편 업로드 |
| **세션 저장** | 진행 상황을 localStorage에 저장하여 나중에 복원 가능 |
| **결과 내보내기** | JSON/TXT 형식으로 설정 결과 다운로드 |

---

## 기술 스택

### 핵심 기술
- **Framework**: Flutter 3.35.5
- **Language**: Dart 3.9.2+, Kotlin, Swift
- **Build Tools**: Gradle (Kotlin DSL), Xcode
- **배포 자동화**: Fastlane, GitHub Actions

### 웹 마법사
- HTML5 / CSS3 / JavaScript
- localStorage API (세션 저장)
- FormData API (파일 업로드)

### 개발 도구
- CodeRabbit (자동 코드 리뷰)
- Fastlane (배포 자동화)
- GitHub Actions (CI/CD)

---

## 설치 및 실행

### 필수 요구사항
- Flutter SDK 3.35.5 이상
- Dart SDK 3.9.2 이상
- Xcode 14.0 이상 (iOS 빌드 시)
- Android Studio / Android SDK (Android 빌드 시)

### 의존성 설치
```bash
flutter pub get
```

### 개발 서버 실행
```bash
# 기본 실행
flutter run

# 웹 실행
flutter run -d chrome

# 특정 플랫폼 실행
flutter run -d ios
flutter run -d android
```

### 릴리스 빌드
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ipa --release

# Web
flutter build web --release
```

### 코드 품질 검사
```bash
# 코드 분석
flutter analyze

# 테스트 실행
flutter test
```

---

## 배포 마법사 사용 방법

### iOS TestFlight 마법사

1. `.github/util/flutter/testflight-wizard/testflight-wizard.html` 파일을 브라우저에서 열기
2. 9단계 마법사를 순서대로 진행:
   - **Step 1**: 인증서 정보 입력
   - **Step 2**: 프로비저닝 프로필 설정
   - **Step 3**: App Store Connect API Key 업로드
   - **Step 4**: App ID 및 Bundle ID 설정
   - **Step 5**: Team ID 설정
   - **Step 6**: Fastlane 설정 생성
   - **Step 7**: GitHub Secrets 설정
   - **Step 8**: 워크플로우 파일 생성
   - **Step 9**: 결과 확인 및 다운로드

### Android Play Store 마법사

1. `.github/util/flutter/playstore-wizard/playstore-wizard.html` 파일을 브라우저에서 열기
2. 단계별 진행:
   - **Keystore 생성**: 앱 서명용 키스토어 생성
   - **Application ID 파싱**: pubspec.yaml에서 자동 추출
   - **Fastlane 설정**: Play Store 배포 스크립트 생성
   - **GitHub Actions 설정**: CI/CD 워크플로우 구성

### OAuth 설정 마법사

1. `.github/util/flutter/oauth-wizard/oauth-wizard.html` 파일을 브라우저에서 열기
2. OAuth 프로바이더 선택 (Google, Facebook, GitHub 등)
3. 필요한 설정 정보 입력
4. 설정 파일 다운로드

---

## CI/CD 파이프라인

### GitHub Actions 워크플로우

| 워크플로우 | 설명 |
|------------|------|
| `PROJECT-FLUTTER-IOS-TESTFLIGHT.yaml` | iOS TestFlight 자동 배포 |
| `PROJECT-FLUTTER-ANDROID-PLAYSTORE-CICD.yaml` | Android Play Store 자동 배포 |
| `PROJECT-COMMON-VERSION-CONTROL.yaml` | 버전 자동 관리 |

### 배포 프로세스

```
코드 푸시 → GitHub Actions 트리거 → 빌드 → 테스트 → 배포
                                              ↓
                              iOS: TestFlight 업로드
                              Android: Play Store 업로드
```

---

## 프로젝트 구조

```
EarLocAlert/
├── lib/                          # Flutter 소스 코드
│   └── main.dart
├── android/                      # Android 네이티브 코드
│   ├── app/
│   ├── fastlane/
│   └── build.gradle.kts
├── ios/                          # iOS 네이티브 코드
│   ├── Runner/
│   └── fastlane/
├── .github/
│   ├── workflows/                # CI/CD 워크플로우
│   └── util/flutter/             # 배포 마법사
│       ├── testflight-wizard/    # iOS 마법사
│       ├── playstore-wizard/     # Android 마법사
│       └── oauth-wizard/         # OAuth 마법사
├── assets/                       # 앱 리소스
├── pubspec.yaml                  # Flutter 의존성
├── version.yml                   # 버전 관리
└── CHANGELOG.md                  # 변경 사항
```

---

## 버전 히스토리

<!-- 수정하지마세요 자동으로 동기화 됩니다 -->
### 최신 버전 : v1.2.6 (2025-12-09)

| 버전 | 날짜 | 주요 변경사항 |
|------|------|-------------|
| 1.2.6 | 2025-12-09 | Android Play Store 배포 로직 개편, Application ID 파싱 로직 추가 |
| 1.2.5 | 2025-12-01 | iOS TestFlight 마법사 확장 (9단계), 암호화 옵션 설정 지원 |
| 1.2.2 | 2025-12-01 | TestFlight 배포 워크플로우 최적화 |
| 1.1.5 | 2025-12-01 | 드래그앤드롭 파일 업로드, 선택적 단계 건너뛰기 |

[전체 버전 기록 보기](CHANGELOG.md)

---

## 보안 고려사항

- 모든 민감한 정보는 **로컬에서만** 처리됩니다
- 키스토어, 인증서, API 키는 `.gitignore`에 등록되어 있습니다
- GitHub Secrets를 통해 CI/CD에서 안전하게 관리됩니다
- 마법사에서 생성된 설정은 브라우저의 localStorage에만 저장됩니다

---

## 기여하기

1. 이 저장소를 Fork 합니다
2. 기능 브랜치를 생성합니다 (`git checkout -b feature/amazing-feature`)
3. 변경 사항을 커밋합니다 (`git commit -m 'Add amazing feature'`)
4. 브랜치에 푸시합니다 (`git push origin feature/amazing-feature`)
5. Pull Request를 생성합니다

---

## 라이선스

이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.

---

## 문의

- **개발자**: Cassiiopeia
- **이슈 등록**: [GitHub Issues](https://github.com/Cassiiopeia/EarLocAlert/issues)
