// Walk progress and anonymous death-marker views. Engine keys only — no mythos literals.

class WalkProgress {
  const WalkProgress({
    this.totalDistanceM = 0,
    this.streakDays = 0,
  });

  final int totalDistanceM;
  final int streakDays;

  double get totalKm => totalDistanceM / 1000.0;

  WalkProgress copyWith({int? totalDistanceM, int? streakDays}) {
    return WalkProgress(
      totalDistanceM: totalDistanceM ?? this.totalDistanceM,
      streakDays: streakDays ?? this.streakDays,
    );
  }
}

class DeathMarkerView {
  const DeathMarkerView({required this.attemptNumber});

  final int attemptNumber;
}
