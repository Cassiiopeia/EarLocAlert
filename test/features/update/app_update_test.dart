import 'dart:convert';

import 'package:ear_loc_alert/features/update/data/github_release_service.dart';
import 'package:ear_loc_alert/features/update/domain/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

/// 앱 업데이트 (이슈 #104)
///
/// 네트워크 없이 판정 전체를 검증한다 — 버전 비교와 응답 파싱이
/// 순수 함수라서 가능하다.
void main() {
  group('AppVersion 파싱', () {
    test('태그 표기가 흔들려도 읽어낸다', () {
      expect(AppVersion.parse('v1.7.2'), const AppVersion(1, 7, 2));
      expect(AppVersion.parse('1.7.2'), const AppVersion(1, 7, 2));
      expect(AppVersion.parse('1.7.2+84'), const AppVersion(1, 7, 2));
      expect(AppVersion.parse('v1.7.2-beta'), const AppVersion(1, 7, 2));
      expect(AppVersion.parse(' v1.7.2 '), const AppVersion(1, 7, 2));
    });

    test('읽을 수 없으면 null 이다 — 받을 수 없는 업데이트를 권하지 않는다', () {
      expect(AppVersion.parse(null), isNull);
      expect(AppVersion.parse(''), isNull);
      expect(AppVersion.parse('latest'), isNull);
      expect(AppVersion.parse('1.7'), isNull);
    });
  });

  group('AppVersion 비교', () {
    test('자릿수가 늘어도 숫자로 비교한다', () {
      // 문자열 비교였다면 1.10.0 < 1.9.0 이 되어
      // 새 버전이 영영 보이지 않는다
      expect(
        const AppVersion(1, 10, 0).isNewerThan(const AppVersion(1, 9, 0)),
        isTrue,
      );
      expect(
        const AppVersion(1, 7, 10).isNewerThan(const AppVersion(1, 7, 9)),
        isTrue,
      );
      expect(
        const AppVersion(2, 0, 0).isNewerThan(const AppVersion(1, 99, 99)),
        isTrue,
      );
    });

    test('같은 버전은 새 버전이 아니다', () {
      expect(
        const AppVersion(1, 7, 2).isNewerThan(const AppVersion(1, 7, 2)),
        isFalse,
      );
    });

    test('낮은 버전은 새 버전이 아니다 — 롤백을 권하면 안 된다', () {
      expect(
        const AppVersion(1, 7, 1).isNewerThan(const AppVersion(1, 7, 2)),
        isFalse,
      );
    });
  });

  group('릴리스 응답 파싱', () {
    String body({
      String tag = 'v1.8.0',
      List<Map<String, String>> assets = const [],
      String notes = '변경 내용',
    }) {
      return jsonEncode({'tag_name': tag, 'assets': assets, 'body': notes});
    }

    test('태그와 APK 주소와 노트를 읽는다', () {
      final release = GithubReleaseService.parseRelease(
        body(
          assets: [
            {
              'name': 'EarLocAlert-v1.8.0-abc.apk',
              'browser_download_url': 'https://example.com/app.apk',
            },
          ],
        ),
      );

      expect(release, isNotNull);
      expect(release!.version, const AppVersion(1, 8, 0));
      expect(release.apkUrl, 'https://example.com/app.apk');
      expect(release.notes, '변경 내용');
      expect(release.hasApk, isTrue);
    });

    test('APK 가 아닌 자산은 건너뛴다', () {
      final release = GithubReleaseService.parseRelease(
        body(
          assets: [
            {
              'name': 'mapping.txt',
              'browser_download_url': 'https://example.com/mapping.txt',
            },
            {
              'name': 'app.apk',
              'browser_download_url': 'https://example.com/app.apk',
            },
          ],
        ),
      );

      expect(release!.apkUrl, 'https://example.com/app.apk');
    });

    test('APK 가 없으면 hasApk 가 false 다 — 받을 것이 없다', () {
      final release = GithubReleaseService.parseRelease(body());

      expect(release, isNotNull);
      expect(release!.hasApk, isFalse);
    });

    test('태그를 읽을 수 없으면 null 이다', () {
      expect(GithubReleaseService.parseRelease(body(tag: 'latest')), isNull);
      expect(GithubReleaseService.parseRelease('{}'), isNull);
      expect(GithubReleaseService.parseRelease('[]'), isNull);
    });

    test('노트가 없어도 파싱은 성공한다', () {
      final release = GithubReleaseService.parseRelease(
        jsonEncode({'tag_name': 'v1.8.0'}),
      );

      expect(release, isNotNull);
      expect(release!.notes, isEmpty);
    });
  });
}
