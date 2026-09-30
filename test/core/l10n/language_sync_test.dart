import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/core/l10n/app_language.dart';

/// 언어마다 있어야 하는 플랫폼별 자리 (이슈 #173)
///
/// **언어를 늘릴 때 가장 빠뜨리기 쉬운 것은 네이티브 쪽이다.** 안드로이드 알림이
/// 앱과 다른 언어로 나오거나 스토어 릴리스 노트가 비어도 앱은 멀쩡히 돌아서
/// 아무도 모른다. `AppLanguage` 에 언어를 더하면 아래 표에 행을 더하도록 강제하고,
/// 행마다 실제 파일이 있는지 본다.
class _Places {
  const _Places({
    required this.androidRes,
    required this.iosLproj,
    required this.playLocale,
  });

  /// 안드로이드 `res/` 아래 폴더 (기본 언어는 `values`)
  final String androidRes;

  /// iOS `Runner/` 아래 폴더 이름(확장자 제외)
  final String iosLproj;

  /// Play 스토어 언어 코드 — 릴리스 노트 폴더와 스토어 본문 파일 이름
  final String playLocale;
}

const _places = <String, _Places>{
  'ko': _Places(androidRes: 'values-ko', iosLproj: 'ko', playLocale: 'ko-KR'),
  'en': _Places(androidRes: 'values', iosLproj: 'en', playLocale: 'en-US'),
  'zh': _Places(
    androidRes: 'values-zh-rCN',
    iosLproj: 'zh-Hans',
    playLocale: 'zh-CN',
  ),
  'ja': _Places(androidRes: 'values-ja', iosLproj: 'ja', playLocale: 'ja-JP'),
};

/// `<string name="x">` 의 이름 집합
Set<String> _androidStringNames(String path) => RegExp(
  r'<string name="([^"]+)"',
).allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!).toSet();

/// `"KEY" = "..."` 의 키 집합
Set<String> _iosKeys(String path) => RegExp(
  r'^"([^"]+)"\s*=',
  multiLine: true,
).allMatches(File(path).readAsStringSync()).map((m) => m.group(1)!).toSet();

void main() {
  final codes = [
    for (final language in AppLanguage.supported) language.storageValue,
  ];
  const kotlin =
      'android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert/AppLocale.kt';
  final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();
  final pbxproj = File(
    'ios/Runner.xcodeproj/project.pbxproj',
  ).readAsStringSync();

  test('지원하는 모든 언어가 이 표에 있다 — 없으면 행을 더한다', () {
    for (final code in codes) {
      expect(
        _places.containsKey(code),
        isTrue,
        reason: '$code 의 플랫폼 자리를 _places 표에 더한다',
      );
    }
  });

  for (final code in codes) {
    final place = _places[code];
    if (place == null) continue;

    group('$code 언어의 자리', () {
      test('번역 파일이 있다', () {
        expect(File('lib/core/l10n/arb/app_$code.arb').existsSync(), isTrue);
      });

      test('안드로이드 문자열이 기본(영어)과 같은 이름을 다 갖는다', () {
        final base = _androidStringNames(
          'android/app/src/main/res/values/strings.xml',
        );
        final own = _androidStringNames(
          'android/app/src/main/res/${place.androidRes}/strings.xml',
        );
        expect(base.difference(own), isEmpty, reason: '번역이 빠진 알림 문구');
      });

      test('안드로이드 알림이 앱에서 고른 언어를 안다 (AppLocale.kt)', () {
        expect(
          File(kotlin).readAsStringSync(),
          contains('"$code" ->'),
          reason: '앱은 $code 인데 알림만 기기 언어로 나온다',
        );
      });

      test('iOS 권한 문구가 영어와 같은 키를 다 갖고 선언돼 있다', () {
        final base = _iosKeys('ios/Runner/en.lproj/InfoPlist.strings');
        final own = _iosKeys(
          'ios/Runner/${place.iosLproj}.lproj/InfoPlist.strings',
        );
        expect(base.difference(own), isEmpty, reason: '번역이 빠진 권한 문구');
        expect(
          infoPlist,
          contains('<string>${place.iosLproj}</string>'),
          reason: 'Info.plist CFBundleLocalizations 에 없다',
        );
        expect(
          pbxproj,
          contains('/* ${place.iosLproj} */'),
          reason: 'Xcode 프로젝트에 등록되지 않았다',
        );
      });

      test('릴리스 노트 폴더와 스토어 본문이 있다', () {
        final notes = Directory('release-notes/${place.playLocale}');
        expect(notes.existsSync(), isTrue, reason: '배포 스크립트가 이 폴더를 본다');
        expect(
          File(
            'docs/store/descriptions/${place.playLocale}_full.txt',
          ).existsSync(),
          isTrue,
        );
      });
    });
  }
}
