import 'package:flutter_test/flutter_test.dart';
import 'package:soulwalker/data/walk_store.dart';
import 'package:soulwalker/domain/walk_credit.dart';
import 'package:soulwalker/presentation/walk_controller.dart';

void main() {
  test('distance from the phone is used as meters', () {
    final MeasuredWalk measured = measureWalk(
      reading: const MotionReading(distanceMeters: 1500, stepCount: 4000),
      appliedMeters: 0,
      stepBaseline: null,
      stepOriginMeters: 0,
    );
    expect(measured.motionMeters, 1500);
  });

  test('steps become meters, and a counter reset keeps what was already walked', () {
    final MeasuredWalk reset = measureWalk(
      reading: const MotionReading(stepCount: 10),
      appliedMeters: 500,
      stepBaseline: 1000,
      stepOriginMeters: 0,
    );
    expect(reset.motionMeters, 500);
    expect(reset.stepBaseline, 10);
    expect(reset.stepOriginMeters, 500);

    final MeasuredWalk later = measureWalk(
      reading: const MotionReading(stepCount: 110),
      appliedMeters: 500,
      stepBaseline: reset.stepBaseline,
      stepOriginMeters: reset.stepOriginMeters,
    );
    expect(later.motionMeters, 500 + (100 * kStepStrideCm) ~/ 100);
  });

  test('a walk banks only new meters and retries what the server refused', () async {
    final FakeMotion motion = FakeMotion();
    final MemoryWalkStore store = MemoryWalkStore();
    var local = 0;
    var server = 0;
    var accept = false;
    final WalkController walk = WalkController(
      motion: motion,
      store: store,
      onLocalDelta: (int meters) {
        local += meters;
      },
      onServerDelta: (int meters) async {
        if (!accept) {
          return false;
        }
        server += meters;
        return true;
      },
    );
    addTearDown(walk.dispose);

    await walk.start();
    motion.meters = 120;
    await walk.sync();
    expect(local, 120);
    expect(server, 0);
    expect(store.checkpoint?.serverAppliedMeters, 0);

    motion.meters = 200;
    accept = true;
    await walk.sync();
    expect(local, 200);
    expect(server, 200);
    expect(store.checkpoint?.appliedMeters, 200);
    expect(store.checkpoint?.serverAppliedMeters, 200);
    expect(walk.note, 'This walk is 0.20 km.');
  });
}

class FakeMotion implements MotionSource {
  int meters = 0;

  @override
  Future<bool> available() async => true;

  @override
  Future<MotionReading> read({required DateTime start}) async {
    return MotionReading(distanceMeters: meters);
  }
}
