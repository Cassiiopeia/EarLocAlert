import '../../../core/domain/alert_direction.dart';

/// 도착 기록 한 줄 (#313): 실제로 울린 도착·출발 알림. app 계층이 이력 + 장소 이름으로 만듦
class ArrivalRecord {
  const ArrivalRecord({
    required this.placeId,
    required this.placeName,
    required this.direction,
    required this.occurredAtUtc,
  });

  final String placeId;

  /// null 이면 지운 장소 (기록은 남음)
  final String? placeName;

  /// enter = 도착, exit = 출발
  final AlertDirection direction;

  final DateTime occurredAtUtc;
}

/// 하루치 기록 묶음 (기기 시간대 기준 날짜)
class ArrivalDay {
  const ArrivalDay({required this.localDate, required this.records});

  /// 그날 0시 (로컬)
  final DateTime localDate;

  /// 최신순
  final List<ArrivalRecord> records;
}

/// 요약 (#313): 최근 [windowDays]일 도착·출발 횟수, 가장 자주 울린 장소
class ArrivalSummary {
  const ArrivalSummary({
    required this.arrivalCount,
    required this.departureCount,
    required this.topPlaceName,
    required this.topPlaceCount,
  });

  // 요약 기간 (일)
  static const int windowDays = 30;

  final int arrivalCount;
  final int departureCount;

  /// 기록이 없거나 지운 장소뿐이면 null
  final String? topPlaceName;
  final int topPlaceCount;

  /// 기록 > 요약 ([nowUtc] 기준 최근 30일, 지운 장소는 최다 장소에서 제외)
  static ArrivalSummary from(List<ArrivalRecord> records, DateTime nowUtc) {
    final cutoff = nowUtc.toUtc().subtract(const Duration(days: windowDays));
    var arrivals = 0;
    var departures = 0;
    final countByPlaceId = <String, int>{};
    final nameByPlaceId = <String, String>{};
    for (final record in records) {
      if (record.occurredAtUtc.isBefore(cutoff)) continue;
      if (record.direction == AlertDirection.exit) {
        departures++;
      } else {
        arrivals++;
      }
      final name = record.placeName;
      if (name == null) continue;
      countByPlaceId[record.placeId] =
          (countByPlaceId[record.placeId] ?? 0) + 1;
      nameByPlaceId[record.placeId] = name;
    }
    String? topPlaceId;
    var topCount = 0;
    countByPlaceId.forEach((placeId, count) {
      if (count > topCount) {
        topPlaceId = placeId;
        topCount = count;
      }
    });
    return ArrivalSummary(
      arrivalCount: arrivals,
      departureCount: departures,
      topPlaceName: topPlaceId == null ? null : nameByPlaceId[topPlaceId],
      topPlaceCount: topCount,
    );
  }
}

/// 최신순 기록 > 로컬 날짜별 묶음 (순서 유지)
List<ArrivalDay> groupArrivalsByLocalDay(List<ArrivalRecord> records) {
  final days = <ArrivalDay>[];
  for (final record in records) {
    final local = record.occurredAtUtc.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    if (days.isNotEmpty && days.last.localDate == date) {
      days.last.records.add(record);
    } else {
      days.add(ArrivalDay(localDate: date, records: [record]));
    }
  }
  return days;
}
