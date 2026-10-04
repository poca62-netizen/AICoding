import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_school_finder/school.dart';

void main() {
  const origin = Place('origin', 0, 0);
  test('identical, known, and antipodal distances', () {
    expect(distanceKm(origin, origin), 0);
    expect(
      distanceKm(origin, const Place('east', 0, 1)),
      closeTo(111.195, .001),
    );
    expect(
      distanceKm(origin, const Place('opposite', 0, 180)),
      closeTo(20015.114, .001),
    );
  });
  test('sort does not mutate input and breaks ties deterministically', () {
    final schools = [
      const School(2, 'far', Place('far', 0, 2)),
      const School(1, 'near', Place('near', 0, 1)),
      const School(3, 'tie', Place('tie', 0, 1)),
    ];
    expect(nearestSchools(origin, schools).map((s) => s.id), [1, 3, 2]);
    expect(schools.first.id, 2);
  });
}
