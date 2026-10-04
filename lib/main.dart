import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import 'school.dart';
import 'geocoder.dart';
import 'school_map.dart';

const green = Color(0xFF26745F);
const ink = Color(0xFF173E36);
void main() => runApp(const NearbySchoolApp());

class NearbySchoolApp extends StatelessWidget {
  const NearbySchoolApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '가까운 장소 찾기',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: green),
      scaffoldBackgroundColor: const Color(0xFFF5F7F3),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF5F7F3),
        foregroundColor: ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF4F7F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    ),
    home: const FinderPage(),
  );
}

class FinderPage extends StatefulWidget {
  const FinderPage({super.key});
  @override
  State<FinderPage> createState() => _FinderPageState();
}

class _FinderPageState extends State<FinderPage> {
  final geocoder = KakaoGeocoder();
  final mapKey = GlobalKey<SchoolMapState>();
  final homeText = TextEditingController(),
      nameText = TextEditingController(),
      schoolText = TextEditingController();
  String apiKey = const String.fromEnvironment('KAKAO_REST_API_KEY');
  Place? home;
  final List<School> schools = [];
  bool demo = false, busy = false;
  int nextId = 1;
  @override
  void dispose() {
    geocoder.dispose();
    homeText.dispose();
    nameText.dispose();
    schoolText.dispose();
    super.dispose();
  }

