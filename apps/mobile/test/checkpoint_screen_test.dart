import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulwalker/domain/progress.dart';
import 'package:soulwalker/domain/term_key.dart';
import 'package:soulwalker/domain/terminology_resolver.dart';
import 'package:soulwalker/presentation/screens/v1_screens.dart';

void main() {
  testWidgets('checkpoint screen renders the resolved term, not a literal key',
      (WidgetTester tester) async {
    final TerminologyResolver terms = TerminologyResolver(const <String, String>{
      'CHECKPOINT_NAME': 'a Held Breath',
      'BOSS_ENCOUNTER_LABEL': 'the Long Night',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CheckpointScreen(terms: terms),
      ),
    );

    expect(find.text('a Held Breath'), findsOneWidget);
    expect(find.text(TermKey.checkpointName.storageKey), findsNothing);
    expect(find.text('Site of Grace'), findsNothing);
    expect(find.textContaining('the Long Night · day 0 of 5'), findsOneWidget);
    expect(find.text('Start walk'), findsNothing);
  });

  testWidgets('checkpoint screen offers a pocket walk', (WidgetTester tester) async {
    final TerminologyResolver terms = TerminologyResolver(const <String, String>{
      'CHECKPOINT_NAME': 'a Held Breath',
      'BOSS_ENCOUNTER_LABEL': 'the Long Night',
    });
    var started = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CheckpointScreen(
          terms: terms,
          onStartWalk: () => started += 1,
        ),
      ),
    );

    await tester.tap(find.text('Start walk'));
    await tester.pump();
    expect(started, 1);
  });

  testWidgets('checkpoint screen syncs Apple Health', (WidgetTester tester) async {
    final TerminologyResolver terms = TerminologyResolver(const <String, String>{
      'CHECKPOINT_NAME': 'a Held Breath',
      'BOSS_ENCOUNTER_LABEL': 'the Long Night',
    });
    var synced = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: CheckpointScreen(
          terms: terms,
          onSyncHealth: () => synced += 1,
        ),
      ),
    );

    await tester.tap(find.text('Sync Apple Health'));
    await tester.pump();
    expect(synced, 1);
    expect(find.text('Start walk'), findsNothing);
  });

  testWidgets('death keeps the walked distance and shows owned armaments',
      (WidgetTester tester) async {
    final TerminologyResolver terms = TerminologyResolver(const <String, String>{
      'CHECKPOINT_NAME': 'a Held Breath',
      'BOSS_ENCOUNTER_LABEL': 'the Long Night',
      'ARMAMENT_CATEGORY_WEAPON': 'Wakings',
      'ARMAMENT_CATEGORY_ARMOR': 'Linens',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: CheckpointScreen(
          terms: terms,
          progress: const WalkProgress(
            totalDistanceM: 5000,
            attempt: 2,
            unlockedTiers: <int>[1, 2],
            events: <EncounterEventKind>[EncounterEventKind.death],
          ),
        ),
      ),
    );

    expect(find.text('Walked 5.0 km'), findsOneWidget);
    expect(find.text('Wakings'), findsOneWidget);
    expect(find.text('Linens'), findsOneWidget);
    expect(find.textContaining('attempt 2'), findsOneWidget);
    expect(
      find.textContaining('The attempt ended. You return here.'),
      findsOneWidget,
    );
  });
}
