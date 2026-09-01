import 'audio_route.dart';
import 'vibration_intensity.dart';

/// 진동 제어 (docs/02-ARCHITECTURE.md 규칙 3)
///
/// 플랫폼 API 를 인터페이스 뒤에 둔다 — 알림 흐름을 실기기 없이
/// 테스트하기 위해서다.
abstract interface class VibrationService {
  /// [interval] 간격으로 반복 진동을 시작한다 (F3.1)
  ///
  /// [intensity] 는 사용자가 설정한 세기다 (이슈 #103). 진폭 제어를
  /// 지원하지 않는 기기에서는 길이만 반영된다.
  Future<void> startRepeating({
    required Duration interval,
    VibrationIntensity intensity = VibrationIntensity.normal,
  });

  /// 즉시 중단한다. **어떤 상황에서도 실패하지 않아야 한다.**
  Future<void> stop();
}

/// 재생할 음원 (이슈 #121)
///
/// **`alert` 는 이 값이 어디서 왔는지 모른다.** 프리셋인지 사용자 파일인지,
/// 파일이 실제로 있는지는 `app` 이 해석해서 넘긴다 — 그래야 `alert` 가
/// 저장소도 파일 시스템도 모르는 채로 남는다 (규칙 1).
sealed class AlertSoundSource {
  const AlertSoundSource();
}

/// 앱에 내장된 음원
final class AssetSound extends AlertSoundSource {
  const AssetSound(this.assetPath);

  final String assetPath;
}

/// 사용자가 올린 음원. **경로가 유효함이 이미 확인된 상태다.**
final class FileSound extends AlertSoundSource {
  const FileSound(this.filePath);

  final String filePath;
}

/// 알림음 재생 (docs/03-DOMAIN.md 규칙 5)
abstract interface class AlertSoundService {
  /// **본인만 듣는** 오디오 출력이 연결되어 있는가.
  ///
  /// 유선 이어폰·USB-C 이어폰·블루투스 이어폰을 모두 포함한다.
  /// 스피커로 흘러나갈 수 있는 출력(차량 오디오·AirPlay·HDMI)은 제외한다
  /// (docs/10-DECISIONS.md 018).
  ///
  /// **발화 시점에 확인한다** — 사용자가 방금 이어폰을 빼거나 꽂았을 수 있다.
  Future<bool> isHeadphoneConnected();

  /// 알림음을 재생한다.
  ///
  /// [volume] 은 재생 크기(0.0~1.0)다 — 사용자가 설정한 값이다 (이슈 #86).
  ///
  /// 호출 전에 이어폰 연결이 확인된 상태여야 한다.
  /// 실패하면 [AlertSoundException] 을 던지고, 호출자는 재시도하지 않고
  /// 진동으로 떨어진다 — 재시도 중 라우팅이 바뀌어 스피커로 새는 것이 최악이다.
  ///
  /// [source] 는 장소마다 다를 수 있는 음원이다 (이슈 #121).
  /// **`null` 이면 기본 음원**을 쓴다 — 해석에 실패했거나 값을 싣지 않은
  /// 경로에서도 소리는 나야 한다.
  Future<void> play({required double volume, AlertSoundSource? source});

  Future<void> stop();
}

/// 알림음 크기 설정 (이슈 #86)
///
/// 전역 설정이다 — 장소별로 두지 않는다. "이 장소는 크게, 저 장소는 작게"
/// 가 필요해진 사례가 없고, 장소마다 다르면 사용자는 왜 지금 작게
/// 울렸는지 추적해야 한다.
abstract interface class AlertVolumeStore {
  /// 0.0 ~ 1.0. 저장된 값이 없으면 [defaultVolume].
  Future<double> volume();

  Future<void> save(double volume);

  /// 최대의 80% — "확실히 들리지만 놀라지 않는" 시작점이다.
  /// 100% 를 기본으로 하면 첫 알림에서 귀를 때린다.
  static const double defaultVolume = 0.8;
}

/// 시스템 미디어 볼륨 제어 (이슈 #86)
///
/// **시스템 볼륨이 0 이면 앱 재생 볼륨을 아무리 올려도 무음이다.**
/// 알림 시점에 시스템 볼륨을 설정값 수준까지 끌어올리고, 해제되면
/// 원래대로 되돌린다 — 사용자의 기기 설정을 영구히 바꾸지 않는다.
///
/// Android 전용이다. iOS 는 시스템 볼륨을 바꾸는 공개 API 가 없어
/// 어떤 호출도 조용히 무시된다 — 앱 재생 볼륨으로만 대응한다.
///
/// **어떤 호출도 예외를 올리지 않는다.** 볼륨을 못 올리는 것은 알림이
/// 작아지는 일이지 알림이 멎을 일이 아니다.
abstract interface class SystemVolumeService {
  /// 미디어 볼륨을 [fraction](0.0~1.0) 수준까지 **올린다.**
  ///
  /// 이미 그보다 크면 건드리지 않는다 — 사용자가 크게 듣고 있는 것을
  /// 낮추면 안 된다.
  Future<void> raiseTo(double fraction);

  /// [raiseTo] 가 바꾼 볼륨을 원래 값으로 되돌린다.
  /// 바꾼 적이 없으면 아무것도 하지 않는다.
  Future<void> restore();
}

class AlertSoundException implements Exception {
  const AlertSoundException(this.message);

  final String message;

  @override
  String toString() => 'AlertSoundException: $message';
}

/// 알림 표시 (OS 알림 영역)
abstract interface class AlertNotifier {
  /// 알림을 띄운다. 사용자가 탭하면 앱이 열린다
  Future<void> show({required String placeName, required String body});

  Future<void> dismiss();
}

/// 발화 결과 — 실제로 어떤 경로로 알렸는지
class AlertOutcome {
  const AlertOutcome({required this.audioRoute, required this.soundFailed});

  final AudioRoute audioRoute;

  /// 소리 재생을 시도했으나 실패해 진동으로 떨어졌는가.
  ///
  /// 화면 표시 문구가 달라지고, 반복되면 조사 단서가 된다.
  final bool soundFailed;
}
