import 'package:flutter_test/flutter_test.dart';
import 'package:soulwalker/domain/activity_sync.dart';
import 'package:soulwalker/domain/encounter_loop.dart';
import 'package:soulwalker/domain/progress.dart';
import 'package:soulwalker/presentation/health_controller.dart';

void main() {
  final DateTime day = DateTime(2026, 10, 18);

  test('the first sync is today, then the open day through today', () {
    expect(
      activityWindow(progressDate: null, today: DateTime(2026, 10, 18, 23)),
      <DateTime>[day],
    );
    expect(
      activityWindow(progressDate: DateTime(2026, 10, 16), today: day),
      <DateTime>[
        DateTime(2026, 10, 16),
        DateTime(2026, 10, 17),
        day,
      ],
    );
  });

  test('walking distance wins, and steps use the shared stride', () {
    expect(metersFromHealth(distanceMeters: 1500, stepCount: 4000), 1500);
    expect(metersFromHealth(distanceMeters: 0, stepCount: 100), 78);
  });

  test('a reread of the same day adds only the new metres', () {
    WalkProgress state = applyActivityDays(
      const WalkProgress(),
      <DayActivity>[DayActivity(date: day, distanceMeters: 2000)],
    );
    expect(state.totalDistanceM, 2000);
    expect(state.progressDate, day);

    state = applyActivityDays(
      state,
      <DayActivity>[DayActivity(date: day, distanceMeters: 2000)],
    );
    expect(state.totalDistanceM, 2000);

    state = applyActivityDays(
      state,
      <DayActivity>[DayActivity(date: day, distanceMeters: 5000)],
    );
    expect(state.totalDistanceM, 5000);
    expect(state.streakDays, 1);
    expect(state.unlockedTiers, <int>[1, 2]);
  });

  test('a missed local day ends the attempt and keeps the distance', () {
    WalkProgress state = applyActivityDays(
      const WalkProgress(),
      <DayActivity>[DayActivity(date: day, distanceMeters: 5000)],
    );
    state = applyActivityDays(
      state,
      <DayActivity>[
        DayActivity(date: day, distanceMeters: 5000),
        DayActivity(date: DateTime(2026, 10, 19), distanceMeters: 0),
        DayActivity(date: DateTime(2026, 10, 20), distanceMeters: 1000),
      ],
    );
    expect(state.events, contains(EncounterEventKind.death));
    expect(state.attempt, 2);
    expect(state.streakDays, 0);
    expect(state.totalDistanceM, 6000);
    expect(state.progressDate, DateTime(2026, 10, 20));
    expect(state.unlockedTiers, <int>[1, 2]);
  });

  test('five local days finish the encounter', () {
    final List<DayActivity> days = <DayActivity>[
      for (var offset = 0; offset < EncounterRules.encounterLengthDays; offset++)
        DayActivity(
          date: DateTime(2026, 10, 18 + offset),
          distanceMeters: EncounterRules.dailyQualifyM,
        ),
    ];
    final WalkProgress state = applyActivityDays(const WalkProgress(), days);
    expect(state.encountersCompleted, 1);
    expect(state.streakDays, 0);
    expect(state.events, contains(EncounterEventKind.encounterCompleted));
  });

  test('sync sends today even when Health returns only steps', () async {
    final _FakeHealth health = _FakeHealth()
      ..readings = <HealthDay>[
        HealthDay(date: day, stepCount: 1000),
      ];
    final List<DayActivity> seen = <DayActivity>[];
    final HealthController controller = HealthController(
      health: health,
      progressDate: () => null,
      onDays: (List<DayActivity> days) async {
        seen.addAll(days);
      },
      clock: () => DateTime(2026, 10, 18, 15),
    );
    addTearDown(controller.dispose);

    await controller.sync();

    expect(seen, hasLength(1));
    expect(seen.single.distanceMeters, (1000 * 78) ~/ 100);
    expect(controller.note, contains('1000 steps'));
  });

  test('a phone without Apple Health explains that', () async {
    final HealthController controller = HealthController(
      health: _FakeHealth()..ready = false,
      progressDate: () => null,
      onDays: (List<DayActivity> days) async {},
      clock: () => day,
    );
    addTearDown(controller.dispose);

    await controller.sync();

    expect(controller.note, contains('physical iPhone'));
  });
}

class _FakeHealth implements HealthSource {
  bool ready = true;
  bool allowed = true;
  List<HealthDay> readings = <HealthDay>[];

  @override
  Future<bool> available() async => ready;

  @override
  Future<bool> requestAccess() async => allowed;

  @override
  Future<List<HealthDay>> readDays(List<DateTime> dates) async => readings;
}
