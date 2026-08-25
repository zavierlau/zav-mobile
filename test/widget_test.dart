// Smoke test: app renders HomeShell with bottom nav. No network is hit
// because no API token is set (StocksScreen shows the login gate).
import 'package:flutter_test/flutter_test.dart';
import 'package:zav_mobile/main.dart';

void main() {
  testWidgets('ZavApp renders home shell', (WidgetTester tester) async {
    await tester.pumpWidget(const ZavApp());
    await tester.pump();
    expect(find.text('行情'), findsOneWidget);
    expect(find.text('資源'), findsOneWidget);
    expect(find.text('日誌'), findsOneWidget);
  });
}