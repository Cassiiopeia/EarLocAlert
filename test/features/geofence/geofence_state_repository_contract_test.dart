import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state_repository.dart';
import 'package:flutter_test/flutter_test.dart';

/// [GeofenceStateRepository] 계약 테스트.
///
/// 이 저장소의 계약 중 하나가 이 앱에서 가장 미묘하다 —
/// **저장된 적 없는 장소는 `unknown` 을 돌려줘야 한다.**
/// 이 규칙이 깨지면 앱 시작 직후 이미 반경 안에 있는 사용자에게
/// "방금 진입했다"는 알림이 잘못 발생한다.
class InMemoryGeofenceStateRepository implements GeofenceStateRepository {
  final Map<String, GeofenceState> _store = {};

  @override
  Future<GeofenceState> stateOf(String placeId) async =>
      _store[placeId] ?? GeofenceState.unknown;

  @override
  Future<Map<String, GeofenceState>> allStates() async => Map.of(_store);

  @override
  Future<void> updateState(String placeId, GeofenceState state) async {
    _store[placeId] = state;
  }

  @override
  Future<void> remove(String placeId) async {
    _store.remove(placeId);
  }
}

void main() {
  late InMemoryGeofenceStateRepository repo;

  setUp(() => repo = InMemoryGeofenceStateRepository());

  group('GeofenceStateRepository 계약', () {
    test('저장된 적 없는 장소는 unknown 이다', () async {
      expect(await repo.stateOf('처음'), GeofenceState.unknown);
    });

    test('저장한 상태를 그대로 돌려준다', () async {
      await repo.updateState('a', GeofenceState.outside);
      expect(await repo.stateOf('a'), GeofenceState.outside);
    });

    test('상태는 덮어쓰기다', () async {
      await repo.updateState('a', GeofenceState.outside);
      await repo.updateState('a', GeofenceState.inside);
      expect(await repo.stateOf('a'), GeofenceState.inside);
    });

    test('allStates 는 저장된 장소만 담는다', () async {
      await repo.updateState('a', GeofenceState.inside);
      await repo.updateState('b', GeofenceState.outside);

      final all = await repo.allStates();
      expect(all, {'a': GeofenceState.inside, 'b': GeofenceState.outside});
    });

    test('remove 후에는 다시 unknown 이 된다', () async {
      await repo.updateState('a', GeofenceState.inside);
      await repo.remove('a');
      expect(await repo.stateOf('a'), GeofenceState.unknown);
    });

    test('없는 장소를 remove 해도 죽지 않는다', () async {
      await repo.remove('없음');
      expect(await repo.allStates(), isEmpty);
    });

    test('재부팅 시나리오 — 저장된 outside 가 살아있어야 진입 알림이 가능하다', () async {
      // 재부팅 전: 집 밖에 있었다
      await repo.updateState('집', GeofenceState.outside);

      // 재부팅 후 새 인스턴스가 같은 저장소를 읽는다고 가정
      final restored = await repo.stateOf('집');

      expect(
        restored,
        GeofenceState.outside,
        reason: 'unknown 으로 돌아가면 outside → inside 전이가 사라져 첫 진입 알림을 놓친다',
      );
    });
  });
}
