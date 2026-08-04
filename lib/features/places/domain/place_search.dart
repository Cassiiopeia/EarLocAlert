/// 장소 검색 (F1.2 — issue #72 로 전방 배치)
///
/// 검색은 **좌표를 얻는 보조 수단**이다. 결과를 저장하지 않고, 선택하면
/// 지도 카메라를 그리로 옮기는 것까지만 한다 — 최종 위치는 언제나
/// 사용자가 핀으로 확정한다. 검색 제공자의 좌표를 그대로 믿으면
/// 출입구 반대편에 지오펜스가 걸리는 일이 생긴다.
class PlaceSearchResult {
  const PlaceSearchResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String name;
  final String address;
  final double latitude;
  final double longitude;
}

/// 검색 서비스.
///
/// 빈 목록은 "결과 없음"이다. 검색 자체를 못 하는 상태(키 없음·네트워크
/// 차단)는 [PlaceSearchUnavailable] 로 구분한다 — 화면이 "결과 없음"과
/// "검색 불가"를 다르게 보여줘야 하기 때문이다.
abstract interface class PlaceSearchService {
  Future<List<PlaceSearchResult>> search(String query);
}

class PlaceSearchUnavailable implements Exception {
  const PlaceSearchUnavailable(this.reason);

  final String reason;

  @override
  String toString() => 'PlaceSearchUnavailable: $reason';
}
