import 'dart:async';

import 'package:ear_loc_alert/core/di/providers.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state.dart';
import 'package:ear_loc_alert/features/geofence/domain/geofence_state_repository.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:ear_loc_alert/features/places/presentation/place_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 편집 화면에서 장소를 삭제한다 (이슈 #205)
///
/// 스와이프를 모르는 사용자도 삭제를 찾을 수 있어야 한다. 대신 편집 중인
/// 화면이라 오탭하기 쉬워 **확인을 한 번 받고**, 지운 뒤에는 목록 화면에서
/// "되돌리기"를 줄 수 있어야 한다.
void main() {
  final existing = AlertPlace(
    id: 'p1',
    name: '회사',
    latitude: 37.5,
    longitude: 127.0,
    radiusMeters: 100,
    direction: AlertDirection.enter,
    createdAt: DateTime.utc(2026),
  );

  late _FakePlaceRepository repo;
  late _FakeStateRepository states;
  late int deletedCallbacks;

  setUp(() {
    repo = _FakePlaceRepository()..items = [existing];
    states = _FakeStateRepository();
    deletedCallbacks = 0;
  });

  /// 홈에서 폼을 push 한 상태로 띄운다 — 실제 앱과 같은 스택이다
  Future<void> pumpPushed(WidgetTester tester, {AlertPlace? place}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placeRepositoryProvider.overrideWithValue(repo),
          geofenceStateRepositoryProvider.overrideWithValue(states),
        ],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (formContext) => PlaceFormScreen(
                        existing: place,
                        // 라우터가 하는 일을 흉내낸다 — 화면을 닫는다
                        onDeleted: () {
                          deletedCallbacks++;
                          Navigator.of(formContext).pop();
                        },
                      ),
                    ),
                  ),
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
  }

  Future<void> tapDelete(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('이 장소 삭제'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('이 장소 삭제'));
    await tester.pumpAndSettle();
  }

  testWidgets('신규 등록에는 삭제 버튼이 없다 — 지울 것이 아직 없다', (tester) async {
    await pumpPushed(tester);

    expect(find.text('이 장소 삭제'), findsNothing);
  });

  testWidgets('편집 화면에는 삭제 버튼이 있고 누르면 먼저 확인을 받는다', (tester) async {
    await pumpPushed(tester, place: existing);

    await tapDelete(tester);

    expect(find.text('이 장소를 삭제할까요?'), findsOneWidget);
    // 확인 전에는 지워지지 않는다
    expect(repo.deleted, isEmpty);
  });

  testWidgets('확인 창에서 취소하면 아무 일도 일어나지 않는다', (tester) async {
    await pumpPushed(tester, place: existing);

    await tapDelete(tester);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();

    expect(repo.deleted, isEmpty);
    expect(deletedCallbacks, 0);
    expect(find.byType(PlaceFormScreen), findsOneWidget);
  });

  testWidgets('삭제하면 저장소와 지오펜스 상태에서 지우고 화면이 닫힌다', (tester) async {
    states.states['p1'] = GeofenceState.inside;
    await pumpPushed(tester, place: existing);

    await tapDelete(tester);
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['p1']);
    // 장소가 사라지면 지오펜스 상태도 함께 지운다 (docs/03-DOMAIN.md)
    expect(states.states.containsKey('p1'), isFalse);
    expect(deletedCallbacks, 1);
    expect(find.byType(PlaceFormScreen), findsNothing);
  });

  testWidgets('지운 뒤 이전 화면에 되돌리기 안내가 뜬다 — 닫힌 폼의 context 를 쓰지 않는다', (
    tester,
  ) async {
    await pumpPushed(tester, place: existing);

    await tapDelete(tester);
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    expect(find.text("'회사' 삭제됨"), findsOneWidget);
    expect(find.text('되돌리기'), findsOneWidget);

    // 되돌리기를 누르면 같은 장소가 다시 저장된다
    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(repo.saved.map((p) => p.id), ['p1']);
  });

  testWidgets('이름을 고치던 중에 삭제해도 저장하지 않고 나간다는 확인이 또 뜨지 않는다', (tester) async {
    await pumpPushed(tester, place: existing);

    await tester.enterText(find.byType(TextField).first, '집');
    await tester.pumpAndSettle();
    await tapDelete(tester);
    await tester.tap(find.widgetWithText(TextButton, '삭제'));
    await tester.pumpAndSettle();

    // 지울 장소의 편집 내용은 의미가 없다
    expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
    expect(find.byType(PlaceFormScreen), findsNothing);
  });
}

class _FakePlaceRepository implements PlaceRepository {
  List<AlertPlace> items = [];
  final deleted = <String>[];
  final saved = <AlertPlace>[];

  @override
  Future<AlertPlace?> findById(String id) async =>
      items.where((p) => p.id == id).firstOrNull;

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    items.removeWhere((p) => p.id == id);
  }

  @override
  Future<void> save(AlertPlace place) async => saved.add(place);

  @override
  Future<List<AlertPlace>> findAll() async => List.of(items);

  @override
  Future<List<AlertPlace>> findEnabled() async =>
      items.where((p) => p.enabled).toList();

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {}

  @override
  Future<int> count() async => items.length;

  @override
  Stream<List<AlertPlace>> watchAll() => const Stream.empty();
}

class _FakeStateRepository implements GeofenceStateRepository {
  final Map<String, GeofenceState> states = {};

  @override
  Future<GeofenceState> stateOf(String placeId) async =>
      states[placeId] ?? GeofenceState.unknown;

  @override
  Future<Map<String, GeofenceState>> allStates() async => Map.of(states);

  @override
  Future<void> updateState(String placeId, GeofenceState state) async =>
      states[placeId] = state;

  @override
  Future<void> remove(String placeId) async => states.remove(placeId);
}
