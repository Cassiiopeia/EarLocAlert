import 'app_version.dart';

/// 내려받을 수 있는 새 버전 (이슈 #104)
class AppRelease {
  const AppRelease({
    required this.version,
    required this.apkUrl,
    required this.notes,
  });

  final AppVersion version;

  /// APK 직접 내려받기 주소. 릴리스에 APK 가 없으면 이 값이 비어 있다
  final String apkUrl;

  /// 릴리스 노트. 무엇이 바뀌었는지 모르면 사용자는 받을 이유를 못 찾는다
  final String notes;

  bool get hasApk => apkUrl.isNotEmpty;
}

/// 업데이트 확인 결과 (이슈 #104)
sealed class UpdateCheck {
  const UpdateCheck();
}

/// 이미 최신이다
class UpdateNotNeeded extends UpdateCheck {
  const UpdateNotNeeded(this.current);

  final AppVersion current;
}

/// 새 버전이 있다
class UpdateAvailable extends UpdateCheck {
  const UpdateAvailable({required this.current, required this.release});

  final AppVersion current;
  final AppRelease release;
}

/// 확인하지 못했다 — 네트워크 단절·응답 이상·버전 파싱 실패.
///
/// **실패를 "최신"으로 뭉뚱그리지 않는다.** 사용자가 확인했다고 믿는데
/// 실제로는 확인이 안 된 상태가 가장 나쁘다.
class UpdateCheckFailed extends UpdateCheck {
  const UpdateCheckFailed(this.reason);

  final String reason;
}

/// 업데이트 확인·설치 (이슈 #104)
///
/// **Android 전용이다.** iOS 는 사이드로드 경로가 없다. 스토어 배포가
/// 시작되면 이 경로는 걷어낸다 (docs/11-ROADMAP.md).
abstract interface class AppUpdateService {
  /// 최신 릴리스를 조회해 지금 버전과 비교한다
  Future<UpdateCheck> check();

  /// APK 를 내려받아 설치 화면을 띄운다.
  ///
  /// **설치 자체는 사용자가 확인한다** — 앱이 하는 것은 여기까지다.
  /// [onProgress] 는 0.0~1.0. 길이를 모르는 응답에서는 호출되지 않는다.
  Future<void> download(
    AppRelease release, {
    void Function(double progress)? onProgress,
  });
}

/// 업데이트 과정에서 발생하는 실패.
///
/// 앱의 다른 기능과 무관하므로 밖으로 새지 않게 여기서 닫는다.
class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}
