import 'package:flutter/foundation.dart';

import '../domain/activity_sync.dart';

class HealthController extends ChangeNotifier {
  HealthController({
    required this.health,
    required this.progressDate,
    required this.onDays,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final HealthSource health;
  final DateTime? Function() progressDate;
  final Future<void> Function(List<DayActivity> days) onDays;
  final DateTime Function() _clock;

  String note = '';
  bool syncing = false;
  Future<void> _tail = Future<void>.value();

  Future<void> sync() {
    final Future<void> run = _tail.then((_) => _syncBody());
    _tail = run.catchError((Object _) {});
    return run;
  }

  Future<void> _syncBody() async {
    syncing = true;
    notifyListeners();
    try {
      final bool ready = await health.available();
      if (!ready) {
        note =
            'Apple Health is not on this device. Sync steps from a physical iPhone. On the simulator, use +km.';
        return;
      }
      final bool opened = await health.requestAccess();
      if (!opened) {
        note =
            'Apple Health did not allow the read. Open the Health app, tap Sharing, then Apps, then Soulwalker, and turn on Steps and Walking + Running Distance.';
        return;
      }
      final List<DateTime> window = activityWindow(
        progressDate: progressDate(),
        today: _clock(),
      );
      final List<HealthDay> readings = await health.readDays(window);
      final List<DayActivity> days = daysForSync(window, readings);
      await onDays(days);
      note = _summary(window, readings);
    } on HealthException catch (error) {
      note = error.message;
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  String _summary(List<DateTime> window, List<HealthDay> readings) {
    final String todayKey = formatDay(window.last);
    HealthDay? today;
    for (final HealthDay day in readings) {
      if (formatDay(day.date) == todayKey) {
        today = day;
      }
    }
    final int steps = today?.stepCount ?? 0;
    final int meters = metersFromHealth(
      distanceMeters: today?.distanceMeters,
      stepCount: today?.stepCount,
    );
    final String km = (meters / 1000).toStringAsFixed(2);
    if (steps == 0 && meters == 0) {
      return 'Apple Health has no steps for today yet. If Fitness already shows a walk, open Health → Sharing → Apps → Soulwalker and allow Steps and Walking + Running Distance, then sync again.';
    }
    return 'Apple Health today: $steps steps, $km km. Open the app again later to bank the rest of the day.';
  }
}
