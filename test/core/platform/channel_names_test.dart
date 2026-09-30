import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/core/platform/channel_names.dart';

/// 채널 이름은 Kotlin 문자열과 글자 그대로 같아야 한다 (이슈 #173).
/// 어긋나면 호출이 조용히 실패한다 — 앱은 멀쩡히 돌아서 아무도 모른다.
void main() {
  test('모든 채널 이름이 Kotlin 소스에 그대로 있다', () {
    final kotlin = Directory('android/app/src/main/kotlin')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.kt'))
        .map((file) => file.readAsStringSync())
        .join('\n');

    const names = {
      'appConfig': ChannelNames.appConfig,
      'alertWindow': ChannelNames.alertWindow,
      'watchEngine': ChannelNames.watchEngine,
      'systemVolume': ChannelNames.systemVolume,
      'mapsApiKey': ChannelNames.mapsApiKey,
      'currentLocation': ChannelNames.currentLocation,
      'alertReliability': ChannelNames.alertReliability,
    };
    names.forEach((key, value) {
      expect(kotlin, contains('"$value"'), reason: '$key 채널이 Kotlin 에 없다');
    });
  });
}
