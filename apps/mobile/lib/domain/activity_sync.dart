import 'encounter_loop.dart';
import 'progress.dart';
import 'walk_credit.dart';

/// One local calendar day of cumulative distance, as Apple Health reports it.
class DayActivity {
  const DayActivity({required this.date, required this.distanceMeters});

  final DateTime date;
  final int distanceMeters;
}

class HealthDay {
  const HealthDay({required this.date, this.distanceMeters, this.stepCount});

  final DateTime date;
  final int? distanceMeters;
  final int? stepCount;
}

class HealthException implements Exception {
  const HealthException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class HealthSource {
  Future<bool> available();

  Future<bool> requestAccess();

  Future<List<HealthDay>> readDays(List<DateTime> dates);
}

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

String formatDay(DateTime value) {
  final DateTime day = dateOnly(value);
  final String month = day.month.toString().padLeft(2, '0');
  final String date = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$date';
}

DateTime? parseDay(Object? raw) {
  if (raw is! String || raw.length < 10) {
    return null;
  }
  final int? year = int.tryParse(raw.substring(0, 4));
  final int? month = int.tryParse(raw.substring(5, 7));
  final int? day = int.tryParse(raw.substring(8, 10));
  if (year == null || month == null || day == null) {
    return null;
  }
  return DateTime(year, month, day);
}

/// Walking distance when Health has it, otherwise the shared step stride.
int metersFromHealth({int? distanceMeters, int? stepCount}) {
  if (distanceMeters != null && distanceMeters > 0) {
    return distanceMeters;
  }
  if (stepCount != null && stepCount > 0) {
    return (stepCount * kStepStrideCm) ~/ 100;
  }
  return 0;
}

/// Dates to ask Health for. The first sync is today only. Later syncs cover
/// the open day through today, capped so a long gap stays a bounded query.
List<DateTime> activityWindow({
  required DateTime? progressDate,
  required DateTime today,
  int maxDays = 31,
}) {
  final DateTime end = dateOnly(today);
  if (progressDate == null) {
    return <DateTime>[end];
  }
  DateTime cursor = dateOnly(progressDate);
  if (cursor.isAfter(end)) {
    return <DateTime>[end];
  }
  final DateTime earliest = DateTime(end.year, end.month, end.day - (maxDays - 1));
  if (cursor.isBefore(earliest)) {
    cursor = earliest;
  }
  final List<DateTime> days = <DateTime>[];
  while (!cursor.isAfter(end)) {
    days.add(cursor);
    cursor = DateTime(cursor.year, cursor.month, cursor.day + 1);
  }
  return days;
}

List<DayActivity> daysForSync(List<DateTime> window, List<HealthDay> readings) {
  final Map<String, HealthDay> byDate = <String, HealthDay>{
    for (final HealthDay day in readings) formatDay(day.date): day,
  };
  return <DayActivity>[
    for (final DateTime date in window)
      DayActivity(
        date: date,
        distanceMeters: metersFromHealth(
          distanceMeters: byDate[formatDay(date)]?.distanceMeters,
          stepCount: byDate[formatDay(date)]?.stepCount,
        ),
      ),
  ];
}

/// Applies cumulative local days. Mirrors `apply_activity_days` on the server.
WalkProgress applyActivityDays(WalkProgress state, List<DayActivity> days) {
  if (days.isEmpty) {
    throw ArgumentError('at least one day is required');
  }
  final List<DayActivity> ordered = List<DayActivity>.from(days)
    ..sort(
      (DayActivity a, DayActivity b) => dateOnly(a.date).compareTo(dateOnly(b.date)),
    );
  WalkProgress current = state;
  final List<EncounterEventKind> seen = <EncounterEventKind>[];
  final Set<DateTime> seenDates = <DateTime>{};

  void adopt(WalkProgress next) {
    current = next;
    for (final EncounterEventKind kind in next.events) {
      if (!seen.contains(kind)) {
        seen.add(kind);
      }
    }
  }

  for (final DayActivity day in ordered) {
    if (day.distanceMeters < 0) {
      throw ArgumentError('distance must be >= 0');
    }
    final DateTime date = dateOnly(day.date);
    if (!seenDates.add(date)) {
      throw ArgumentError('duplicate activity date');
    }
    if (current.progressDate == null) {
      current = current.copyWith(progressDate: date);
    }
    final DateTime? open = current.progressDate;
    if (open != null && date.isBefore(open)) {
      continue;
    }
    while (current.progressDate != null && current.progressDate!.isBefore(date)) {
      adopt(closeProgressDay(current));
    }
    final int delta = day.distanceMeters - current.todayDistanceM;
    if (delta > 0) {
      adopt(recordDistance(current, delta));
    }
  }
  if (seen.isEmpty) {
    return current;
  }
  return current.copyWith(events: seen);
}
