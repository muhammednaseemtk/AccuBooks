import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/database/database_helper.dart';
import 'package:accubooks/app/app.dart';

void main() {
  setUpAll(() {
    DatabaseHelper.initializeFfi();
  });

  testWidgets('AccuBooksApp renders successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AccuBooksApp());
    expect(find.text('AccuBooks'), findsOneWidget);
    expect(find.text('Professional Local-First Accounting'), findsOneWidget);

    // Let any pending splash timers resolve safely
    await tester.pump(const Duration(seconds: 1));
  });
}
