import 'progress.dart';

/// Mirrors `domain/encounter.py`. A day counts at 5 km. Five counted days
/// finish the encounter. A missed day resets that attempt only.
abstract final class EncounterRules {
  static const int dailyQualifyM = 5000;
  static const int encounterLengthDays = 5;
  static const List<int> armamentUnlocksM = <int>[3000, 5000];
}

WalkProgress recordDistance(WalkProgress state, int meters) {
  if (meters <= 0) {
    throw ArgumentError('meters must be positive');
  }
  final int total = state.totalDistanceM + meters;
  final int today = state.todayDistanceM + meters;
  final List<EncounterEventKind> events = <EncounterEventKind>[
    EncounterEventKind.distanceRecorded,
  ];
  var streak = state.streakDays;
  var completed = state.encountersCompleted;
  final bool alreadyQualified = state.todayDistanceM >= EncounterRules.dailyQualifyM;
  if (!alreadyQualified && today >= EncounterRules.dailyQualifyM) {
    streak += 1;
    events.add(EncounterEventKind.dayQualified);
    if (streak >= EncounterRules.encounterLengthDays) {
      completed += 1;
      streak = 0;
      events.add(EncounterEventKind.encounterCompleted);
    }
  }
  final List<int> tiers = List<int>.from(state.unlockedTiers);
  for (var index = 0; index < EncounterRules.armamentUnlocksM.length; index++) {
    final int tier = index + 1;
    final int threshold = EncounterRules.armamentUnlocksM[index];
    if (total >= threshold && !tiers.contains(tier)) {
      tiers.add(tier);
      events.add(EncounterEventKind.armamentUnlocked);
    }
  }
  return WalkProgress(
    totalDistanceM: total,
    todayDistanceM: today,
    progressDate: state.progressDate,
    streakDays: streak,
    attempt: state.attempt,
    encountersCompleted: completed,
    unlockedTiers: tiers,
    events: events,
  );
}

DateTime? _nextDate(DateTime? day) {
  if (day == null) {
    return null;
  }
  return DateTime(day.year, day.month, day.day + 1);
}

WalkProgress closeProgressDay(WalkProgress state) {
  final bool qualified = state.todayDistanceM >= EncounterRules.dailyQualifyM;
  var streak = state.streakDays;
  var attempt = state.attempt;
  final List<EncounterEventKind> events = <EncounterEventKind>[];
  if (!qualified && streak > 0) {
    streak = 0;
    attempt += 1;
    events.add(EncounterEventKind.death);
  }
  events.add(EncounterEventKind.dayClosed);
  return state.copyWith(
    todayDistanceM: 0,
    progressDate: _nextDate(state.progressDate),
    streakDays: streak,
    attempt: attempt,
    events: events,
  );
}
