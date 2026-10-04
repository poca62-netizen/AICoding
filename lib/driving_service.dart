import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'school.dart';

class DrivingRoute {
  const DrivingRoute(this.points, this.meters, this.seconds);
  final List<LatLng> points;
  final double meters;
  final double seconds;
  String get description =>
      '${(meters / 1000).toStringAsFixed(2)} km · 약 ${(seconds / 60).ceil()}분';
}

class RouteFailure implements Exception {
  const RouteFailure(this.message);
  final String message;
}

class DrivingService {
  DrivingService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  void dispose() => _client.close();
  Future<DrivingRoute> fetch(
    Place origin,
    Place destination,
    String key,
  ) async {
    if (key.trim().isEmpty) {
      throw const RouteFailure('API 설정에 REST API 키를 입력해 주세요.');
    }
    try {
      final response = await _client
          .get(
            Uri.https('apis-navi.kakaomobility.com', '/v1/directions', {
              'origin': '${origin.longitude},${origin.latitude}',
              'destination': '${destination.longitude},${destination.latitude}',
              'priority': 'RECOMMEND',
              'summary': 'false',
              'alternatives': 'false',
            }),
            headers: {'Authorization': 'KakaoAK ${key.trim()}'},
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const RouteFailure('REST API 키와 카카오모빌리티 자동차 길찾기 사용 권한을 확인해 주세요.');
      }
      if (response.statusCode == 429) {
        throw const RouteFailure('길찾기 요청 한도를 초과했어요. 잠시 후 다시 시도해 주세요.');
      }
      if (response.statusCode != 200) {
        throw const RouteFailure('도로경로 서비스 오류입니다. 잠시 후 다시 시도해 주세요.');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List;
      if (routes.isEmpty || routes.first['result_code'] != 0) {
        throw const RouteFailure('이 위치 사이의 자동차 경로를 찾지 못했어요. 출입구 주소를 확인해 주세요.');
      }
      final route = routes.first;
      final summary = route['summary'];
      final points = <LatLng>[];
      for (final section in route['sections'] as List) {
        for (final road in section['roads'] as List) {
          final vertices = road['vertexes'] as List;
          if (vertices.length.isOdd) {
            throw const FormatException('Invalid route coordinates');
          }
          for (var i = 0; i < vertices.length; i += 2) {
            points.add(
              LatLng(
                (vertices[i + 1] as num).toDouble(),
                (vertices[i] as num).toDouble(),
              ),
            );
          }
        }
      }
      final meters = (summary['distance'] as num).toDouble();
      final seconds = (summary['duration'] as num).toDouble();
      if (points.length < 2 ||
          !meters.isFinite ||
          !seconds.isFinite ||
          meters < 0 ||
          seconds < 0) {
        throw const FormatException('Invalid route');
      }
      return DrivingRoute(points, meters, seconds);
    } on RouteFailure {
      rethrow;
    } on TimeoutException {
      throw const RouteFailure('도로경로 검색 시간이 초과됐어요. 다시 시도해 주세요.');
    } catch (_) {
      throw const RouteFailure('도로경로를 불러오지 못했어요. 인터넷 연결과 API 설정을 확인해 주세요.');
    }
  }
}
