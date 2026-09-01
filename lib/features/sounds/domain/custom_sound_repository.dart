import 'custom_sound.dart';

/// 사용자 음원 저장소 (이슈 #121)
///
/// **메타데이터(DB)와 파일이 함께 움직인다.** 등록하면 파일이 앱 전용
/// 디렉토리로 복사되고 행이 생기며, 삭제하면 둘 다 사라진다. 한쪽만 남으면
/// 목록에 있는데 소리가 안 나거나, 지운 줄 알았는데 용량을 먹는다.
abstract interface class CustomSoundRepository {
  /// 등록한 순서대로 (최신이 뒤)
  Future<List<CustomSound>> findAll();

  Future<CustomSound?> findById(String id);

  Future<int> count();

  /// [sourcePath] 의 파일을 앱 전용 디렉토리로 **복사**하고 등록한다.
  ///
  /// 원본을 참조하지 않는 이유 — 재부팅·재설치 후 접근 권한이 무효가 되고,
  /// 사용자가 원본을 옮기거나 지우면 소리가 사라진다. 무엇보다 **재생
  /// 시점이 백그라운드**라 그때 접근이 막히면 조용히 실패한다.
  ///
  /// 검증([SoundValidator])은 호출자가 미리 끝낸 상태여야 한다.
  Future<CustomSound> add({
    required String sourcePath,
    required String displayName,
    required Duration duration,
  });

  /// 행과 파일을 함께 지운다. 없는 id 여도 예외를 던지지 않는다.
  Future<void> delete(String id);

  /// 재생에 쓸 파일 경로. **파일이 실제로 없으면 `null`** 이다.
  ///
  /// 앱 데이터 삭제나 알 수 없는 이유로 파일만 사라질 수 있다.
  /// 호출자는 `null` 을 받으면 기본음으로 떨어진다 — 재생 단계에서
  /// 터뜨리지 않고 **해석 단계에서 막는다.**
  Future<String?> resolvePlayablePath(String id);
}
