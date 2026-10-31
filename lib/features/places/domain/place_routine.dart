import 'alert_place.dart';

/// 장소 루틴 묶음 (#315): 이름 붙인 장소 묶음 (예: 출근길)
///
/// 켜짐은 저장하지 않음 — 묶은 장소 중 남은 것이 모두 켜져 있으면 켜짐 ([isOnFor]).
class PlaceRoutine {
  const PlaceRoutine({
    required this.id,
    required this.name,
    required this.placeIds,
    required this.isExclusive,
    required this.createdAt,
  });

  // 이름 최대 길이 (Drift 열 제약과 같음)
  static const int maxNameLength = 50;

  final String id;
  final String name;

  /// 묶은 장소 id (값 참조, 지운 장소 id 가 남아 있을 수 있음)
  final List<String> placeIds;

  /// 켤 때 루틴 밖 장소를 모두 끄는가
  final bool isExclusive;

  /// UTC
  final DateTime createdAt;

  /// 지금 있는 장소 중 이 루틴에 묶인 것
  List<AlertPlace> placesIn(List<AlertPlace> places) {
    final ids = placeIds.toSet();
    return places.where((place) => ids.contains(place.id)).toList();
  }

  /// 켜짐: 묶인 장소가 하나 이상 있고 모두 켜짐
  bool isOnFor(List<AlertPlace> places) {
    final members = placesIn(places);
    return members.isNotEmpty && members.every((place) => place.enabled);
  }

  /// 누르면 바뀔 장소 켜짐 값 (켜짐 > 모두 끔, 아니면 > 모두 켬 + 나머지 끄기 옵션)
  ///
  /// 이미 그 값인 장소는 빼서 돌려줌 (빈 맵이면 바뀔 것 없음)
  Map<String, bool> toggleChanges(List<AlertPlace> places) {
    final members = placesIn(places).map((place) => place.id).toSet();
    final turnOn = !isOnFor(places);
    final changes = <String, bool>{};
    for (final place in places) {
      final bool next;
      if (members.contains(place.id)) {
        next = turnOn;
      } else if (turnOn && isExclusive) {
        next = false;
      } else {
        continue;
      }
      if (place.enabled != next) changes[place.id] = next;
    }
    return changes;
  }

  PlaceRoutine copyWith({
    String? name,
    List<String>? placeIds,
    bool? isExclusive,
  }) => PlaceRoutine(
    id: id,
    name: name ?? this.name,
    placeIds: placeIds ?? this.placeIds,
    isExclusive: isExclusive ?? this.isExclusive,
    createdAt: createdAt,
  );
}

/// 루틴 저장소 (#315)
abstract interface class PlaceRoutineRepository {
  /// 만든 순서
  Stream<List<PlaceRoutine>> watchAll();

  Future<void> save(PlaceRoutine routine);

  Future<void> delete(String id);
}
