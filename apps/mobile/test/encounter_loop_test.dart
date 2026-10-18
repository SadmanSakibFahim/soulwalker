import 'package:flutter_test/flutter_test.dart';
import 'package:soulwalker/domain/encounter_loop.dart';
import 'package:soulwalker/domain/progress.dart';

void main() {
  test('five kilometres unlocks both tiers and counts one day', () {
    final WalkProgress state = recordDistance(const WalkProgress(), 5000);
    expect(state.unlockedTiers, <int>[1, 2]);
    expect(state.streakDays, 1);
    expect(state.encountersCompleted, 0);
    expect(state.events, contains(EncounterEventKind.dayQualified));
  });

  test('one grant cannot finish the encounter', () {
    final WalkProgress state = recordDistance(const WalkProgress(), 25000);
    expect(state.streakDays, 1);
    expect(state.encountersCompleted, 0);
    expect(state.unlockedTiers, <int>[1, 2]);
  });

  test('five counted days finish the encounter', () {
    WalkProgress state = const WalkProgress();
    for (var day = 0; day < EncounterRules.encounterLengthDays; day++) {
      state = recordDistance(state, EncounterRules.dailyQualifyM);
      if (day < 4) {
        expect(state.streakDays, day + 1);
        state = closeProgressDay(state);
        expect(state.events, isNot(contains(EncounterEventKind.death)));
      }
    }
    expect(state.encountersCompleted, 1);
    expect(state.streakDays, 0);
    expect(state.events, contains(EncounterEventKind.encounterCompleted));
  });

  test('a missed day resets the attempt and keeps armaments', () {
    WalkProgress state = recordDistance(const WalkProgress(), 5000);
    state = closeProgressDay(state);
    expect(state.streakDays, 1);
    state = closeProgressDay(state);
    expect(state.events, contains(EncounterEventKind.death));
    expect(state.streakDays, 0);
    expect(state.attempt, 2);
    expect(state.totalDistanceM, 5000);
    expect(state.unlockedTiers, <int>[1, 2]);
    expect(state.encountersCompleted, 0);
  });

  test('three kilometres unlocks only the first tier', () {
    final WalkProgress state = recordDistance(const WalkProgress(), 3000);
    expect(state.unlockedTiers, <int>[1]);
    expect(state.streakDays, 0);
  });
}
