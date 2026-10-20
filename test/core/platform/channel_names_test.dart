import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/core/platform/channel_names.dart';

/// 네이티브 소스 전체 (확장자 1개) > 한 문자열
String _readSources(String root, String extension) => Directory(root)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith(extension))
    .map((file) => file.readAsStringSync())
    .join('\n');

/// 채널 이름은 Kotlin·Swift 문자열과 글자 그대로 같아야 한다 (이슈 #173).
/// 어긋나면 호출이 조용히 실패한다 — 앱은 멀쩡히 돌아서 아무도 모른다.
void main() {
  final kotlin = _readSources('android/app/src/main/kotlin', '.kt');
  final swift = _readSources('ios/Runner', '.swift');

  test('모든 채널 이름이 Kotlin 소스에 그대로 있다', () {
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

  test('iOS 가 쓰는 채널 이름이 Swift 소스에 그대로 있다', () {
    const names = {
      'mapsApiKey': ChannelNames.mapsApiKey,
      'currentLocation': ChannelNames.currentLocation,
      'iosWatch': ChannelNames.iosWatch,
      'systemVibration': ChannelNames.systemVibration,
      'arrivalAlarm': ChannelNames.arrivalAlarm,
      'notificationSettings': ChannelNames.notificationSettings,
    };
    names.forEach((key, value) {
      expect(swift, contains('"$value"'), reason: '$key 채널이 Swift 에 없다');
    });
  });

  test('네이티브의 채널 이름 문자열은 전부 ChannelNames 에 있다', () {
    const known = {
      ChannelNames.appConfig,
      ChannelNames.alertWindow,
      ChannelNames.watchEngine,
      ChannelNames.systemVolume,
      ChannelNames.mapsApiKey,
      ChannelNames.currentLocation,
      ChannelNames.alertReliability,
      ChannelNames.iosWatch,
      ChannelNames.systemVibration,
      ChannelNames.arrivalAlarm,
      ChannelNames.notificationSettings,
    };
    // 채널 이름 형식: "kr.suhsaechan.ear_loc_alert/{이름}"
    final channelLiteral = RegExp(
      r'"(kr\.suhsaechan\.ear_loc_alert/[A-Za-z0-9_]+)"',
    );
    final nativeNames = channelLiteral
        .allMatches('$kotlin\n$swift')
        .map((match) => match.group(1)!)
        .toSet();
    expect(nativeNames.difference(known), isEmpty);
  });
}
