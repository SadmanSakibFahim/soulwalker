import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulwalker/domain/term_key.dart';
import 'package:soulwalker/domain/terminology_resolver.dart';
import 'package:soulwalker/presentation/screens/v1_screens.dart';

void main() {
  testWidgets('checkpoint screen renders the resolved term, not a literal key',
      (WidgetTester tester) async {
    final TerminologyResolver terms = TerminologyResolver(const <String, String>{
      'CHECKPOINT_NAME': 'a Held Breath',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CheckpointScreen(terms: terms),
      ),
    );

    expect(find.text('a Held Breath'), findsOneWidget);
    expect(find.text(TermKey.checkpointName.storageKey), findsNothing);
    expect(find.text('Site of Grace'), findsNothing);
  });
}
