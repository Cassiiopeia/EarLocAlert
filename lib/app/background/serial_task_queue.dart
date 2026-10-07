import 'dart:async';

/// 작업을 하나씩 순서대로 돌리는 큐 (이슈 #231)
///
/// iOS 영역 콜백은 같은 isolate 에 **동시에** 들어온다. 실기기에서 세 콜백이
/// 같은 초에 도착했고, 그중 하나는 `received` 만 남기고 사라졌다. 콜백마다
/// 판정기를 새로 만들어 판정기 안의 직렬화가 콜백 사이를 막지 못했기 때문이다.
///
/// [whenIdle] 이 핵심이다. native_geofence 는 콜백 하나가 끝나면 남은 이벤트가
/// 없을 때 **헤드리스 엔진을 바로 파괴한다** — 동시에 보낸 다른 콜백이 아직
/// 돌고 있어도. 그래서 모든 콜백이 큐가 빌 때까지 기다렸다가 끝나야 한다.
class SerialTaskQueue {
  Future<void> _tail = Future.value();
  int _pending = 0;

  /// 아직 끝나지 않은 작업 수
  int get pending => _pending;

  /// 앞선 작업이 끝난 뒤 [task] 를 돌린다. 실패해도 큐는 끊기지 않는다.
  Future<T> run<T>(Future<T> Function() task) {
    _pending++;
    final completer = Completer<T>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await task());
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      } finally {
        _pending--;
      }
    });
    return completer.future;
  }

  /// 큐가 비고 [grace] 동안 새 작업이 없을 때 끝난다.
  ///
  /// 유예를 두는 이유 — 네이티브가 다음 이벤트를 이미 보냈는데 메시지가 아직
  /// Dart 에 닿지 않은 순간이 있다. 그 사이에 끝나면 엔진이 파괴된다.
  Future<void> whenIdle({
    Duration grace = const Duration(milliseconds: 300),
  }) async {
    while (true) {
      await _tail;
      await Future<void>.delayed(grace);
      if (_pending == 0) return;
    }
  }
}
