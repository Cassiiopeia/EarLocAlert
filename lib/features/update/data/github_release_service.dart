import 'dart:convert';
import 'dart:io';

import '../../../core/diagnostics/diagnostics.dart';
import '../domain/app_update.dart';
import '../domain/app_version.dart';
import 'app_installer_channel.dart';

/// GitHub 릴리스 기반 업데이트 서비스 (이슈 #104)
///
/// 공개 레포의 공개 릴리스만 읽으므로 **토큰이 필요 없다.** 인증을 붙이면
/// 그 순간 앱에 자격 증명을 넣어야 하고, APK 를 뜯으면 나온다.
///
/// 요청은 릴리스 조회와 APK 내려받기 둘뿐이다. 위치도 사용자 정보도
/// 나가지 않는다 (docs/09-RELEASE.md).
class GithubReleaseService implements AppUpdateService {
  GithubReleaseService({
    AppInstallerChannel installer = const AppInstallerChannel(),
    Future<String> Function()? currentVersionLoader,
  }) : _installer = installer,
       _currentVersionLoader =
           currentVersionLoader ?? AppInstallerChannel.readVersionName;

  final AppInstallerChannel _installer;
  final Future<String> Function() _currentVersionLoader;

  static final _latestEndpoint = Uri.parse(
    'https://api.github.com/repos/Cassiiopeia/EarLocAlert/releases/latest',
  );

  @override
  Future<UpdateCheck> check() async {
    final current = AppVersion.parse(await _currentVersionLoader());
    if (current == null) {
      // 자기 버전을 못 읽으면 비교 기준이 없다 — 아무것도 권하지 않는다
      return const UpdateCheckFailed('현재 버전을 읽지 못했습니다');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(_latestEndpoint);
      // GitHub API 는 User-Agent 없는 요청을 403 으로 막는다
      request.headers
        ..set(HttpHeaders.userAgentHeader, 'EarLocAlert')
        ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        // 403 은 대개 요청 한도다 — 잠시 뒤 다시 확인하면 된다
        return UpdateCheckFailed('HTTP ${response.statusCode}');
      }

      final release = parseRelease(body);
      if (release == null) {
        return const UpdateCheckFailed('릴리스 정보를 읽지 못했습니다');
      }
      if (!release.version.isNewerThan(current)) {
        return UpdateNotNeeded(current);
      }
      if (!release.hasApk) {
        // 버전은 올라갔는데 APK 가 안 붙은 릴리스다 — 받을 것이 없다
        return const UpdateCheckFailed('새 버전에 설치 파일이 없습니다');
      }
      return UpdateAvailable(current: current, release: release);
    } on Object catch (error) {
      return UpdateCheckFailed('$error');
    } finally {
      client.close(force: true);
    }
  }

  /// 릴리스 응답 파싱 — **순수 함수라 실기기 없이 테스트한다.**
  ///
  /// 버전을 못 읽으면 null 이다. 자산 중 `.apk` 로 끝나는 첫 항목을 쓴다 —
  /// 릴리스에 APK 는 하나만 붙는다.
  static AppRelease? parseRelease(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return null;

    final version = AppVersion.parse(decoded['tag_name'] as String?);
    if (version == null) return null;

    var apkUrl = '';
    final assets = decoded['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is! Map<String, dynamic>) continue;
        final name = asset['name'];
        final url = asset['browser_download_url'];
        if (name is String && url is String && name.endsWith('.apk')) {
          apkUrl = url;
          break;
        }
      }
    }

    return AppRelease(
      version: version,
      apkUrl: apkUrl,
      notes: (decoded['body'] as String?)?.trim() ?? '',
    );
  }

  @override
  Future<void> download(
    AppRelease release, {
    void Function(double progress)? onProgress,
  }) async {
    if (!release.hasApk) {
      throw const AppUpdateException('설치 파일이 없습니다');
    }

    Diagnostics.log('update', '업데이트 내려받기 시작 ${release.version}');

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse(release.apkUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'EarLocAlert');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        throw AppUpdateException('내려받기 실패 (HTTP ${response.statusCode})');
      }

      final total = response.contentLength;
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        // contentLength 가 -1 이면 길이를 모른다 — 진행률을 지어내지 않는다
        if (total > 0) onProgress?.call(bytes.length / total);
      }

      await _installer.install(
        bytes: bytes,
        fileName: 'EarLocAlert-${release.version}.apk',
      );
      Diagnostics.log('update', '설치 화면 요청 ${release.version}');
    } on AppUpdateException {
      rethrow;
    } on Object catch (error) {
      Diagnostics.log('update', '업데이트 실패 $error');
      throw AppUpdateException('$error');
    } finally {
      client.close(force: true);
    }
  }
}
