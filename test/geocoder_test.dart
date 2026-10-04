import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:nearby_school_finder/geocoder.dart';

void main() {
  test('request authenticates and parses latitude/longitude', () async {
    final service = KakaoGeocoder(
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'KakaoAK test');
        expect(request.url.queryParameters['query'], '수원');
        return http.Response(
          '{"documents":[{"address_name":"수원","road_address":null,"x":"127.1","y":"37.2"}]}',
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    final result = await service.search('수원', 'test');
    expect(result.single.latitude, 37.2);
    expect(result.single.longitude, 127.1);
    service.dispose();
  });
  for (final status in [200, 401, 403, 429, 500]) {
    test('empty results or HTTP $status yields useful error', () async {
      final service = KakaoGeocoder(
        client: MockClient(
          (_) async => http.Response('{"documents":[]}', status),
        ),
      );
      await expectLater(
        service.search('unknown', 'key'),
        throwsA(isA<SearchFailure>()),
      );
      service.dispose();
    });
  }
  test('timeout yields useful error', () async {
    final service = KakaoGeocoder(
      client: MockClient((_) async => throw TimeoutException('timeout')),
    );
    await expectLater(
      service.search('address', 'key'),
      throwsA(isA<SearchFailure>()),
    );
    service.dispose();
  });
}
