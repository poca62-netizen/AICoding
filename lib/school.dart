import 'dart:math';

class Place {
  const Place(this.address, this.latitude, this.longitude, {this.name});
  final String? name;
  final String address;
  final double latitude;
  final double longitude;
}

class School {
  const School(this.id, this.name, this.place);
  final int id;
  final String name;
  final Place place;
}

double distanceKm(Place a, Place b) {
  double rad(double d) => d * pi / 180;
  final h =
      pow(sin(rad(b.latitude - a.latitude) / 2), 2) +
      cos(rad(a.latitude)) *
          cos(rad(b.latitude)) *
          pow(sin(rad(b.longitude - a.longitude) / 2), 2);
  return 6371.0088 * 2 * asin(sqrt(h.clamp(0, 1)));
}

List<School> nearestSchools(Place home, List<School> schools) =>
    [...schools]..sort((a, b) {
      final d = distanceKm(home, a.place).compareTo(distanceKm(home, b.place));
      return d == 0 ? a.id.compareTo(b.id) : d;
    });
