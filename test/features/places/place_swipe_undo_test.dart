import 'package:ear_loc_alert/core/di/providers.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state_repository.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:ear_loc_alert/features/places/presentation/place_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 목록에서 카드를 밀어 지우면 "되돌리기" 안내가 떠야 한다 (이슈 #205)
///
/// 지도 홈의 목록과 **같은 배선**이다 — `onDelete` 가 `deletePlaceWithUndo` 를
/// 부르고, 목록은 저장소 스트림을 따라간다. 카드가 스스로 접은 뒤 저장소
/// 갱신이 와도 안내가 살아 있어야 한다.
void main() {
  AlertPlace place(String name) => AlertPlace(
    id: name,
    name: name,
    latitude: 37.5,
    longitude: 127.0,
    radiusMeters: 100,
    direction: AlertDirection.enter,
    createdAt: DateTime.utc(2026),
  );

  testWidgets('밀어서 지우면 되돌리기 안내가 뜨고, 누르면 복구된다', (tester) async {
    final repo = _FakeRepo([place('회사'), place('집')]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider.overrideWithValue(repo),
          geofenceStateRepositoryProvider.overrideWithValue(_FakeStates()),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark(),
          home: Scaffold(
            body: StreamBuilder<List<AlertPlace>>(
              stream: repo.watchAll(),
              initialData: repo.items,
              builder: (context, snap) => Consumer(
                builder: (context, ref, _) => ListView(
                  children: [
                    for (final p in snap.data!)
                      PlaceCard(
                        key: ValueKey(p.id),
                        place: p,
                        onTap: () {},
                        onToggle: (_) {},
                        onDelete: () => deletePlaceWithUndo(context, ref, p),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.fling(find.text('집'), const Offset(-600, 0), 2500);
    await tester.pumpAndSettle();

    expect(repo.deleted, ['집']);
    expect(find.text('집'), findsNothing);
    expect(find.text("'집' 삭제됨"), findsOneWidget, reason: '삭제 안내');
    expect(find.text('되돌리기'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(repo.saved.map((p) => p.id), ['집']);
  });
}

class _FakeRepo implements PlaceRepository {
  _FakeRepo(this.items);
  List<AlertPlace> items;
  final deleted = <String>[];
  final saved = <AlertPlace>[];
  final _changes = Stream<List<AlertPlace>>.empty();

  @override
  Future<AlertPlace?> findById(String id) async =>
      items.where((p) => p.id == id).firstOrNull;

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    items = items.where((p) => p.id != id).toList();
  }

  @override
  Future<void> save(AlertPlace place) async {
    saved.add(place);
    items = [...items, place];
  }

  @override
  Future<List<AlertPlace>> findAll() async => List.of(items);

  @override
  Future<List<AlertPlace>> findEnabled() async => List.of(items);

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {}

  @override
  Future<int> count() async => items.length;

  @override
  Stream<List<AlertPlace>> watchAll() => _changes;
}

class _FakeStates implements GeofenceStateRepository {
  @override
  Future<GeofenceState> stateOf(String placeId) async => GeofenceState.unknown;

  @override
  Future<Map<String, GeofenceState>> allStates() async => {};

  @override
  Future<void> updateState(String placeId, GeofenceState state) async {}

  @override
  Future<void> remove(String placeId) async {}
}
