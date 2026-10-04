import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:nearby_school_finder/driving_service.dart';
import 'package:nearby_school_finder/school.dart';
import 'package:nearby_school_finder/school_map.dart';

const home = Place('home', 37.2, 127.1);
const destination = Place('destination', 37.3, 127.2);

class PendingService extends DrivingService {
  final pending = Completer<DrivingRoute>();
  @override
  Future<DrivingRoute> fetch(Place origin, Place destination, String key) =>
      pending.future;
}

void main() {
  test(
    'directions request and response geometry use longitude first',
    () async {
      final service = DrivingService(
        client: MockClient((request) async {
          expect(request.url.host, 'apis-navi.kakaomobility.com');
          expect(request.url.queryParameters['origin'], '127.1,37.2');
          expect(request.url.queryParameters['destination'], '127.2,37.3');
          expect(request.url.queryParameters['summary'], 'false');
          expect(request.headers['Authorization'], 'KakaoAK test');
          return http.Response(
            jsonEncode({
              'routes': [
                {
                  'result_code': 0,
                  'summary': {'distance': 12500, 'duration': 601},
                  'sections': [
                    {
                      'roads': [
                        {
                          'vertexes': [127.1, 37.2, 127.15, 37.22, 127.2, 37.3],
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );
      final route = await service.fetch(home, destination, 'test');
      expect(route.points[1].latitude, 37.22);
      expect(route.points[1].longitude, 127.15);
      expect(route.meters, 12500);
      expect(route.description, '12.50 km · 약 11분');
      service.dispose();
    },
  );
  for (final status in [401, 403, 429, 500]) {
    test('HTTP $status gives a route error', () async {
      final service = DrivingService(
        client: MockClient((_) async => http.Response('{}', status)),
      );
      await expectLater(
        service.fetch(home, destination, 'test'),
        throwsA(isA<RouteFailure>()),
      );
      service.dispose();
    });
  }
  test('unsuccessful route cannot be displayed as a straight road', () async {
    final service = DrivingService(
      client: MockClient(
        (_) async => http.Response('{"routes":[{"result_code":104}]}', 200),
      ),
    );
    await expectLater(
      service.fetch(home, destination, 'test'),
      throwsA(isA<RouteFailure>()),
    );
    service.dispose();
  });
  testWidgets('road mode preserves straight mode and ignores stale results', (
    tester,
  ) async {
    final service = PendingService();
    final key = GlobalKey<SchoolMapState>();
    final schools = [const School(1, 'destination', destination)];
    Future<void> render(Place? origin) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SchoolMap(
              key: key,
              home: origin,
              schools: schools,
              loadTiles: false,
              apiKey: 'test',
              drivingService: service,
            ),
          ),
        ),
      ),
    );
    await render(home);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points
          .length,
      2,
    );
    await tester.tap(find.text('자동차 도로경로'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
      isEmpty,
    );
    final request = key.currentState!.loadRoutes();
    await tester.pump();
    await render(null);
    await tester.pump();
    service.pending.complete(
      const DrivingRoute(
        [LatLng(37.2, 127.1), LatLng(37.22, 127.15), LatLng(37.3, 127.2)],
        12500,
        601,
      ),
    );
    await request;
    await tester.pumpAndSettle();
    expect(key.currentState!.roadRoutes, isEmpty);
    await render(home);
    await tester.pumpAndSettle();
    await key.currentState!.loadRoutes();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points
          .length,
      3,
    );
    await tester.ensureVisible(find.text('직선거리'));
    await tester.tap(find.text('직선거리'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points
          .length,
      2,
    );
    expect(tester.takeException(), isNull);
    service.dispose();
  });
}
