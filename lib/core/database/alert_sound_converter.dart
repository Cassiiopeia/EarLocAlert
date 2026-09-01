import 'package:drift/drift.dart';

import '../domain/alert_sound.dart';

/// [AlertSound] ↔ 문자열 (이슈 #121)
///
/// 별도 테이블도 JSON 도 아닌 **문자열 하나**다. `preset:<id>` /
/// `custom:<uuid>` 두 가지뿐이라 구조가 필요 없고, 프리셋을 늘려도
/// 스키마가 바뀌지 않는다.
class AlertSoundConverter extends TypeConverter<AlertSound, String> {
  const AlertSoundConverter();

  /// **절대 던지지 않는다.** 깨진 값은 기본음으로 떨어진다 —
  /// 문자열 하나 때문에 장소를 못 읽으면 알림이 통째로 멎는다.
  /// 그 판단은 [AlertSound.parse] 안에 있다.
  @override
  AlertSound fromSql(String fromDb) => AlertSound.parse(fromDb);

  @override
  String toSql(AlertSound value) => value.storageValue;
}
