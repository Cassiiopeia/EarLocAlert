// 도착 알림이 DB 잠김으로 취소된 사고(#337)의 재발 방지 점검.
// 두 연결이 같은 파일에 동시에 쓰는 상황을 재현한다 — 몇 초 안에 끝나는 범위만.
import 'dart:io';
import 'dart:isolate';

import 'package:ear_loc_alert/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

/// 다른 isolate 에서 [holdMilliseconds] 동안 쓰기 잠금을 쥔다
Future<void> _holdWriteLockInOtherIsolate(
  String path,
  int holdMilliseconds,
) async {
  final ready = ReceivePort();
  await Isolate.spawn((List<Object> args) {
    final sendPort = args[0] as SendPort;
    final database = sqlite3.open(args[1] as String);
    configureDatabaseConnection(database);
    database.execute('BEGIN IMMEDIATE;');
    sendPort.send('locked');
    sleep(Duration(milliseconds: args[2] as int));
    database.execute('COMMIT;');
    database.dispose();
  }, [ready.sendPort, path, holdMilliseconds]);
  await ready.first;
}

void main() {
  late Directory directory;
  late String path;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('earloc_db_lock_');
    path = '${directory.path}/lock.sqlite';
    final database = sqlite3.open(path);
    configureDatabaseConnection(database);
    database.execute('CREATE TABLE t (v INTEGER);');
    database.dispose();
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('다른 연결이 쓰기 잠금을 쥐어도 대기 설정이 있으면 쓰기가 성공한다', () async {
    await _holdWriteLockInOtherIsolate(path, 1500);
    final database = sqlite3.open(path);
    configureDatabaseConnection(database);
    final stopwatch = Stopwatch()..start();

    database.execute('INSERT INTO t VALUES (1);');

    expect(stopwatch.elapsedMilliseconds, greaterThan(500)); // 기다렸다 성공
    database.dispose();
  });

  test('대조군: 대기 설정이 없으면 같은 상황에서 즉시 잠김 오류가 난다', () async {
    await _holdWriteLockInOtherIsolate(path, 1500);
    final database = sqlite3.open(path); // configureDatabaseConnection 없음

    expect(
      () => database.execute('INSERT INTO t VALUES (1);'),
      throwsA(
        isA<SqliteException>().having(
          (error) => error.message,
          'message',
          contains('database is locked'),
        ),
      ),
    );
    database.dispose();
  });
}
