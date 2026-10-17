import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soulwalker/dev/dev_host.dart';
import 'package:soulwalker/domain/progress.dart';
import 'package:soulwalker/domain/terminology_resolver.dart';
import 'package:soulwalker/presentation/screens/v1_screens.dart';

TerminologyResolver _terms() {
  return TerminologyResolver(const <String, String>{
    'PLAYER_TITLE': 'the Half-Woken',
    'CHECKPOINT_NAME': 'a Held Breath',
    'DEATH_MARKER_NAME': 'a Failed Waking',
    'AFFLICTION_NAME': 'the Weight',
    'ARMAMENT_CATEGORY_WEAPON': 'Wakings',
    'ARMAMENT_CATEGORY_ARMOR': 'Linens',
    'BOSS_ENCOUNTER_LABEL': 'the Long Night',
    'SUMMONS_NAME': 'a Shared Vigil',
    'STANDINGS_NAME': 'the Quiet Census',
  });
}

void main() {
  testWidgets('dev panel adds kilometres onto the checkpoint copy', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(home: DevHost(terms: _terms())));
    await tester.tap(find.text('+1 km'));
    await tester.pump();
    expect(find.textContaining('Walked 1.0 km'), findsWidgets);
  });

  testWidgets('death marker screen lists fixed-type attempts', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DeathMarkerScreen(
          terms: _terms(),
          markers: const <DeathMarkerView>[DeathMarkerView(attemptNumber: 3)],
        ),
      ),
    );
    expect(find.text('a Failed Waking'), findsOneWidget);
    expect(find.text('Died here, attempt #3'), findsOneWidget);
  });
}
