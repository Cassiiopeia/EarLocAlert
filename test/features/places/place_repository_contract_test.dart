import 'dart:async';

import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// [PlaceRepository] 계약 테스트.
///
/// Drift 구현 자체는 테스트하지 않는다 — Drift 를 믿는다
/// (docs/04-CONVENTIONS.md). 여기서 검증하는 것은 **인터페이스가 약속한 동작**
/// 이며, 이 테스트를 통과하는 구현이면 화면이 기대한 대로 동작한다.
class InMemoryPlaceRepository implements PlaceRepository {
  final Map<String, AlertPlace> _store = {};
  final _controller = StreamController<List<AlertPlace>>.broadcast();

  List<AlertPlace> get _sorted =>
      _store.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  void _emit() => _controller.add(_sorted);

  @override
  Future<List<AlertPlace>> findAll() async => _sorted;

  @override
  Future<List<AlertPlace>> findEnabled() async =>
      _sorted.where((p) => p.enabled).toList();

  @override
  Future<AlertPlace?> findById(String id) async => _store[id];

  @override
  Future<void> save(AlertPlace place) async {
    _store[place.id] = place;
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _store.remove(id);
    _emit();
  }

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {
    final place = _store[id];
    if (place == null) return;
    _store[id] = place.copyWith(enabled: enabled);
    _emit();
  }

  @override
  Future<int> count() async => _store.length;

  @override
  Stream<List<AlertPlace>> watchAll() => _controller.stream;

  void dispose() => _controller.close();
}

AlertPlace makePlace({
  required String id,
  String name = '장소',
  bool enabled = true,
  int createdAtOffsetMinutes = 0,
}) {
  return AlertPlace(
    id: id,
    name: name,
    latitude: 37.5663,
    longitude: 126.9779,
    radiusMeters: 100,
    direction: AlertDirection.both,
    enabled: enabled,
    createdAt: DateTime.utc(
      2026,
      8,
      3,
      12,
    ).add(Duration(minutes: createdAtOffsetMinutes)),
  );
}

void main() {
  late InMemoryPlaceRepository repo;

  setUp(() => repo = InMemoryPlaceRepository());
  tearDown(() => repo.dispose());

  group('PlaceRepository 계약', () {
    test('저장한 장소를 id 로 조회할 수 있다', () async {
      await repo.save(makePlace(id: 'a', name: '학원'));

      final found = await repo.findById('a');
      expect(found?.name, '학원');
    });

    test('없는 id 조회는 null 이다 — 예외를 던지지 않는다', () async {
      expect(await repo.findById('없음'), isNull);
    });

    test('같은 id 로 저장하면 덮어쓴다', () async {
      await repo.save(makePlace(id: 'a', name: '이전'));
      await repo.save(makePlace(id: 'a', name: '이후'));

      expect(await repo.count(), 1);
      expect((await repo.findById('a'))?.name, '이후');
    });

    test('findAll 은 생성 시각 오름차순이다', () async {
      await repo.save(makePlace(id: 'b', createdAtOffsetMinutes: 10));
      await repo.save(makePlace(id: 'a', createdAtOffsetMinutes: 0));

      final all = await repo.findAll();
      expect(all.map((p) => p.id), ['a', 'b']);
    });

    test('findEnabled 는 비활성 장소를 제외한다 (F1.7)', () async {
      await repo.save(makePlace(id: 'on'));
      await repo.save(makePlace(id: 'off', enabled: false));

      final enabled = await repo.findEnabled();
      expect(enabled.map((p) => p.id), ['on']);
    });

    test('setEnabled 는 장소를 지우지 않고 상태만 바꾼다', () async {
      await repo.save(makePlace(id: 'a'));

      await repo.setEnabled('a', enabled: false);

      expect(await repo.count(), 1, reason: '삭제되면 안 된다');
      expect((await repo.findById('a'))?.enabled, isFalse);
      expect(await repo.findEnabled(), isEmpty);
    });

    test('없는 id 에 setEnabled 해도 죽지 않는다', () async {
      await repo.setEnabled('없음', enabled: false);
      expect(await repo.count(), 0);
    });

    test('delete 후에는 조회되지 않는다', () async {
      await repo.save(makePlace(id: 'a'));
      await repo.delete('a');

      expect(await repo.findById('a'), isNull);
      expect(await repo.count(), 0);
    });

    test('count 는 iOS 20개 제한 확인에 쓸 수 있다', () async {
      for (var i = 0; i < 20; i++) {
        await repo.save(makePlace(id: 'p$i', createdAtOffsetMinutes: i));
      }
      expect(await repo.count(), 20);
    });

    test('watchAll 은 변경 시마다 목록을 흘려보낸다', () async {
      final emitted = <int>[];
      final sub = repo.watchAll().listen((list) => emitted.add(list.length));

      await repo.save(makePlace(id: 'a'));
      await repo.save(makePlace(id: 'b', createdAtOffsetMinutes: 1));
      await repo.delete('a');
      await Future<void>.delayed(Duration.zero);

      expect(emitted, [1, 2, 1]);
      await sub.cancel();
    });
  });
}
