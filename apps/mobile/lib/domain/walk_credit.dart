// Pocket-walk measurement. iOS can report meters from the motion coprocessor.
// Android reports a step counter, converted at [kStepStrideCm].
// Apple Health distance is preferred when Sync Apple Health is used.

const int kStepStrideCm = 78;

class MotionReading {
  const MotionReading({this.distanceMeters, this.stepCount});

  final int? distanceMeters;
  final int? stepCount;
}

class MotionException implements Exception {
  const MotionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class MotionSource {
  Future<bool> available();

  Future<MotionReading> read({required DateTime start});
}

class WalkCheckpoint {
  const WalkCheckpoint({
    required this.startedAt,
    required this.appliedMeters,
    required this.serverAppliedMeters,
    this.stepBaseline,
    this.stepOriginMeters = 0,
  });

  final DateTime startedAt;
  final int appliedMeters;
  final int serverAppliedMeters;
  final int? stepBaseline;
  final int stepOriginMeters;

  WalkCheckpoint copyWith({
    int? appliedMeters,
    int? serverAppliedMeters,
    int? stepBaseline,
    int? stepOriginMeters,
  }) {
    return WalkCheckpoint(
      startedAt: startedAt,
      appliedMeters: appliedMeters ?? this.appliedMeters,
      serverAppliedMeters: serverAppliedMeters ?? this.serverAppliedMeters,
      stepBaseline: stepBaseline ?? this.stepBaseline,
      stepOriginMeters: stepOriginMeters ?? this.stepOriginMeters,
    );
  }
}

abstract class WalkStore {
  Future<WalkCheckpoint?> load();

  Future<void> save(WalkCheckpoint checkpoint);

  Future<void> clear();
}

class MeasuredWalk {
  const MeasuredWalk({
    required this.motionMeters,
    required this.stepBaseline,
    required this.stepOriginMeters,
  });

  final int motionMeters;
  final int? stepBaseline;
  final int stepOriginMeters;
}

MeasuredWalk measureWalk({
  required MotionReading reading,
  required int appliedMeters,
  required int? stepBaseline,
  required int stepOriginMeters,
}) {
  final int? distance = reading.distanceMeters;
  if (distance != null) {
    return MeasuredWalk(
      motionMeters: distance < 0 ? 0 : distance,
      stepBaseline: stepBaseline,
      stepOriginMeters: stepOriginMeters,
    );
  }

  int? baseline = stepBaseline ?? reading.stepCount;
  var origin = stepOriginMeters;
  final int? steps = reading.stepCount;
  if (steps != null && baseline != null && steps < baseline) {
    baseline = steps;
    origin = appliedMeters;
  }
  var meters = origin;
  if (steps != null && baseline != null && steps > baseline) {
    meters = origin + ((steps - baseline) * kStepStrideCm) ~/ 100;
  }
  return MeasuredWalk(
    motionMeters: meters,
    stepBaseline: baseline,
    stepOriginMeters: origin,
  );
}

int newlyWalkedMeters(int motionMeters, int appliedMeters) {
  if (motionMeters <= appliedMeters) {
    return 0;
  }
  return motionMeters - appliedMeters;
}
