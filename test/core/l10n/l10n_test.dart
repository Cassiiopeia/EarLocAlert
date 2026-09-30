import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ear_loc_alert/core/l10n/app_language.dart';
import 'package:ear_loc_alert/core/l10n/app_language_controller.dart';
import 'package:ear_loc_alert/core/l10n/app_language_store.dart';
import 'package:ear_loc_alert/core/l10n/l10n.dart';
import 'package:ear_loc_alert/core/l10n/locale_resolver.dart';
import 'package:ear_loc_alert/core/text/keep_all.dart';

/// 다국어 (이슈 #163, docs/superpowers/specs/2026-09-29-i18n-design.md)
/// 지원 언어 코드 — 언어가 늘어도 이 파일을 고치지 않는다 ([AppLanguage.supported])
final _languageCodes = [
  for (final language in AppLanguage.supported) language.storageValue,
];

/// 원문(ko)을 뺀 번역 언어
final _translated = _languageCodes.where((code) => code != 'ko').toList();

void main() {
  group('로케일 해석', () {
    test('기본값은 기기 언어를 따른다', () {
      expect(
        resolveAppLocale(AppLanguage.system, const [Locale('ja', 'JP')]),
        const Locale('ja'),
      );
      expect(
        resolveAppLocale(AppLanguage.system, const [Locale('ko', 'KR')]),
        const Locale('ko'),
      );
    });

    test('사용자가 고른 언어가 기기 언어보다 우선한다', () {
      expect(
        resolveAppLocale(AppLanguage.zh, const [Locale('ko', 'KR')]),
        const Locale('zh'),
      );
    });

    test('지원하지 않는 기기 언어는 영어로 보인다', () {
      expect(
        resolveAppLocale(AppLanguage.system, const [Locale('fr', 'FR')]),
        fallbackAppLocale,
      );
      expect(resolveAppLocale(AppLanguage.system, const []), fallbackAppLocale);
    });

    test('기기 언어 목록에서 처음 지원되는 것을 고른다', () {
      expect(
        resolveAppLocale(AppLanguage.system, const [
          Locale('fr', 'FR'),
          Locale('ja', 'JP'),
          Locale('ko', 'KR'),
        ]),
        const Locale('ja'),
      );
    });

    test('번체 중국어 기기는 간체를 보이지 않고 영어로 보인다 (명세 4-A)', () {
      expect(
        resolveAppLocale(AppLanguage.system, const [Locale('zh', 'TW')]),
        fallbackAppLocale,
      );
      expect(
        resolveAppLocale(AppLanguage.system, const [Locale('zh', 'HK')]),
        fallbackAppLocale,
      );
      expect(
        resolveAppLocale(AppLanguage.system, [
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        ]),
        fallbackAppLocale,
      );
      expect(
        resolveAppLocale(AppLanguage.system, const [Locale('zh', 'CN')]),
        const Locale('zh'),
      );
    });
  });

  group('AppLanguage', () {
    test('모르는 저장 값은 기기 언어를 따른다 — 옛 값으로 앱이 깨지지 않는다', () {
      expect(AppLanguage.parse(null), AppLanguage.system);
      expect(AppLanguage.parse('xx'), AppLanguage.system);
      expect(AppLanguage.parse('ja'), AppLanguage.ja);
    });

    test('각 언어는 자기 표기를 가진다 — 번역하지 않는다', () {
      expect(AppLanguage.ko.nativeName, '한국어');
      expect(AppLanguage.en.nativeName, 'English');
      expect(AppLanguage.zh.nativeName, '中文');
      expect(AppLanguage.ja.nativeName, '日本語');
    });

    test('저장 값은 네이티브와의 계약이다', () {
      // 이 값을 바꾸면 Kotlin 이 읽는 값과 어긋난다 (이슈 #164)
      expect(AppLanguageStore.key, 'app_language');
      expect(AppLanguage.values.map((l) => l.storageValue), [
        'system',
        'ko',
        'en',
        'zh',
        'ja',
      ]);
    });
  });

  group('저장', () {
    test('바꾼 언어는 저장되고 다시 읽힌다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appLanguageControllerProvider), AppLanguage.system);
      await container
          .read(appLanguageControllerProvider.notifier)
          .select(AppLanguage.ja);

      expect(container.read(appLanguageControllerProvider), AppLanguage.ja);
      expect(await const AppLanguageStore().read(), AppLanguage.ja);
    });

    test('시작할 때 읽어 둔 값으로 시작한다 — 첫 프레임 깜빡임이 없다', () {
      final container = ProviderContainer(
        overrides: [
          appLanguageInitialProvider.overrideWithValue(AppLanguage.zh),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(appLanguageControllerProvider), AppLanguage.zh);
    });
  });

  group('번역 파일', () {
    Map<String, dynamic> load(String lang) =>
        jsonDecode(File('lib/core/l10n/arb/app_$lang.arb').readAsStringSync())
            as Map<String, dynamic>;

    Set<String> keys(Map<String, dynamic> arb) =>
        arb.keys.where((k) => !k.startsWith('@')).toSet();

    test('모든 지원 언어의 키가 서로 빠짐없이 같다', () {
      final ko = keys(load('ko'));
      for (final lang in _translated) {
        final other = keys(load(lang));
        expect(ko.difference(other), isEmpty, reason: '$lang 에 없는 키 — 번역이 빠졌다');
        expect(other.difference(ko), isEmpty, reason: '$lang 에만 있는 키');
      }
    });

    test('빈 번역이 없다', () {
      for (final lang in _languageCodes) {
        final arb = load(lang);
        for (final key in keys(arb)) {
          if (key == '@@locale') continue;
          expect(
            (arb[key] as String).trim(),
            isNotEmpty,
            reason: '$lang.$key 가 비어 있다',
          );
        }
      }
    });
  });

  group('한국어 전용 줄바꿈 보호 (결정 037)', () {
    Future<String> keep(WidgetTester tester, Locale? locale) async {
      late String result;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: supportedAppLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Builder(
            builder: (context) {
              result = context.keepAllText('알립니다');
              return const SizedBox();
            },
          ),
        ),
      );
      return result;
    }

    testWidgets('한국어에서는 글자 사이에 줄바꿈 금지 문자를 넣는다', (tester) async {
      expect(await keep(tester, const Locale('ko')), contains('⁠'));
    });

    testWidgets('중국어와 일본어에서는 넣지 않는다 — 줄이 안 바뀌어 넘친다', (tester) async {
      expect(await keep(tester, const Locale('ja')), isNot(contains('⁠')));
      expect(await keep(tester, const Locale('zh')), isNot(contains('⁠')));
      expect(await keep(tester, const Locale('en')), isNot(contains('⁠')));
    });
  });

  group('컨텍스트 없는 조회 (규칙 6)', () {
    test('백그라운드가 언어만으로 문구를 찾는다', () {
      expect(AppStrings.forLocale(const Locale('ko')).languageUndo, '되돌리기');
      expect(AppStrings.forLocale(const Locale('en')).languageUndo, 'Undo');
      expect(AppStrings.forLocale(const Locale('ja')).languageUndo, '元に戻す');
      expect(AppStrings.forLocale(const Locale('zh')).languageUndo, '撤销');
    });

    test('지원하지 않는 언어는 영어다', () {
      expect(AppStrings.forLocale(const Locale('fr')).languageUndo, 'Undo');
    });
  });
}
