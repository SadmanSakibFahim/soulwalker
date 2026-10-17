/// PLAYTEST ONLY. Delete the `lib/dev/` folder to strip these hacks.
/// Enable with: flutter run --dart-define=SOULWALKER_DEV=true
library;

const bool kSoulwalkerDev = bool.fromEnvironment('SOULWALKER_DEV');

const String kDevApiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://127.0.0.1:8000',
);
