import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nearby_school_finder/geocoder.dart';

void main() {
  test(
    'unrestricted keyword search returns institution branches and addresses',
    () async {
      final service = KakaoGeocoder(
        client: MockClient((request) async {
          expect(request.url.path, '/v2/local/search/keyword.json');
          expect(request.url.queryParameters['query'], '디지털혁신교육센터');
          expect(
            request.url.queryParameters.containsKey('category_group_code'),
            isFalse,
          );
          expect(request.headers['Authorization'], 'KakaoAK test');
          return http.Response(
            jsonEncode({
              'documents': [
                {
                  'place_name': '디지털혁신교육센터 인천점',
                  'road_address_name': '인천 도로명 주소',
                  'address_name': '인천 지번 주소',
                  'x': '126.7',
                  'y': '37.5',
                },
                {
                  'place_name': '디지털혁신교육센터 경기점',
                  'road_address_name': '',
                  'address_name': '경기 지번 주소',
                  'x': '126.9',
                  'y': '37.4',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final result = await service.search(' 디지털혁신교육센터 ', 'test', keyword: true);
      expect(result.first.name, '디지털혁신교육센터 인천점');
      expect(result.first.address, '인천 도로명 주소');
      expect(result.last.name, '디지털혁신교육센터 경기점');
      expect(result.last.address, '경기 지번 주소');
      expect(result.last.latitude, 37.4);
      expect(result.last.longitude, 126.9);
      service.dispose();
    },
  );
  test('missing place suggests region or branch name', () async {
    final service = KakaoGeocoder(
      client: MockClient((_) async => http.Response('{"documents":[]}', 200)),
    );
    await expectLater(
      service.search('unknown', 'test', keyword: true),
      throwsA(
        isA<SearchFailure>().having(
          (e) => e.message,
          'message',
          contains('지역명'),
        ),
      ),
    );
    service.dispose();
  });
}
