import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'school.dart';

class SchoolMap extends StatefulWidget {
  const SchoolMap({
    super.key,
    required this.home,
    required this.schools,
    this.demo = false,
    this.loadTiles = true,
  });
  final Place? home;
  final List<School> schools;
  final bool demo;
  final bool loadTiles;
  @override
  State<SchoolMap> createState() => SchoolMapState();
}

class SchoolMapState extends State<SchoolMap> {
  final controller = MapController();
  bool ready = false, failed = false;
  int? selected;
  LatLng point(Place place) => LatLng(place.latitude, place.longitude);
  List<LatLng> get points => [
    if (widget.home != null) point(widget.home!),
    ...widget.schools.map((s) => point(s.place)),
  ];
  void fitAll() {
    if (!ready) return;
    if (points.length < 2 || points.every((p) => p == points.first)) {
      controller.move(
        points.isEmpty ? const LatLng(37.2636, 127.0286) : points.first,
        13,
      );
    } else {
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(60),
          maxZoom: 16,
        ),
      );
    }
  }

  void focusSchool(School school) {
    setState(() => selected = school.id);
    if (ready) controller.move(point(school.place), 15);
  }

  @override
  void didUpdateWidget(covariant SchoolMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Callers may mutate a list in place, so compare the currently drawn set.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) fitAll();
    });
    if (!widget.schools.any((s) => s.id == selected)) selected = null;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Marker marker(
    Place place,
    String label,
    Color color,
    VoidCallback onTap, {
    bool active = false,
  }) => Marker(
    point: point(place),
    width: 110,
    height: 66,
    alignment: Alignment.topCenter,
    child: Semantics(
      button: true,
      label: '$label 위치',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: active ? 3 : 1),
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            Icon(Icons.location_on, color: color, size: 34),
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) {
    final matches = widget.schools.where((s) => s.id == selected);
    final school = matches.isEmpty ? null : matches.first;
    final home = widget.home;
    final ranked = home == null
        ? <School>[]
        : nearestSchools(home, widget.schools);
    final shortest = ranked.isEmpty
        ? null
        : distanceKm(home!, ranked.first.place);
    bool isNearest(School s) =>
        shortest != null &&
        (distanceKm(home!, s.place) - shortest).abs() < 0.000001;
    const highlight = Color(0xFFE65100);
    final connections = home == null
        ? <Polyline>[]
        : [
            // Draw highlighted lines last so they stay visible where routes overlap.
            for (final nearest in [false, true])
              for (final s in widget.schools.where(
                (s) => isNearest(s) == nearest,
              ))
                Polyline(
                  points: [point(home), point(s.place)],
                  color: nearest ? highlight : const Color(0xFF607D8B),
                  strokeWidth: nearest ? 7 : 3,
                  borderColor: nearest ? const Color(0xFFFFE0B2) : Colors.white,
                  borderStrokeWidth: nearest ? 3 : 1,
                ),
          ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.map_outlined, color: Color(0xFF26745F)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '지도에서 보기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(onPressed: fitAll, child: const Text('전체 위치')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${widget.demo ? '예시 위치 · ' : ''}파랑: 출발지 / 초록: 목적지 / 주황: 최단 직선거리',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: (MediaQuery.sizeOf(context).height * .62).clamp(
              420.0,
              640.0,
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                    initialCenter: const LatLng(37.2636, 127.0286),
                    initialZoom: 12,
                    minZoom: 3,
                    maxZoom: 18,
                    onMapReady: () {
                      ready = true;
                      fitAll();
                    },
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    if (widget.loadTiles)
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.nearbyschool.nearby_school_finder',
                        maxNativeZoom: 19,
                        errorTileCallback: (tile, error, stack) {
                          if (!failed && mounted) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) setState(() => failed = true);
                            });
                          }
                        },
                      ),
                    PolylineLayer(polylines: connections),
                    MarkerLayer(
                      markers: [
                        if (widget.home != null)
                          marker(widget.home!, '출발지', Colors.blue.shade700, () {
                            setState(() => selected = null);
                            controller.move(point(widget.home!), 15);
                          }),
                        ...widget.schools.map(
                          (s) => marker(
                            s.place,
                            s.name,
                            isNearest(s)
                                ? highlight
                                : selected == s.id
                                ? Colors.purple
                                : const Color(0xFF26745F),
                            () => focusSchool(s),
                            active: selected == s.id,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: Card(
                    child: Column(
                      children: [
                        IconButton(
                          tooltip: '지도 확대',
                          onPressed: () => controller.move(
                            controller.camera.center,
                            (controller.camera.zoom + 1).clamp(3, 18),
                          ),
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: '지도 축소',
                          onPressed: () => controller.move(
                            controller.camera.center,
                            (controller.camera.zoom - 1).clamp(3, 18),
                          ),
                          icon: const Icon(Icons.remove),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: ColoredBox(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () => launchUrl(
                        Uri.parse('https://www.openstreetmap.org/copyright'),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ),
                  ),
                ),
                if (points.isEmpty)
                  const Positioned(
                    left: 12,
                    bottom: 36,
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(10),
                        child: Text('주소를 추가하면 지도에 표시됩니다.'),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (shortest != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.bolt, color: highlight, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '최단 직선거리 ${shortest.toStringAsFixed(2)} km · ${ranked.where(isNearest).map((s) => s.name).join(', ')}\n주황색 굵은 선: 최단 거리 / 회색 선: 다른 목적지\n연결선은 실제 도로 경로가 아닙니다.',
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          if (failed)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '지도 배경을 불러오지 못했어요. 인터넷 연결을 확인해 주세요.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => failed = false),
                    child: const Text('확인'),
                  ),
                ],
              ),
            ),
          if (school != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${school.name} · ${school.place.address}${widget.home == null ? '' : ' · 직선거리 ${distanceKm(widget.home!, school.place).toStringAsFixed(2)} km'}',
              ),
            ),
        ],
      ),
    );
  }
}