  void message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> settings() async {
    final controller = TextEditingController(text: apiKey);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('카카오 주소 검색 설정'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '카카오디벨로퍼스에서 발급받은 REST API 키를 입력하세요. 현재 실행 중에만 사용하며 저장하지 않습니다.',
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'REST API 키'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('적용'),
          ),
        ],
      ),
    );
    if (value != null && mounted) {
      setState(() => apiKey = value);
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
  }

  Future<Place?> chooseAddress(String query, {bool keyword = false}) async {
    final options = await geocoder.search(query, apiKey, keyword: keyword);
    if (!mounted) return null;
    return showModalBottomSheet<Place>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                keyword ? '장소를 선택해 주세요' : '주소를 확인해 주세요',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                keyword
                    ? '검색 결과 최대 15곳입니다. 원하는 장소가 없으면 지역명도 함께 입력해 주세요.'
                    : '검색된 주소를 선택하면 위치가 확정됩니다.',
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .55,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, i) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on_outlined),
                    title: Text(options[i].name ?? options[i].address),
                    subtitle: options[i].name == null
                        ? null
                        : Text(options[i].address),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, options[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> search(bool forHome) async {
    if (busy) return;
    final name = nameText.text.trim();
    final byName = !forHome && schoolText.text.trim().isEmpty;
    final query = forHome
        ? homeText.text.trim()
        : (byName ? name : schoolText.text.trim());
    if (query.isEmpty || (!forHome && name.isEmpty)) {
      message(forHome ? '집 주소를 입력해 주세요.' : '장소 이름을 입력해 주세요. 주소는 비워 두어도 됩니다.');
      return;
    }
    if (apiKey.isEmpty) {
      await settings();
      if (!mounted || apiKey.isEmpty) return;
    }
    setState(() => busy = true);
    try {
      final place = await chooseAddress(query, keyword: byName);
      if (!mounted || place == null) return;
      final selectedName = place.name ?? name;
      if (!forHome &&
          schools.any(
            (s) => s.name == selectedName && s.place.address == place.address,
          )) {
        message('이미 추가한 장소입니다.');
        return;
      }
      setState(() {
        if (forHome) {
          home = place;
          homeText.text = place.address;
        } else {
          schools.add(School(nextId++, selectedName, place));
          nameText.clear();
          schoolText.clear();
        }
      });
    } on SearchFailure catch (e) {
      if (mounted) message(e.message);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void loadDemo() => setState(() {
    demo = true;
    home = const Place('예시 출발지 · 수원시청 부근', 37.2636, 127.0286);
    homeText.text = home!.address;
    schools.clear();
    schools.addAll([
      School(
        nextId++,
        '하늘학교',
        const Place('예시 위치 C · 수원 북쪽', 37.3076, 127.0170),
      ),
      School(
        nextId++,
        '초록학교',
        const Place('예시 위치 A · 수원 남쪽', 37.2520, 127.0300),
      ),
      School(
        nextId++,
        '나무학교',
        const Place('예시 위치 B · 수원 동쪽', 37.2740, 127.0500),
      ),
    ]);
  });
  void showSchool(School school) {
    final target = mapKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
      );
    }
    mapKey.currentState?.focusSchool(school);
  }

  void clearDemo() => setState(() {
    demo = false;
    home = null;
    homeText.clear();
    schools.clear();
  });
  Widget panel(
    String number,
    String title,
    String subtitle,
    List<Widget> children,
  ) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE2E9E2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: const Color(0xFFE6F1E9),
              child: Text(
                number,
                style: const TextStyle(
                  fontSize: 13,
                  color: green,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: const TextStyle(color: Color(0xFF68776D), height: 1.5),
        ),
        const SizedBox(height: 22),
        ...children,
      ],
    ),
  );
  @override
  Widget build(BuildContext context) {
    final homePanel = panel('01', '어디에서 출발하나요?', '도로명 또는 지번 주소로 출발지를 찾아주세요.', [
      TextField(
        controller: homeText,
        enabled: !busy && !demo,
        onChanged: (_) => setState(() => home = null),
        onSubmitted: (_) => search(true),
        decoration: const InputDecoration(
          labelText: '집(출발지) 주소',
          hintText: '예: 경기 수원시 팔달구 효원로 241',
          prefixIcon: Icon(Icons.home_outlined),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: busy || demo ? null : () => search(true),
          icon: const Icon(Icons.search),
          label: const Text('출발지 주소 검색'),
        ),
      ),
      if (home != null)
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Text(
            '✓  ${home!.address}',
            style: const TextStyle(color: green),
          ),
        ),
    ]);
    final schoolPanel = panel(
      '02',
      '어디로 가시나요?',
      '기관명·상호명·학교명으로 검색하고, 결과에서 원하는 장소를 선택하세요.',
      [
        TextField(
          controller: nameText,
          enabled: !busy && !demo,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => search(false),
          decoration: const InputDecoration(
            labelText: '장소 이름',
            hintText: '예: 디지털혁신교육센터, 수원시청, 카페',
            prefixIcon: Icon(Icons.school_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: schoolText,
          enabled: !busy && !demo,
          onSubmitted: (_) => search(false),
          decoration: const InputDecoration(
            labelText: '장소 주소 (선택)',
            hintText: '비워 두면 장소 이름으로 검색합니다',
            helperText: '주소를 입력하면 해당 주소로 검색합니다.',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy || demo ? null : () => search(false),
            icon: const Icon(Icons.add),
            label: const Text('장소 검색 후 추가'),
          ),
        ),
      ],
    );
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.school_rounded, color: green),
            SizedBox(width: 10),
            Text(
              '가까운 장소 찾기',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: busy ? null : settings,
            tooltip: 'API 설정',
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'NEARBY PLACE FINDER',
                  style: TextStyle(
                    color: green,
                    letterSpacing: 2,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '가까운 장소부터,\n하루를 가볍게.',
                  style: TextStyle(
                    fontSize: 36,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '출발지에서 목적지까지의 거리를 한 번에 비교하세요.',
                  style: TextStyle(fontSize: 16, color: Color(0xFF68776D)),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EFE4),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        demo
                            ? '예시 체험 중 · 가상 학교와 예시 좌표입니다.'
                            : '처음이신가요? 예시 학교 3곳으로 체험해 보세요.',
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : (demo
                                  ? clearDemo
                                  : (schools.isEmpty && home == null
                                        ? loadDemo
                                        : null)),
                        child: Text(demo ? '실제 주소 입력하기' : '예시 체험 →'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SchoolMap(
                  key: mapKey,
                  apiKey: apiKey,
                  home: home,
                  schools: schools,
                  demo: demo,
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, c) => c.maxWidth > 720
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: homePanel),
                            const SizedBox(width: 20),
                            Expanded(child: schoolPanel),
                          ],
                        )
                      : Column(
                          children: [
                            homePanel,
                            const SizedBox(height: 18),
                            schoolPanel,
                          ],
                        ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: LinearProgressIndicator(),
                  ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Text(
                      '비교할 장소',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${schools.length}곳',
                      style: const TextStyle(color: green),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (schools.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.add_location_alt_outlined,
                          color: green,
                          size: 32,
                        ),
                        SizedBox(height: 12),
                        Text('아직 추가한 장소가 없어요.'),
                        SizedBox(height: 5),
                        Text(
                          '장소를 추가하면 이곳에 모아 보여드려요.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ...schools.map(
                  (s) => Card(
                    elevation: 0,
                    color: Colors.white,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 6,
                      ),
                      leading: const Icon(Icons.school_outlined, color: green),
                      title: Text(s.name),
                      subtitle: Text(s.place.address),
                      onTap: () => showSchool(s),
                      trailing: IconButton(
                        tooltip: '${s.name} 삭제',
                        onPressed: busy
                            ? null
                            : () => setState(
                                () => schools.removeWhere(
                                  (item) => item.id == s.id,
                                ),
                              ),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: !busy && home != null && schools.isNotEmpty
                      ? () async {
                          final remaining = await Navigator.push<List<School>>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ResultsPage(
                                apiKey: apiKey,
                                home: home!,
                                schools: schools,
                                demo: demo,
                              ),
                            ),
                          );
                          if (remaining != null && mounted) {
                            setState(() {
                              schools.clear();
                              schools.addAll(remaining);
                            });
                          }
                        }
                      : null,
                  icon: const Icon(Icons.swap_vert),
                  label: Text(
                    '가까운 장소 찾기${schools.isEmpty ? '' : ' · ${schools.length}곳'}',
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '직선거리 기준 · 실제 이동거리와 소요시간은 다를 수 있어요.\n입력한 주소와 장소 목록은 앱을 종료하면 사라집니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF68776D),
                    height: 1.7,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResultsPage extends StatefulWidget {
  const ResultsPage({
    super.key,
    required this.home,
    required this.schools,
    required this.demo,
    this.apiKey = '',
  });
  final Place home;
  final List<School> schools;
  final bool demo;
  final String apiKey;
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  final mapKey = GlobalKey<SchoolMapState>();
  void showSchool(School school) {
    final target = mapKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
      );
    }
    mapKey.currentState?.focusSchool(school);
  }

  late final List<School> ranked = nearestSchools(widget.home, widget.schools);
  @override
  Widget build(BuildContext context) => PopScope<List<School>>(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) Navigator.pop(context, ranked);
    },
    child: Scaffold(
      appBar: AppBar(title: const Text('거리 비교 결과')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              scrollCacheExtent: const ScrollCacheExtent.pixels(100000),
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  '가까운 순서로\n정리했어요.',
                  style: TextStyle(
                    fontSize: 34,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '출발지  ·  ${widget.home.address}',
                  style: const TextStyle(color: green),
                ),
                const SizedBox(height: 8),
                Text('${widget.demo ? '예시 좌표로 계산한 체험 결과 · ' : ''}직선거리 기준 / km'),
                const SizedBox(height: 24),
                SchoolMap(
                  key: mapKey,
                  apiKey: widget.apiKey,
                  home: widget.home,
                  schools: ranked,
                  demo: widget.demo,
                ),
                const SizedBox(height: 20),
                const Text('장소 이름을 누르면 지도에서 위치를 확인할 수 있어요.'),
                const SizedBox(height: 12),
                if (ranked.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('모든 장소를 삭제했어요. 입력 화면에서 장소를 추가해 주세요.'),
                  ),
                ...ranked.asMap().entries.map((entry) {
                  final first = entry.key == 0, s = entry.value;
                  final km = distanceKm(widget.home, s.place);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: first ? ink : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${entry.key + 1}'.padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 23,
                            color: first ? const Color(0xFFB7D6A6) : green,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (first)
                                const Text(
                                  '가장 가까운 장소',
                                  style: TextStyle(
                                    color: Color(0xFFB7D6A6),
                                    fontSize: 11,
                                  ),
                                ),
                              InkWell(
                                key: ValueKey('school-result-${s.id}'),
                                onTap: () => showSchool(s),
                                child: Text(
                                  s.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: first ? Colors.white : ink,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                s.place.address,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: first
                                      ? Colors.white70
                                      : Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                '${km > 0 && km < .01 ? '< 0.01' : km.toStringAsFixed(2)} km',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: first ? Colors.white : ink,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '${s.name} 삭제',
                          onPressed: () => setState(
                            () => ranked.removeWhere((item) => item.id == s.id),
                          ),
                          icon: Icon(
                            Icons.close,
                            color: first ? Colors.white70 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 12),
                const Text(
                  '거리는 지구 곡률을 반영한 Haversine 공식으로 계산합니다. 도로 경로와 대중교통 소요시간은 포함하지 않습니다.',
                  style: TextStyle(color: Colors.black54, height: 1.6),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context, ranked),
                  child: const Text('입력 화면으로 돌아가기'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
