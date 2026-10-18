import 'package:ear_loc_alert/core/ui/foundation/app_theme.dart';
import 'package:ear_loc_alert/features/ads/domain/ad_consent.dart';
import 'package:ear_loc_alert/features/ads/domain/native_strip_ad_loader.dart';
import 'package:ear_loc_alert/features/ads/data/ads_providers.dart';
import 'package:ear_loc_alert/features/ads/presentation/native_strip_ad_slot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 네이티브 띠 슬롯 (이슈 #283)
///
/// 실제 광고 뷰는 플랫폼 뷰라 로더와 그리는 위젯을 가짜로 끼운다.
/// 슬롯이 지켜야 하는 **요청 시점·실패 처리·테마 전환 재로드**만 고정한다.
class _FakeConsent implements AdConsent {
  _FakeConsent(this.canRequest);

  bool canRequest;

  @override
  Future<bool> canRequestAds() async => canRequest;

  @override
  Future<void> gather() async {}

  @override
  Future<bool> isPrivacyOptionsRequired() async => false;

  @override
  Future<void> showPrivacyOptions() async {}
}

class _FakeLoadedAd implements LoadedNativeStripAd {
  bool isDisposed = false;

  @override
  void dispose() => isDisposed = true;
}

class _FakeLoader implements NativeStripAdLoader {
  bool isLoadSuccessful = true;
  final requestedColors = <NativeStripAdColors>[];
  final loadedAds = <_FakeLoadedAd>[];

  @override
  Future<LoadedNativeStripAd?> load(NativeStripAdColors colors) async {
    requestedColors.add(colors);
    if (!isLoadSuccessful) return null;
    final ad = _FakeLoadedAd();
    loadedAds.add(ad);
    return ad;
  }
}

void main() {
  late _FakeConsent consent;
  late _FakeLoader loader;
  late List<bool> loadedReports;

  Widget app({ThemeData? theme}) {
    return ProviderScope(
      overrides: [
        adConsentProvider.overrideWithValue(consent),
        nativeStripAdLoaderProvider.overrideWithValue(loader),
        nativeStripAdViewBuilderProvider.overrideWithValue(
          (loadedAd) => const SizedBox.expand(key: Key('strip-view')),
        ),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.dark(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: NativeStripAdSlot(onLoadedChanged: loadedReports.add),
          ),
        ),
      ),
    );
  }

  setUp(() {
    consent = _FakeConsent(true);
    loader = _FakeLoader();
    loadedReports = [];
  });

  testWidgets('로드되면 높이 44 의 띠를 그리고 부모에게 알린다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    expect(loadedReports, [true]);
    expect(tester.getSize(find.byKey(const Key('strip-view'))).height, 44);
  });

  testWidgets('로드에 실패하면 아무것도 그리지 않고 알리지도 않는다', (tester) async {
    loader.isLoadSuccessful = false;
    await tester.pumpWidget(app());
    await tester.pump();

    expect(find.byKey(const Key('strip-view')), findsNothing);
    expect(loadedReports, isEmpty);
  });

  testWidgets('동의가 확정되기 전에는 요청하지 않고 잠시 뒤 다시 묻는다', (tester) async {
    consent.canRequest = false;
    await tester.pumpWidget(app());
    await tester.pump();
    expect(loader.requestedColors, isEmpty);

    consent.canRequest = true;
    await tester.pump(const Duration(seconds: 8));
    await tester.pump();

    expect(loader.requestedColors, hasLength(1));
    expect(loadedReports, [true]);
  });

  testWidgets('동의 재시도는 세 번에서 멈춘다', (tester) async {
    consent.canRequest = false;
    await tester.pumpWidget(app());
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 8));
    }

    consent.canRequest = true;
    await tester.pump(const Duration(seconds: 8));

    expect(loader.requestedColors, isEmpty);
  });

  testWidgets('라이트·다크가 바뀌면 새 색으로 다시 로드하고 이전 광고를 해제한다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    final darkBackground = loader.requestedColors.single.background;

    await tester.pumpWidget(app(theme: AppTheme.light()));
    // MaterialApp 이 테마를 보간하므로 전환이 끝나야 밝기가 바뀐다
    await tester.pumpAndSettle();

    expect(loader.requestedColors, hasLength(2));
    expect(loader.requestedColors.last.background, isNot(darkBackground));
    expect(loader.loadedAds.first.isDisposed, isTrue);
    expect(loader.loadedAds.last.isDisposed, isFalse);
    expect(find.byKey(const Key('strip-view')), findsOneWidget);
  });

  testWidgets('같은 테마로 다시 빌드해도 다시 요청하지 않는다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();
    await tester.pumpWidget(app());
    await tester.pump();

    expect(loader.requestedColors, hasLength(1));
  });

  testWidgets('화면이 사라지면 광고를 해제한다', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump();

    await tester.pumpWidget(const SizedBox());

    expect(loader.loadedAds.single.isDisposed, isTrue);
  });
}
