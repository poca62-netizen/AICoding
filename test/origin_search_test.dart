import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nearby_school_finder/geocoder.dart';

void main() {
  test('origin name falls back to unrestricted keyword search', () async {
    final paths = <String>[];
    final service = KakaoGeocoder(
      client: MockClient((request) async {
        paths.add(request.url.path);
        expect(request.url.queryParameters['query'], '수원시청');
        expect(
          request.url.queryParameters.containsKey('category_group_code'),
          false,
        );
        return http.Response(
          jsonEncode({
            'documents': request.url.path.endsWith('address.json')
                ? []
                : [
                    {
                      'place_name': '수원시청',
                      'road_address_name': '경기 수원시 팔달구 효원로 241',
                      'address_name': '지번 주소',
                      'x': '127.0286',
                      'y': '37.2636',
                    },
                  ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final places = await service.searchOrigin('수원시청', 'test');
    expect(paths, [
      '/v2/local/search/address.json',
      '/v2/local/search/keyword.json',
    ]);
    expect(places.single.name, '수원시청');
    expect(places.single.latitude, 37.2636);
    service.dispose();
  });
  test('valid origin address avoids a second request', () async {
    var calls = 0;
    final service = KakaoGeocoder(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          '{"documents":[{"address_name":"address","road_address":null,"x":"127.1","y":"37.2"}]}',
          200,
        );
      }),
    );
    expect(
      (await service.searchOrigin('address', 'test')).single.address,
      'address',
    );
    expect(calls, 1);
    service.dispose();
  });
  test('authentication failure does not trigger keyword fallback', () async {
    var calls = 0;
    final service = KakaoGeocoder(
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 401);
      }),
    );
    await expectLater(
      service.searchOrigin('name', 'test'),
      throwsA(isA<SearchFailure>()),
    );
    expect(calls, 1);
    service.dispose();
  });
}
