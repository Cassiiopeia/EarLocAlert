// Ref 는 riverpod_annotation 이 아니라 flutter_riverpod 이 제공한다
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/app_installer_channel.dart';
import '../data/github_release_service.dart';
import '../domain/app_update.dart';

part 'update_provider.g.dart';

/// 앱 업데이트 서비스 (이슈 #104)
@Riverpod(keepAlive: true)
AppUpdateService appUpdateService(Ref ref) => GithubReleaseService();

/// 현재 설치된 버전 문자열.
///
/// **네트워크를 타지 않는다** — 설정 화면을 열 때마다 릴리스를 조회하면
/// 요청 한도만 소모하고, 사용자는 확인을 누른 적이 없다. 확인은 사용자가
/// 직접 누를 때만 나간다.
@riverpod
Future<String> installedVersion(Ref ref) {
  return AppInstallerChannel.readVersionName();
}
