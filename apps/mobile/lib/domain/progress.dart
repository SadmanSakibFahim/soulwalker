// Walk progress and anonymous death-marker views. Engine keys only — no mythos literals.

enum EncounterEventKind {
  distanceRecorded('distance_recorded'),
  armamentUnlocked('armament_unlocked'),
  dayQualified('day_qualified'),
  encounterCompleted('encounter_completed'),
  death('death'),
  dayClosed('day_closed');

  const EncounterEventKind(this.wire);

  final String wire;

  static EncounterEventKind? parse(String wire) {
    for (final EncounterEventKind kind in EncounterEventKind.values) {
      if (kind.wire == wire) {
        return kind;
      }
    }
    return null;
  }
}

class WalkProgress {
  const WalkProgress({
    this.totalDistanceM = 0,
    this.todayDistanceM = 0,
    this.progressDate,
    this.streakDays = 0,
    this.attempt = 1,
    this.encountersCompleted = 0,
    this.unlockedTiers = const <int>[],
    this.events = const <EncounterEventKind>[],
  });

  final int totalDistanceM;
  final int todayDistanceM;
  final DateTime? progressDate;
  final int streakDays;
  final int attempt;
  final int encountersCompleted;
  final List<int> unlockedTiers;
  final List<EncounterEventKind> events;

  double get totalKm => totalDistanceM / 1000.0;

  double get todayKm => todayDistanceM / 1000.0;

  WalkProgress copyWith({
    int? totalDistanceM,
    int? todayDistanceM,
    DateTime? progressDate,
    int? streakDays,
    int? attempt,
    int? encountersCompleted,
    List<int>? unlockedTiers,
    List<EncounterEventKind>? events,
  }) {
    return WalkProgress(
      totalDistanceM: totalDistanceM ?? this.totalDistanceM,
      todayDistanceM: todayDistanceM ?? this.todayDistanceM,
      progressDate: progressDate ?? this.progressDate,
      streakDays: streakDays ?? this.streakDays,
      attempt: attempt ?? this.attempt,
      encountersCompleted: encountersCompleted ?? this.encountersCompleted,
      unlockedTiers: unlockedTiers ?? this.unlockedTiers,
      events: events ?? this.events,
    );
  }
}

class DeathMarkerView {
  const DeathMarkerView({required this.attemptNumber});

  final int attemptNumber;
}
