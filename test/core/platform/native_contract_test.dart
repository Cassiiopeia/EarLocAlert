import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ear_loc_alert/app/background/alert_decision.dart';
import 'package:ear_loc_alert/core/domain/alert_direction.dart';
import 'package:ear_loc_alert/features/ads/data/google_native_strip_ad_loader.dart';
import 'package:ear_loc_alert/features/geofence/domain/watch_tier.dart';

String _read(String path) => File(path).readAsStringSync();

const _kotlinRoot = 'android/app/src/main/kotlin/kr/suhsaechan/ear_loc_alert';

/// Dart 값 <-> Kotlin·Swift 문자열 계약 (채널 이름 외)
/// 한쪽만 바꾸면 컴파일은 되고 동작만 조용히 사라진다
void main() {
  group('네이티브 광고 띠', () {
    final kotlin = _read('$_kotlinRoot/StripNativeAdFactory.kt');
    final swift = _read('ios/Runner/StripNativeAdFactory.swift');
    const optionKeys = [
      GoogleNativeStripAdLoader.backgroundColorKey,
      GoogleNativeStripAdLoader.headlineColorKey,
      GoogleNativeStripAdLoader.callToActionColorKey,
      GoogleNativeStripAdLoader.badgeBackgroundColorKey,
      GoogleNativeStripAdLoader.badgeTextColorKey,
      GoogleNativeStripAdLoader.badgeLabelKey,
    ];

    test('팩토리 ID 가 Kotlin·Swift 와 같다', () {
      const factoryId = '"${GoogleNativeStripAdLoader.factoryId}"';
      expect(kotlin, contains(factoryId));
      expect(swift, contains(factoryId));
    });

    test('customOptions 키가 Kotlin·Swift 에 모두 있다', () {
      for (final key in optionKeys) {
        expect(kotlin, contains('"$key"'), reason: '$key 가 Kotlin 에 없다');
        expect(swift, contains('"$key"'), reason: '$key 가 Swift 에 없다');
      }
    });
  });

  test('판정 결과 키가 Kotlin AlertDecision.fromMap 과 같다', () {
    final kotlin = _read('$_kotlinRoot/WatchEngine.kt');
    const decision = AlertDecision(
      shouldAlert: false,
      placeId: null,
      placeName: null,
      direction: null,
      soundEnabled: true,
      vibrationAmplitude: 0,
      vibrationPulseMs: 0,
    );
    for (final key in decision.toMap().keys) {
      expect(kotlin, contains('map["$key"]'), reason: '$key 를 Kotlin 이 읽지 않는다');
    }
  });

  test('출발 방향 이름이 Kotlin 알림 문구 분기와 같다', () {
    final kotlin = _read('$_kotlinRoot/AlertWatchService.kt');
    expect(kotlin, contains('direction == "${AlertDirection.exit.name}"'));
  });

  test('감시 단계 이름이 Swift 정확도 분기와 같다', () {
    final swift = _read('ios/Runner/AdaptiveLocationWatcher.swift');
    for (final tier in WatchTier.values) {
      expect(
        swift,
        // far·precise 는 switch 분기, mid 는 저장값 기본값
        anyOf(contains('case "${tier.name}"'), contains('?? "${tier.name}"')),
        reason: '${tier.name} 가 Swift 에 없다',
      );
    }
  });
}
