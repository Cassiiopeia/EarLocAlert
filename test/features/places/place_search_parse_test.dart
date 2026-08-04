import 'dart:convert';

import 'package:ear_loc_alert/features/places/data/google_place_search_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Places API (New) Text Search 응답 파싱 (issue #72)
///
/// 파싱은 순수 함수라 실기기·네트워크 없이 전부 검증한다.
void main() {
  group('검색 응답 파싱', () {
    test('정상 응답 → 이름·주소·좌표가 그대로 온다', () {
      final body = jsonEncode({
        'places': [
          {
            'displayName': {'text': '강남역', 'languageCode': 'ko'},
            'formattedAddress': '서울특별시 강남구 강남대로 지하396',
            'location': {'latitude': 37.4979, 'longitude': 127.0276},
          },
          {
            'displayName': {'text': '강남역 2호선', 'languageCode': 'ko'},
            'formattedAddress': '서울특별시 강남구',
            'location': {'latitude': 37.4981, 'longitude': 127.0278},
          },
        ],
      });

      final results = GooglePlaceSearchService.parseResponse(body);

      expect(results, hasLength(2));
      expect(results.first.name, '강남역');
      expect(results.first.address, '서울특별시 강남구 강남대로 지하396');
      expect(results.first.latitude, closeTo(37.4979, 1e-9));
      expect(results.first.longitude, closeTo(127.0276, 1e-9));
    });

    test('결과 없음 — places 필드 자체가 없다', () {
      // Places API 는 결과가 없으면 빈 객체를 준다
      expect(GooglePlaceSearchService.parseResponse('{}'), isEmpty);
    });

    test('좌표 없는 항목은 버리고 나머지는 살린다', () {
      final body = jsonEncode({
        'places': [
          {
            'displayName': {'text': '좌표 없는 곳'},
            'formattedAddress': '어딘가',
            // location 누락
          },
          {
            'displayName': {'text': '멀쩡한 곳'},
            'formattedAddress': '서울',
            'location': {'latitude': 37.5, 'longitude': 127.0},
          },
        ],
      });

      final results = GooglePlaceSearchService.parseResponse(body);

      expect(results, hasLength(1));
      expect(results.first.name, '멀쩡한 곳');
    });

    test('이름이 없으면 대체 문구, 주소가 없으면 빈 문자열', () {
      final body = jsonEncode({
        'places': [
          {
            'location': {'latitude': 37.5, 'longitude': 127.0},
          },
        ],
      });

      final results = GooglePlaceSearchService.parseResponse(body);

      expect(results, hasLength(1));
      expect(results.first.name, '이름 없는 장소');
      expect(results.first.address, '');
    });

    test('정수 좌표도 double 로 변환된다', () {
      final body = jsonEncode({
        'places': [
          {
            'displayName': {'text': '적도 어딘가'},
            'location': {'latitude': 0, 'longitude': 127},
          },
        ],
      });

      final results = GooglePlaceSearchService.parseResponse(body);

      expect(results.single.latitude, 0.0);
      expect(results.single.longitude, 127.0);
    });
  });
}
