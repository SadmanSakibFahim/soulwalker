enum TermKey {
  playerTitle('PLAYER_TITLE'),
  checkpointName('CHECKPOINT_NAME'),
  deathMarkerName('DEATH_MARKER_NAME'),
  afflictionName('AFFLICTION_NAME'),
  armamentCategoryWeapon('ARMAMENT_CATEGORY_WEAPON'),
  armamentCategoryArmor('ARMAMENT_CATEGORY_ARMOR'),
  bossEncounterLabel('BOSS_ENCOUNTER_LABEL'),
  summonsName('SUMMONS_NAME'),
  standingsName('STANDINGS_NAME');

  const TermKey(this.storageKey);

  final String storageKey;
}

class MissingTermException implements Exception {
  MissingTermException(this.key);

  final TermKey key;

  @override
  String toString() => 'MissingTermException: ${key.storageKey}';
}
