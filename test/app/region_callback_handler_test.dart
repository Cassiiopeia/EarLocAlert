import 'dart:async';
import 'dart:isolate';

import 'package:ear_loc_alert/app/background/region_event_relay.dart';
import 'package:ear_loc_alert/app/background/serial_task_queue.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostic_logger.dart';
import 'package:ear_loc_alert/core/diagnostics/diagnostics.dart';
import 'package:flutter_test/flutter_test.dart';

/// iOS 영역 콜백 직렬화 (이슈 #231)
///
/// 실기기에서 같은 초에 세 콜백이 들어왔고, 그중 하나는 `received` 만 남기고
/// 사라졌다. 콜백마다 판정기를 새로 만들어 직렬화가 콜백 사이를 막지 못했고,
/// 먼저 끝난 콜백이 엔진 파괴를 불렀다. 이 테스트가 세 가지를 지킨다:
/// 동시에 들어와도 하나씩 돈다 · 모든 id 가 끝 기록을 남긴다 · 모든 작업이
/// 끝나기 전에는 어떤 콜백도 돌아가지 않는다.
void main() {
  late _RecordingLogger logger;

  setUp(() {
    Diagnostics.resetForTest();
    logger = _RecordingLogger();
    Diagnostics.overrideLogger(logger);
  });

  tearDown(Diagnostics.resetForTest);

  RegionEvent event(String id, {bool entered = true}) =>
      RegionEvent(placeId: id, entered: entered);

  test('동시에 들어온 콜백도 하나씩 돌고, 모든 id 가 처리 기록을 남긴다', () async {
    var running = 0;
    var maxRunning = 0;
    final handled = <String>[];
    final handler = RegionCallbackHandler(
      relay: (_) async => false,
      handleLocally: (e) async {
        running++;
        maxRunning = running > maxRunning ? running : maxRunning;
        // DB 쓰기처럼 시간이 걸리는 판정
        await Future<void>.delayed(const Duration(milliseconds: 5));
        handled.add(e.placeId);
        running--;
      },
      idleGrace: const Duration(milliseconds: 1),
    );

    // 실기기와 같은 모양 — 세 콜백이 거의 동시에
    await Future.wait([
      handler.handle([event('01a11647', entered: false)]),
      handler.handle([event('bbbbbbbb')]),
      handler.handle([event('cccccccc')]),
    ]);

    expect(maxRunning, 1);
    expect(handled, ['01a11647', 'bbbbbbbb', 'cccccccc']);
    for (final id in ['01a11647', 'bbbbbbbb', 'cccccccc']) {
      expect(
        logger.lines.where((l) => l.contains('ios callback handled place=$id')),
        hasLength(1),
        reason: '$id 의 끝 기록이 없으면 무슨 일이 있었는지 영영 모른다',
      );
    }
  });

  test('먼저 들어온 콜백도 뒤에 들어온 작업이 끝날 때까지 돌아가지 않는다', () async {
    final slow = Completer<void>();
    final handler = RegionCallbackHandler(
      relay: (_) async => false,
      handleLocally: (e) async {
        if (e.placeId == 'second') await slow.future;
      },
      idleGrace: const Duration(milliseconds: 1),
    );

    var firstReturned = false;
    final first = handler
        .handle([event('first')])
        .then((_) => firstReturned = true);
    final second = handler.handle([event('second')]);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    // 'first' 의 판정은 끝났지만 콜백은 아직 돌아가면 안 된다 — 돌아가면
    // 플러그인이 엔진을 파괴해 'second' 가 기록 없이 사라진다
    expect(firstReturned, isFalse);

    slow.complete();
    await Future.wait([first, second]);
    expect(firstReturned, isTrue);
    expect(
      logger.lines.where((l) => l.contains('ios callback handled')),
      hasLength(2),
    );
  });

  test('한 장소가 실패해도 기록을 남기고 다음 장소를 처리한다', () async {
    final handled = <String>[];
    final handler = RegionCallbackHandler(
      relay: (_) async => false,
      handleLocally: (e) async {
        if (e.placeId == 'broken') throw StateError('db locked');
        handled.add(e.placeId);
      },
      idleGrace: const Duration(milliseconds: 1),
    );

    await handler.handle([event('broken'), event('ok')]);

    expect(handled, ['ok']);
    expect(
      logger.lines.singleWhere(
        (l) => l.contains('ios callback handle failed place=broken'),
      ),
      contains('db locked'),
    );
  });

  test('앱 isolate 가 받으면 직접 판정하지 않는다 — 판정기는 하나다', () async {
    var local = 0;
    final handler = RegionCallbackHandler(
      relay: (_) async => true,
      handleLocally: (_) async => local++,
      idleGrace: const Duration(milliseconds: 1),
    );

    await handler.handle([event('a')]);

    expect(local, 0);
    expect(logger.lines.last, contains('via=app'));
  });

  group('relayRegionEventToApp', () {
    test('포트가 없으면 false — 호출자가 직접 판정한다', () async {
      final relayed = await relayRegionEventToApp(
        event('a'),
        lookup: (_) => null,
      );

      expect(relayed, isFalse);
    });

    test('수신기가 처리하고 ok 를 답하면 true', () async {
      final received = <RegionEvent>[];
      final port = ReceivePort();
      port.listen((message) {
        final map = message as Map;
        received.add(
          RegionEvent(
            placeId: map['placeId'] as String,
            entered: map['entered'] as bool,
          ),
        );
        (map['reply'] as SendPort).send('ok');
      });

      final relayed = await relayRegionEventToApp(
        event('a', entered: false),
        lookup: (_) => port.sendPort,
      );
      port.close();

      expect(relayed, isTrue);
      expect(received.single.placeId, 'a');
      expect(received.single.entered, isFalse);
    });

    test('죽은 포트처럼 답이 없으면 시간 초과 후 false', () async {
      final port = ReceivePort(); // 듣기만 하고 답하지 않는다
      final relayed = await relayRegionEventToApp(
        event('a'),
        lookup: (_) => port.sendPort,
        timeout: const Duration(milliseconds: 20),
      );
      port.close();

      expect(relayed, isFalse);
      expect(logger.lines.last, contains('reason=timeout'));
    });
  });

  group('SerialTaskQueue', () {
    test('실패해도 큐가 끊기지 않는다', () async {
      final queue = SerialTaskQueue();
      final failed = queue.run<void>(() async => throw StateError('x'));
      final after = queue.run(() async => 42);

      await expectLater(failed, throwsStateError);
      expect(await after, 42);
      expect(queue.pending, 0);
    });
  });
}

class _RecordingLogger implements DiagnosticLogger {
  final List<String> lines = [];

  @override
  Future<void> log(String tag, String message) async =>
      lines.add('[$tag] $message');

  @override
  Future<String> readAll() async => lines.join('\n');

  @override
  Future<void> clear() async => lines.clear();
}
