import 'dart:async';

/// 지오펜스 등록 동기화가 끝났다는 신호 (이슈 #142 QA)
///
/// **홈 상태가 등록 결과를 따라가게 하려고 둔다.** 홈 상태는 "등록된
/// 장소가 있는가"를 한 번 읽고 끝났는데, 첫 장소를 등록해도 다시 읽지
/// 않아 켜진 장소는 있는데 감시=false 인 채로 "감시 꺼짐 ›" 경고가
/// 떴다. 에뮬레이터에서 앱이 다시 앞으로 올 때까지 76분 동안 남았다.
///
/// 동기화 객체를 직접 구독하지 않고 이 신호를 사이에 두는 것은, 홈 상태가
/// 장소 저장소(Drift)까지 끌어오지 않게 하기 위해서다.
class GeofenceSyncSignal {
  final _controller = StreamController<void>.broadcast();

  /// 동기화가 끝날 때마다 한 번씩 흐른다
  Stream<void> get stream => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}
