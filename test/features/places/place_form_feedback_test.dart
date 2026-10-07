import 'package:ear_loc_alert/core/di/providers.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/theme/app_theme.dart';
import 'package:ear_loc_alert/features/places/domain/alert_place.dart';
import 'package:ear_loc_alert/features/places/domain/place_repository.dart';
import 'package:ear_loc_alert/features/places/domain/place_search.dart';
import 'package:ear_loc_alert/features/places/presentation/place_form_screen.dart';
import 'package:ear_loc_alert/features/places/presentation/place_map_picker_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 장소 폼의 입력 피드백 (이슈 #228)
///
/// - 이름 없이 등록하면 **이름 칸에** 오류가 붙고 포커스가 간다
/// - 검색으로 고른 장소 이름을 빈 이름 칸에만 제안한다
/// - 좌표 칸은 소수 6자리로 보이되, 고치지 않으면 원래 값이 유지된다
void main() {
  late _FakePlaceRepository repo;

  setUp(() => repo = _FakePlaceRepository());

  Future<void> pumpForm(WidgetTester tester, PlaceFormScreen form) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [placeRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          locale: const Locale('ko'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.dark(),
          home: form,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// 등록 버튼은 폼 맨 아래라 테스트 화면(800×600) 밖에 있다 — 내려서 누른다
  Future<void> tapSubmit(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('등록'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.text('등록'));
    await tester.pumpAndSettle();
  }

  TextField nameField(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first);

  group('이름 없이 등록', () {
    testWidgets('좌표가 없어도 이름 칸에 오류를 붙이고 포커스를 준다', (tester) async {
      await pumpForm(tester, const PlaceFormScreen());

      await tapSubmit(tester);

      // 토스트만으로는 어느 칸이 문제인지 알 수 없었다
      expect(nameField(tester).decoration!.errorText, '이름을 입력해주세요');
      expect(nameField(tester).focusNode!.hasFocus, isTrue);
    });

    testWidgets('좌표가 있으면 저장소 검증 결과로 이름 칸에 오류를 붙인다', (tester) async {
      await pumpForm(
        tester,
        PlaceFormScreen(
          onPickOnMap: (_) async => const MapPickResult(
            latitude: 37.5,
            longitude: 127,
            radiusMeters: 100,
          ),
        ),
      );
      await tester.tap(find.text('지도에서 선택'));
      await tester.pumpAndSettle();

      await tapSubmit(tester);

      expect(nameField(tester).decoration!.errorText, '이름을 입력해주세요');
      expect(repo.saved, isEmpty);
      // 이름 칸이 화면 안으로 돌아와야 한다
      expect(tester.getRect(find.byType(TextField).first).top, greaterThan(0));
    });

    testWidgets('이름을 쓰기 시작하면 오류를 거둔다', (tester) async {
      await pumpForm(tester, const PlaceFormScreen());
      await tapSubmit(tester);

      await tester.enterText(find.byType(TextField).first, '집');
      await tester.pump();

      expect(nameField(tester).decoration!.errorText, isNull);
    });
  });

  group('검색 결과 이름 제안', () {
    PlaceFormScreen formReturning(String? placeName, {AlertPlace? existing}) =>
        PlaceFormScreen(
          existing: existing,
          onPickOnMap: (_) async => MapPickResult(
            latitude: 37.497952,
            longitude: 127.027619,
            radiusMeters: 100,
            placeName: placeName,
          ),
        );

    testWidgets('이름이 비어 있으면 고른 장소 이름으로 채운다', (tester) async {
      await pumpForm(tester, formReturning('강남역'));

      await tester.tap(find.text('지도에서 선택'));
      await tester.pumpAndSettle();

      expect(nameField(tester).controller!.text, '강남역');
    });

    testWidgets('사용자가 쓴 이름은 덮지 않는다', (tester) async {
      await pumpForm(tester, formReturning('강남역'));
      await tester.enterText(find.byType(TextField).first, '회사 앞 정류장');

      await tester.tap(find.text('지도에서 선택'));
      await tester.pumpAndSettle();

      expect(nameField(tester).controller!.text, '회사 앞 정류장');
    });

    testWidgets('검색 없이 고르면 이름을 건드리지 않는다', (tester) async {
      await pumpForm(tester, formReturning(null));

      await tester.tap(find.text('지도에서 선택'));
      await tester.pumpAndSettle();

      expect(nameField(tester).controller!.text, isEmpty);
    });
  });

  group('좌표 칸 표시', () {
    final precise = AlertPlace(
      id: 'p1',
      name: '강남역',
      latitude: 37.49789989126091,
      longitude: 127.02761650085449,
      radiusMeters: 100,
      direction: AlertDirection.enter,
      createdAt: DateTime.utc(2026),
    );

    String fieldText(WidgetTester tester, String label) => tester
        .widget<TextField>(find.widgetWithText(TextField, label))
        .controller!
        .text;

    Future<void> openCoordinates(WidgetTester tester) async {
      await tester.tap(find.textContaining('좌표'));
      await tester.pumpAndSettle();
    }

    testWidgets('편집 화면은 소수 6자리로 보여준다', (tester) async {
      await pumpForm(tester, PlaceFormScreen(existing: precise));
      await openCoordinates(tester);

      expect(fieldText(tester, '위도'), '37.497900');
      expect(fieldText(tester, '경도'), '127.027617');
    });

    testWidgets('지도에서 고른 값도 소수 6자리로 넣는다', (tester) async {
      await pumpForm(
        tester,
        PlaceFormScreen(
          onPickOnMap: (_) async => const MapPickResult(
            latitude: 37.49789989126091,
            longitude: 127.02761650085449,
            radiusMeters: 100,
          ),
        ),
      );
      await tester.tap(find.text('지도에서 선택'));
      await tester.pumpAndSettle();
      await openCoordinates(tester);

      expect(fieldText(tester, '위도'), '37.497900');
      expect(fieldText(tester, '경도'), '127.027617');
    });

    testWidgets('줄여 보여줘도 열기만 한 편집은 바뀐 것으로 보지 않는다', (tester) async {
      // 줄인 값으로 비교하면 원래 좌표와 달라 "저장하지 않고 나갈까요?" 가 뜬다
      await tester.pumpWidget(
        ProviderScope(
          overrides: [placeRepositoryProvider.overrideWithValue(repo)],
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
                        builder: (_) => PlaceFormScreen(existing: precise),
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

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();

      expect(find.text('저장하지 않고 나갈까요?'), findsNothing);
      expect(find.byType(PlaceFormScreen), findsNothing);
    });
  });

  testWidgets('지도 선택은 고른 검색 결과의 이름을 돌려준다', (tester) async {
    MapPickResult? picked;
    await tester.binding.setSurfaceSize(const Size(411, 914));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ko'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.dark(),
        home: PlaceMapPickerScreen(
          args: const MapPickArgs(
            latitude: 37.5,
            longitude: 127,
            radiusMeters: 100,
          ),
          searchService: _FakeSearchService(),
          onPicked: (result) => picked = result,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '강남');
    // 검색은 입력이 멈춘 뒤에 나간다
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('강남역'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('이 위치로 선택'));
    await tester.pumpAndSettle();

    expect(picked?.placeName, '강남역');
  });
}

class _FakeSearchService implements PlaceSearchService {
  @override
  Future<List<PlaceSearchResult>> search(
    String query, {
    required String languageCode,
  }) async => const [
    PlaceSearchResult(
      name: '강남역',
      address: '서울 강남구 강남대로 396',
      latitude: 37.497952,
      longitude: 127.027619,
    ),
  ];
}

class _FakePlaceRepository implements PlaceRepository {
  final saved = <AlertPlace>[];

  @override
  Future<AlertPlace?> findById(String id) async => null;

  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> save(AlertPlace place) async => saved.add(place);

  @override
  Future<List<AlertPlace>> findAll() async => const [];

  @override
  Future<List<AlertPlace>> findEnabled() async => const [];

  @override
  Future<void> setEnabled(String id, {required bool enabled}) async {}

  @override
  Future<int> count() async => 0;

  @override
  Stream<List<AlertPlace>> watchAll() => const Stream.empty();
}
