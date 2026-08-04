import 'package:flutter/services.dart';

/// 네이티브에 이미 박혀 있는 Google Maps API 키를 읽어온다.
///
/// 키의 단일 소스는 `.env` 하나이고, 빌드가 Android 매니페스트와
/// iOS Info.plist 에 주입한다 (docs/08-OPERATIONS.md). Dart 에서 키가
/// 필요한 곳(장소 검색 REST 호출)은 **그 주입된 값을 도로 읽는다** —
/// dart-define 같은 두 번째 주입 경로를 만들면 한쪽만 갱신되는 사고가 난다.
abstract final class MapsApiKeyChannel {
  static const _channel = MethodChannel(
    'kr.suhsaechan.ear_loc_alert/maps_api_key',
  );

  /// 키가 없거나(키 없이 빌드) 채널이 실패하면 null.
  /// 호출자는 null 이면 검색을 조용히 비활성화한다 — 앱은 계속 동작한다.
  static Future<String?> read() async {
    try {
      final key = await _channel.invokeMethod<String>('getMapsApiKey');
      if (key == null || key.isEmpty) return null;
      return key;
    } on Object {
      return null;
    }
  }
}
