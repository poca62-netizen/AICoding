import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_school_finder/school_map.dart';
import 'package:nearby_school_finder/school.dart';

void main() {
  testWidgets('map markers track coordinates, focus, deletion and reset', (
    tester,
  ) async {
    final key = GlobalKey<SchoolMapState>();
    const home = Place('home', 37.26, 127.02);
    final schools = [
      const School(1, '학교 A', Place('A', 37.27, 127.03)),
      const School(2, '학교 B', Place('B', 37.28, 127.04)),
    ];
    Future<void> render(Place? origin) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SchoolMap(
              key: key,
              home: origin,
              schools: schools,
              loadTiles: false,
            ),
          ),
        ),
      ),
    );
    await render(home);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      3,
    );
    final lines = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines;
    expect(lines.length, 2);
    expect(lines.last.points.last.latitude, 37.27);
    expect(lines.last.strokeWidth, greaterThan(lines.first.strokeWidth));
    expect(lines.last.color, const Color(0xFFE65100));
    expect(
      lines.every((line) => line.points.first.latitude == home.latitude),
      isTrue,
    );
    expect(tester.getSize(find.byType(FlutterMap)).height, greaterThan(340));
    key.currentState!.focusSchool(schools.last);
    await tester.pumpAndSettle();
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.mapController!.camera.center.latitude, closeTo(37.28, .00001));
    expect(map.mapController!.camera.center.longitude, closeTo(127.04, .00001));
    schools.removeAt(0);
    await render(home);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.length,
      2,
    );
    final remaining = tester
        .widget<PolylineLayer>(find.byType(PolylineLayer))
        .polylines;
    expect(remaining.single.points.last.latitude, 37.28);
    expect(remaining.single.color, const Color(0xFFE65100));
    await render(null);
    await tester.pumpAndSettle();
    expect(
      tester.widget<PolylineLayer>(find.byType(PolylineLayer)).polylines,
      isEmpty,
    );
    schools.clear();
    await render(null);
    await tester.pumpAndSettle();
    expect(
      tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });
}
