/// Google Maps 다크 스타일 (docs/06-UX.md)
///
/// **기본 지도는 흰색이다.** 다크 앱 안에 하얀 판이 박히면 그것만으로
/// 디자인이 무너진다. 색은 전부 `AppColors` 팔레트에서 가져왔다 —
/// 팔레트를 바꾸면 이 값도 함께 고친다.
///
/// POI 아이콘·라벨을 끈 이유는 장식이 아니라 판독성이다. 장소를 고르는
/// 화면에서 상점 핀이 깔리면 사용자가 찍은 핀이 묻힌다.
abstract final class MapStyle {
  static const dark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#0d0d0d"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#9e9e9e"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#0d0d0d"}]},
  {"featureType":"administrative","elementType":"geometry",
   "stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill",
   "stylers":[{"color":"#bdbdbd"}]},
  {"featureType":"poi","elementType":"labels","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry",
   "stylers":[{"color":"#16201c"}]},
  {"featureType":"road","elementType":"geometry",
   "stylers":[{"color":"#262626"}]},
  {"featureType":"road","elementType":"labels.text.fill",
   "stylers":[{"color":"#8a8a8a"}]},
  {"featureType":"road.arterial","elementType":"geometry",
   "stylers":[{"color":"#2e2e2e"}]},
  {"featureType":"road.highway","elementType":"geometry",
   "stylers":[{"color":"#3a3a3a"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"water","elementType":"geometry",
   "stylers":[{"color":"#101820"}]},
  {"featureType":"water","elementType":"labels.text.fill",
   "stylers":[{"color":"#4a5560"}]}
]
''';
}
