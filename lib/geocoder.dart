import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'school.dart';

class SearchFailure implements Exception {
  const SearchFailure(this.message);
  final String message;
}

class KakaoGeocoder {
  KakaoGeocoder({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  void dispose() => _client.close();
  Future<List<Place>> search(
    String query,
    String key, {
    bool keyword = false,
  }) async {
    if (key.trim().isEmpty) {
      throw const SearchFailure('설정에서 카카오 REST API 키를 입력해 주세요.');
    }
    try {
      final response = await _client
          .get(
            Uri.https(
              'dapi.kakao.com',
              keyword
                  ? '/v2/local/search/keyword.json'
                  : '/v2/local/search/address.json',
              {'query': query.trim(), 'size': '15'},
            ),
            headers: {'Authorization': 'KakaoAK ${key.trim()}'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const SearchFailure('API 키 또는 카카오맵 사용 권한을 확인해 주세요.');
      }
      if (response.statusCode == 429) {
        throw const SearchFailure('검색 한도를 초과했습니다. 잠시 후 다시 시도해 주세요.');
      }
      if (response.statusCode != 200) {
        throw const SearchFailure('주소 검색 서비스 오류입니다. 다시 시도해 주세요.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = (data['documents'] as List).map((item) {
        if (keyword) {
          final road = item['road_address_name'] as String?;
          return Place(
            road != null && road.isNotEmpty
                ? road
                : item['address_name'] as String,
            double.parse(item['y'] as String),
            double.parse(item['x'] as String),
            name: item['place_name'] as String,
          );
        }
        final road = item['road_address'] as Map<String, dynamic>?;
        return Place(
          road?['address_name'] as String? ?? item['address_name'] as String,
          double.parse(item['y'] as String),
          double.parse(item['x'] as String),
        );
      }).toList();
      if (places.isEmpty) {
        if (keyword) {
          throw const SearchFailure(
            '장소를 찾지 못했어요. 지역명이나 지점명을 함께 입력하거나 주소로 검색해 주세요.',
          );
        }
        throw const SearchFailure('주소를 다시 확인해 주세요. 도로명과 건물 번호를 입력해 주세요.');
      }
      return places;
    } on SearchFailure {
      rethrow;
    } on TimeoutException {
      throw const SearchFailure('검색 시간이 초과되었습니다. 다시 시도해 주세요.');
    } catch (_) {
      throw const SearchFailure('주소 검색에 실패했습니다. 인터넷 연결을 확인해 주세요.');
    }
  }
}
