import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nearby_school_finder/main.dart';

Future<void> reveal(WidgetTester tester, Finder finder) async {
  final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    scroll.position.jumpTo(
      (scroll.position.pixels + 250).clamp(0, scroll.position.maxScrollExtent),
    );
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('demo sorts schools and deletion persists on return', (
    tester,
  ) async {
    await tester.pumpWidget(const NearbySchoolApp());
    await tester.tap(find.text('예시 체험 →'));
    await tester.pumpAndSettle();
    final calculate = find.widgetWithText(FilledButton, '가까운 장소 찾기 · 3곳');
    await reveal(tester, calculate);
    await tester.tap(calculate);
    await tester.pumpAndSettle();
    final greenResult = find.byKey(const ValueKey('school-result-2'));
    final treeResult = find.byKey(const ValueKey('school-result-3'));
    await reveal(tester, treeResult);
    expect(
      tester.getTopLeft(greenResult).dy,
      lessThan(tester.getTopLeft(treeResult).dy),
    );
    await reveal(tester, find.byTooltip('초록학교 삭제'));
    await tester.tap(find.byTooltip('초록학교 삭제'));
    await tester.pumpAndSettle();
    final back = find.text('입력 화면으로 돌아가기');
    await reveal(tester, back);
    await tester.tap(back);
    await tester.pumpAndSettle();
    expect(find.text('초록학교'), findsNothing);
    await reveal(tester, find.text('2곳'));
    expect(find.text('2곳'), findsOneWidget);
  });
  testWidgets('mobile empty state and demo reset', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const NearbySchoolApp());
    await tester.tap(find.text('예시 체험 →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('실제 주소 입력하기'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('0곳'));
    expect(find.text('0곳'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
