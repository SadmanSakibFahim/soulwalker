import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/walk_credit.dart';

class WalkController extends ChangeNotifier {
  WalkController({
    required this.motion,
    required this.store,
    required this.onLocalDelta,
    required this.onServerDelta,
  });

  final MotionSource motion;
  final WalkStore store;
  final void Function(int meters) onLocalDelta;
  final Future<bool> Function(int meters) onServerDelta;

  bool walking = false;
  String note = '';
  Timer? _timer;
  bool _syncing = false;

  Future<void> restore() async {
    final WalkCheckpoint? saved = await store.load();
    if (saved == null) {
      return;
    }
    walking = true;
    _ensureTimer();
    await sync();
  }

  Future<void> start() async {
    final bool ready = await motion.available();
    if (!ready) {
      note = 'This phone cannot count a walk. Use a physical iPhone or Android phone.';
      notifyListeners();
      return;
    }
    await store.save(
      WalkCheckpoint(
        startedAt: DateTime.now(),
        appliedMeters: 0,
        serverAppliedMeters: 0,
      ),
    );
    walking = true;
    note =
        'Walking. Lock the phone and keep it in a pocket. Open Soulwalker again to bank the distance.';
    _ensureTimer();
    notifyListeners();
    await sync();
  }

  Future<void> sync() async {
    if (_syncing) {
      return;
    }
    _syncing = true;
    try {
      final WalkCheckpoint? saved = await store.load();
      if (saved == null) {
        walking = false;
        return;
      }
      walking = true;
      final MotionReading reading = await motion.read(start: saved.startedAt);
      final MeasuredWalk measured = measureWalk(
        reading: reading,
        appliedMeters: saved.appliedMeters,
        stepBaseline: saved.stepBaseline,
        stepOriginMeters: saved.stepOriginMeters,
      );
      final int delta = newlyWalkedMeters(measured.motionMeters, saved.appliedMeters);
      var applied = saved.appliedMeters;
      var serverApplied = saved.serverAppliedMeters;
      if (delta > 0) {
        onLocalDelta(delta);
        applied = measured.motionMeters;
      }
      final int unsent = applied - serverApplied;
      if (unsent > 0) {
        final bool accepted = await onServerDelta(unsent);
        if (accepted) {
          serverApplied = applied;
        }
      }
      await store.save(
        saved.copyWith(
          appliedMeters: applied,
          serverAppliedMeters: serverApplied,
          stepBaseline: measured.stepBaseline,
          stepOriginMeters: measured.stepOriginMeters,
        ),
      );
      final String km = (applied / 1000).toStringAsFixed(2);
      if (applied == 0) {
        note =
            'Walking. Lock the phone and keep it in a pocket. Open Soulwalker again to bank the distance.';
      } else if (serverApplied < applied) {
        note = 'This walk is $km km on the phone. Connect API to bank the rest.';
      } else {
        note = 'This walk is $km km.';
      }
    } on MotionException catch (error) {
      note = error.message;
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> end() async {
    await sync();
    _timer?.cancel();
    _timer = null;
    await store.clear();
    walking = false;
    note = 'Walk ended. Distance already banked stays.';
    notifyListeners();
  }

  Future<void> discard() async {
    _timer?.cancel();
    _timer = null;
    await store.clear();
    walking = false;
    note = '';
    notifyListeners();
  }

  void _ensureTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 20), (Timer timer) {
      unawaited(sync());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
