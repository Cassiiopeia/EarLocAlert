import 'dart:async';
import 'dart:isolate';
import 'dart:ui' show IsolateNameServer;

import '../../core/diagnostics/diagnostics.dart';
import '../../core/diagnostics/log_format.dart';
import 'serial_task_queue.dart';

/// iOS 영역 이벤트 하나 (이슈 #231)
class RegionEvent {
  const RegionEvent({
    required this.placeId,
    required this.entered,
    this.latitude,
    this.longitude,
  });

  final String placeId;
  final bool entered;
  final double? latitude;
  final double? longitude;

  String get direction => entered ? 'enter' : 'exit';
}

/// 앱 isolate 가 영역 이벤트를 받는 포트 이름 (이슈 #231)
///
/// `IsolateNameServer` 는 프로세스 전체에서 하나다 — native_geofence 의 헤드리스
/// 엔진과 앱 엔진은 다른 엔진이지만 같은 Dart VM 에 있어 이 이름으로 만난다.
const regionEventPortName = 'kr.suhsaechan.ear_loc_alert/region_event';

/// 영역 이벤트를 앱 isolate 로 넘긴다 (이슈 #231).
///
/// **왜 넘기나** — 앱 isolate 에는 적응형 감시의 정밀 판정이 이미 돌고 있다.
/// 두 경로가 각자 판정하면 같은 도착을 동시에 `outside → inside` 로 보고 두 번
/// 울릴 수 있다 (#131 과 같은 경합). 판정기 하나의 직렬화 큐로 모으면
/// `inside → inside` 가 되어 중복이 구조적으로 막힌다. DB 연결도 하나로 끝난다.
///
/// 앱 isolate 가 없거나(포트 없음) 제때 답하지 않으면 false — 호출자가 직접
/// 판정한다. 답을 기다리는 동안 이 콜백은 끝나지 않으므로 엔진도 살아 있다.
Future<bool> relayRegionEventToApp(
  RegionEvent event, {
  Duration timeout = const Duration(seconds: 10),
  SendPort? Function(String name) lookup = IsolateNameServer.lookupPortByName,
}) async {
  final target = lookup(regionEventPortName);
  if (target == null) return false;

  final reply = ReceivePort();
  try {
    target.send({
      'placeId': event.placeId,
      'entered': event.entered,
      'latitude': event.latitude,
      'longitude': event.longitude,
      'reply': reply.sendPort,
    });
    final answer = await reply.first.timeout(timeout);
    if (answer == 'ok') return true;
    Diagnostics.log(
      'geofence',
      'relay failed place=${shortId(event.placeId)} reason=app_error detail=$answer',
    );
    return false;
  } on TimeoutException {
    // 죽은 포트(앱 isolate 가 사라진 뒤 남은 이름)로 보내면 답이 영영 없다
    Diagnostics.log(
      'geofence',
      'relay failed place=${shortId(event.placeId)} reason=timeout',
    );
    return false;
  } finally {
    reply.close();
  }
}

/// 앱 isolate 쪽 수신기 (이슈 #231)
///
/// 받은 이벤트는 [handle] 이 판정한다 — 정밀 판정과 같은 판정기를 쓰게 하는 것이
/// 이 수신기의 존재 이유다.
class RegionEventReceiver {
  RegionEventReceiver(this._handle);

  final Future<void> Function(RegionEvent event) _handle;
  ReceivePort? _port;

  void attach() {
    if (_port != null) return;
    final port = ReceivePort();
    // 이전 실행이 남긴 이름이 있으면 죽은 포트다 — 지우고 다시 건다
    IsolateNameServer.removePortNameMapping(regionEventPortName);
    IsolateNameServer.registerPortWithName(port.sendPort, regionEventPortName);
    port.listen((message) => unawaited(_onMessage(message)));
    _port = port;
    Diagnostics.log('geofence', 'region relay receiver attached');
  }

  void detach() {
    IsolateNameServer.removePortNameMapping(regionEventPortName);
    _port?.close();
    _port = null;
  }

  Future<void> _onMessage(Object? message) async {
    if (message is! Map) return;
    final reply = message['reply'];
    try {
      final event = RegionEvent(
        placeId: message['placeId'] as String,
        entered: message['entered'] as bool,
        latitude: (message['latitude'] as num?)?.toDouble(),
        longitude: (message['longitude'] as num?)?.toDouble(),
      );
      await _handle(event);
      if (reply is SendPort) reply.send('ok');
    } on Object catch (error) {
      Diagnostics.log('geofence', 'relay handle failed error=$error');
      if (reply is SendPort) reply.send('error:$error');
    }
  }
}

/// 영역 콜백 처리 — 직렬화와 "사라지지 않는 기록" (이슈 #231)
///
/// 받은 장소마다 **처리 완료 또는 실패가 반드시 한 줄 남는다.** 실기기에서
/// `received` 뒤에 아무 기록 없이 사라진 이벤트가 있었다 — 무엇이 일어났는지
/// 영영 알 수 없는 것이 가장 나쁘다.
class RegionCallbackHandler {
  RegionCallbackHandler({
    required Future<bool> Function(RegionEvent event) relay,
    required Future<void> Function(RegionEvent event) handleLocally,
    SerialTaskQueue? queue,
    this.idleGrace = const Duration(milliseconds: 300),
  }) : _relay = relay,
       _handleLocally = handleLocally,
       _queue = queue ?? SerialTaskQueue();

  final Future<bool> Function(RegionEvent event) _relay;
  final Future<void> Function(RegionEvent event) _handleLocally;
  final SerialTaskQueue _queue;
  final Duration idleGrace;

  /// 아직 끝나지 않은 이벤트 수 — 0 일 때만 자원을 정리한다
  int get pending => _queue.pending;

  /// 이벤트들을 큐에 넣고, **이 isolate 의 모든 작업이 끝날 때까지** 기다린다.
  Future<void> handle(List<RegionEvent> events) async {
    await Future.wait([
      for (final event in events) _queue.run(() => _handleOne(event)),
    ]);
    await _queue.whenIdle(grace: idleGrace);
  }

  Future<void> _handleOne(RegionEvent event) async {
    final id = shortId(event.placeId);
    try {
      if (await _relay(event)) {
        Diagnostics.log(
          'geofence',
          'ios callback handled place=$id event=${event.direction} via=app',
        );
        return;
      }
      await _handleLocally(event);
      Diagnostics.log(
        'geofence',
        'ios callback handled place=$id event=${event.direction} via=callback',
      );
    } on Object catch (error) {
      // 한 장소의 실패가 다른 장소 처리를 막으면 안 된다 — 삼키되 사유는 남긴다
      Diagnostics.log(
        'geofence',
        'ios callback handle failed place=$id event=${event.direction} error=$error',
      );
    }
  }
}
