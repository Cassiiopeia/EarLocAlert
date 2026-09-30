import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/diagnostics/diagnostics.dart';

part 'app_version_provider.g.dart';

/// 설치된 앱 버전 — 설정 화면에 보여준다 (이슈 #179)
///
/// `1.20.3 (113)` 형식이다. 앞은 `version.yml` 의 version, 괄호 안은 version_code 라
/// 문의가 왔을 때 어느 빌드인지, 인앱 업데이트가 실제로 올라왔는지 여기서 확인한다.
///
/// **읽기에 실패해도 예외를 던지지 않는다.** 부가 정보 때문에 설정 화면이 막히면 안 된다.
@riverpod
Future<String> appVersion(Ref ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } on Object catch (error) {
    Diagnostics.log('app', 'version read failed $error');
    return '-';
  }
}
