import 'dart:convert';

import 'package:drift/drift.dart';

import '../domain/alert_schedule.dart';

/// [AlertSchedule] 목록 ↔ JSON 문자열 (이슈 #81)
///
/// 별도 테이블로 쪼개지 않는 이유는 **창이 장소 없이 조회되는 경우가 없기
/// 때문**이다. 항상 함께 읽고 함께 쓴다. 테이블을 나누면 백그라운드의
/// `findById(placeId)` 마다 조인이 붙는데, 그 대가로 얻는 쿼리 능력을 쓸
/// 데가 없다.
///
/// `json_serializable` 을 쓰지 않고 손으로 쓴다 — 필드 셋뿐이라 의존성을
/// 늘릴 이유가 없다.
class AlertScheduleListConverter
    extends TypeConverter<List<AlertSchedule>, String> {
  const AlertScheduleListConverter();

  @override
  List<AlertSchedule> fromSql(String fromDb) {
    if (fromDb.isEmpty) return const [];
    // 저장된 값이 깨져 있어도 앱이 죽으면 안 된다. 스케줄을 잃는 것은
    // "항상 알림"으로 떨어지는 것이라 안전한 쪽이다 — 조용히 안 울리는
    // 것보다 낫다.
    try {
      final decoded = jsonDecode(fromDb);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(_scheduleFromJson)
          .whereType<AlertSchedule>()
          .toList(growable: false);
    } on FormatException {
      return const [];
    }
  }

  @override
  String toSql(List<AlertSchedule> value) {
    return jsonEncode(value.map(_scheduleToJson).toList(growable: false));
  }

  static AlertSchedule? _scheduleFromJson(Map<String, dynamic> json) {
    final days = json['days'];
    final start = json['start'];
    final end = json['end'];
    if (days is! List || start is! int || end is! int) return null;
    return AlertSchedule(
      daysOfWeek: days.whereType<int>().toSet(),
      startMinuteOfDay: start,
      endMinuteOfDay: end,
    );
  }

  static Map<String, dynamic> _scheduleToJson(AlertSchedule schedule) {
    // 요일은 정렬해서 저장한다 — Set 의 순회 순서에 따라 같은 값이 다른
    // 문자열로 저장되면 diff·테스트가 불안정해진다
    final days = schedule.daysOfWeek.toList()..sort();
    return {
      'days': days,
      'start': schedule.startMinuteOfDay,
      'end': schedule.endMinuteOfDay,
    };
  }
}
