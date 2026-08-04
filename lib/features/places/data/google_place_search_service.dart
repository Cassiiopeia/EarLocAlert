import 'dart:convert';
import 'dart:io';

import '../domain/place_search.dart';
import 'maps_api_key_channel.dart';

/// Google Places API (New) Text Search 구현 (issue #72)
///
/// SDK 대신 REST 를 직접 부른다 — 검색 하나에 플러그인을 더 들이는 것보다
/// 요청 한 개를 만드는 쪽이 작고, 응답 파싱을 순수 함수로 분리해
/// 실기기 없이 테스트할 수 있다.
///
/// 키는 네이티브에 주입된 값을 채널로 읽는다. 키가 없으면
/// [PlaceSearchUnavailable] — 검색만 죽고 앱은 계속 동작해야 한다.
class GooglePlaceSearchService implements PlaceSearchService {
  GooglePlaceSearchService({Future<String?> Function()? apiKeyLoader})
    : _apiKeyLoader = apiKeyLoader ?? MapsApiKeyChannel.read;

  final Future<String?> Function() _apiKeyLoader;

  static final _endpoint = Uri.parse(
    'https://places.googleapis.com/v1/places:searchText',
  );

  /// null 은 "아직 안 읽음"과 구분되지 않으므로 키 없음은 '' 로 캐시한다
  String? _cachedKey;

  @override
  Future<List<PlaceSearchResult>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final key = _cachedKey ??= (await _apiKeyLoader()) ?? '';
    if (key.isEmpty) {
      throw const PlaceSearchUnavailable('Maps API 키가 없다');
    }

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.postUrl(_endpoint);
      request.headers
        ..contentType = ContentType.json
        ..set('X-Goog-Api-Key', key)
        // 필요한 필드만 청구된다 — 마스크를 넓히면 과금 SKU 가 올라간다
        ..set(
          'X-Goog-FieldMask',
          'places.displayName,places.formattedAddress,places.location',
        );
      request.write(
        jsonEncode({'textQuery': trimmed, 'languageCode': 'ko', 'pageSize': 8}),
      );

      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != HttpStatus.ok) {
        // 403 = 키 제한에 Places API 가 빠져 있다 (docs/08-OPERATIONS.md)
        throw PlaceSearchUnavailable('HTTP ${response.statusCode}');
      }
      return parseResponse(body);
    } on PlaceSearchUnavailable {
      rethrow;
    } on Object catch (error) {
      // 네트워크 단절·타임아웃 — 검색 불가로 통일한다
      throw PlaceSearchUnavailable('$error');
    } finally {
      client.close(force: true);
    }
  }

  /// 응답 파싱 — 순수 함수라 실기기 없이 테스트한다.
  ///
  /// 필드가 빠진 항목은 조용히 버린다. 좌표 없는 검색 결과는
  /// 이 앱에서 쓸모가 없고, 하나가 이상하다고 전체를 실패시키면
  /// 멀쩡한 결과까지 못 보여준다.
  static List<PlaceSearchResult> parseResponse(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];

    final places = decoded['places'];
    if (places is! List) return const [];

    final results = <PlaceSearchResult>[];
    for (final place in places) {
      if (place is! Map<String, dynamic>) continue;

      final location = place['location'];
      if (location is! Map<String, dynamic>) continue;
      final latitude = location['latitude'];
      final longitude = location['longitude'];
      if (latitude is! num || longitude is! num) continue;

      final displayName = place['displayName'];
      final name = displayName is Map<String, dynamic>
          ? displayName['text']
          : null;

      results.add(
        PlaceSearchResult(
          name: name is String && name.isNotEmpty ? name : '이름 없는 장소',
          address: place['formattedAddress'] is String
              ? place['formattedAddress'] as String
              : '',
          latitude: latitude.toDouble(),
          longitude: longitude.toDouble(),
        ),
      );
    }
    return results;
  }
}
