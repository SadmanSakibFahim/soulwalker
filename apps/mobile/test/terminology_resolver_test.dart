import 'package:flutter_test/flutter_test.dart';
import 'package:soulwalker/domain/term_key.dart';
import 'package:soulwalker/domain/terminology_resolver.dart';

void main() {
  const Map<String, String> table = <String, String>{
    'PLAYER_TITLE': 'the Half-Woken',
    'CHECKPOINT_NAME': 'a Held Breath',
    'DEATH_MARKER_NAME': 'a Failed Waking',
    'AFFLICTION_NAME': 'the Weight',
    'ARMAMENT_CATEGORY_WEAPON': 'Wakings',
    'ARMAMENT_CATEGORY_ARMOR': 'Linens',
    'BOSS_ENCOUNTER_LABEL': 'the Long Night',
    'SUMMONS_NAME': 'a Shared Vigil',
    'STANDINGS_NAME': 'the Quiet Census',
  };

  test('resolves keys and never requires hardcoded mythos in callers', () {
    final TerminologyResolver resolver = TerminologyResolver(table);
    expect(resolver.resolve(TermKey.checkpointName), 'a Held Breath');
    expect(resolver.resolve(TermKey.deathMarkerName), 'a Failed Waking');
  });

  test('missing key throws', () {
    final TerminologyResolver resolver = TerminologyResolver(<String, String>{});
    expect(
      () => resolver.resolve(TermKey.playerTitle),
      throwsA(isA<MissingTermException>()),
    );
  });
}
