import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:accubooks/core/widgets/app_table.dart';
import 'package:accubooks/core/widgets/app_card.dart';

void main() {
  testWidgets('AppTable renders inside AppCard on desktop without errors',
      (WidgetTester tester) async {
    final columns = [
      const AppTableColumn(title: 'Code', width: 90),
      const AppTableColumn(title: 'Account Name'),
      const AppTableColumn(title: 'Type', width: 120),
      const AppTableColumn(title: 'Balance', width: 150),
    ];

    final rows = [
      [
        const Text('1000'),
        const Text('Cash in Hand'),
        const Text('Asset'),
        const Text('₹50,000.00'),
      ],
      [
        const Text('1010'),
        const Text('HDFC Bank A/c'),
        const Text('Asset'),
        const Text('₹1,50,000.00'),
      ],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1024,
            height: 768,
            child: Column(
              children: [
                Expanded(
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      child: AppTable(
                        columns: columns,
                        rows: rows,
                        minWidth: 780,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('CODE'), findsOneWidget);
    expect(find.text('ACCOUNT NAME'), findsOneWidget);
    expect(find.text('Cash in Hand'), findsOneWidget);
  });

  testWidgets('AppTable renders inside AppCard on mobile screen without errors and allows scroll',
      (WidgetTester tester) async {
    final columns = [
      const AppTableColumn(title: 'Code', width: 90),
      const AppTableColumn(title: 'Account Name'),
      const AppTableColumn(title: 'Type', width: 120),
      const AppTableColumn(title: 'Balance', width: 150),
    ];

    final rows = [
      [
        const Text('1000'),
        const Text('Cash in Hand'),
        const Text('Asset'),
        const Text('₹50,000.00'),
      ],
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 640,
            child: Column(
              children: [
                Expanded(
                  child: AppCard(
                    padding: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      child: AppTable(
                        columns: columns,
                        rows: rows,
                        minWidth: 780,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('CODE'), findsOneWidget);
    expect(find.text('Cash in Hand'), findsOneWidget);
  });
}
