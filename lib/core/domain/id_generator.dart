import 'package:uuid/uuid.dart';

/// 식별자 생성 (docs/03-DOMAIN.md)
///
/// **저장 전에 앱이 만든다.** DB 자동 증가를 쓰지 않는다 —
/// 플랫폼 지오펜스에 등록할 때 식별자가 먼저 필요하고,
/// 나중에 기기 간 동기화를 붙일 여지를 남긴다.
///
/// UUIDv7 은 상위 비트가 타임스탬프라 시간순 정렬된다.
abstract final class IdGenerator {
  static const _uuid = Uuid();

  static String generate() => _uuid.v7();
}
