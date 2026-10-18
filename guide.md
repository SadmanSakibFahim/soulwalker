# Tomorrow morning

One command prepares the database and starts the API. A second command puts the app on your iPhone. Apple Health is how steps that Fitness already recorded get into the encounter.

## 1. Start the Mac side

Docker Desktop has to be open. From the repo:

```bash
./scripts/morning.sh
```

That starts Postgres, applies the database revision, loads the world pack, and starts the API. Leave it. The script prints a phone command with this Mac's Wi-Fi address already filled in.

The phone and the Mac need the same Wi-Fi. The Mac has to stay awake while you play, because the API runs on it.

The phone script uses Xcode from `/Applications/Xcode.app`. The license on this Mac is not accepted yet. `morning.sh` prints this if it is still true. Run it once, then the phone command:

```bash
sudo /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -license accept
```

## 2. Put the app on the iPhone

Plug the phone in, unlock it, and trust this Mac if it asks. Then run the command `morning.sh` printed. It looks like:

```bash
API_BASE=http://YOUR_MAC_IP:8000 ./scripts/run-mobile-dev.sh --release
```

`--release` keeps the app on the phone after you unplug. The first launch may ask Xcode for a signing team. In Xcode, open `apps/mobile/ios/Runner.xcworkspace`, select the Runner target, and pick your Personal Team. If signing says the profile is missing HealthKit, stay on that target, open Signing & Capabilities, add HealthKit, and run the phone command again.

## 3. Connect Apple Health

Fitness and the Health app store the same steps. Soulwalker reads them from Health. You do not start a workout inside Soulwalker for this.

On **a Held Breath**:

1. Tap **Connect API** in the dev panel (science button). The amber bar should say you are connected. That tap also asks Apple Health for access and banks today.
2. On the Apple sheet, turn on **Steps** and **Walking + Running Distance**.
3. If you dismissed the sheet, or today shows 0 while Fitness already has a walk: open the **Health** app → **Sharing** → **Apps** → **Soulwalker** → turn those two on. Then tap **Sync Apple Health** in Soulwalker.
4. The same switches live under **Settings → Privacy & Security → Health → Soulwalker**.

The first sync counts **today's** steps, including steps taken before you opened Soulwalker. Earlier days stay in Fitness and do not count. After that, opening the app catches up each local day since the open day, up to 31 days, from what Fitness stored. A day counts once it reaches 5 km. Five counted days finish the encounter. Extra distance on a day that already counted stays in your total and does not count as another day.

Open Soulwalker again later in the day, or the next morning. **Sync Apple Health** banks the new distance. You can also just tap **Connect API** again. A real midnight closes the day the next time you sync. On the phone, leave **Close day** alone. That button is for the simulator.

An Apple Watch walk shows up once it is in the Health app. Soulwalker is reading that store, so the watch does not need a separate connection.

**Start walk** is the fallback that measures from the moment you tap it, using the phone's motion coprocessor. Use **Sync Apple Health** for steps Fitness already has. Using both on the same outing can count those steps twice.

## Simulator, if you are not on the phone

The simulator has no Apple Health data. **Sync Apple Health** will say so. The `+km` buttons fake the distance.

```bash
./scripts/morning.sh
./scripts/run-mobile-dev.sh
```

If Flutter asks which device, pick the simulator:

```bash
flutter devices
./scripts/run-mobile-dev.sh -d iPhone
```

The app opens with an amber **DEV** bar. If that bar is missing, this terminal was a plain `flutter run`. Stop it and use the script above.

Tap the science button if the panel is closed.

1. Tap **Connect API** first. That signs you in as `devwalker` and loads whatever that account already has saved.
2. Stay on the first tab, **a Held Breath**.
3. Tap **+5 km**. That counts day 1 of 5 and unlocks both armaments.
4. Tap **Close day**. The streak stays. Today's bar goes back to 0.
5. Repeat until the fifth counted day. On that fifth +5 km the encounter finishes.

To see a failed attempt: +5 km, Close day, then Close day again without adding distance. The attempt number becomes 2. Walked kilometres and armaments stay.

| Button | What you get |
|---|---|
| +1 km / +3 km | Distance only. 3 km unlocks the first armament. The day counts at 5 km. |
| Pull lore | A fragment from the API, or a bundled line if the API is down |
| Drop death marker | A local “Died here, attempt #N” on **a Failed Waking**. It is not saved. |
| Reset local | Clears the screen. It does not wipe the database. |

**the Quiet Census** and **a Shared Vigil** are still empty of live rankings and nearby players.

## Stop

The API is running in the background after `morning.sh`. To stop it:

```bash
kill "$(cat "${TMPDIR:-/tmp}/soulwalker-api.pid")"
```

If you started it in a terminal instead, press Ctrl-C there. Postgres can keep running. To turn it off:

```bash
docker compose stop
```

Your `devwalker` progress stays in the database volume.

## If it fails

| What you see | What to do |
|---|---|
| `docker compose` cannot connect | Open Docker Desktop and wait until it is running, then `./scripts/morning.sh` |
| Alembic cannot connect | Postgres is on port **5433**. Check `docker compose ps` |
| `/v1/dev/status` is 404 | `.env` needs `DEV_MODE=true`. Stop the API and run `./scripts/morning.sh` again |
| Column or relation does not exist | Run `./scripts/morning.sh` again |
| No Flutter device | Plug in the phone and unlock it, or `open -a Simulator`, then `flutter devices` |
| Connect API says the API is down | On a phone, `API_BASE` must be the Mac's Wi-Fi address, not `127.0.0.1`. The Mac must be awake |
| Sync says Apple Health is not on this device | You are on the simulator, or this is not an iPhone. Use `+km`, or run on the phone |
| Today stays 0 and Fitness has steps | Health → Sharing → Apps → Soulwalker → turn on Steps and Walking + Running Distance, then Sync again |
| Xcode license | `sudo /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -license accept` |
| Signing failed, or HealthKit is missing from the profile | Open `apps/mobile/ios/Runner.xcworkspace`, pick your Personal Team on the Runner target, add the HealthKit capability, and run the phone command again |
| API log | `tail -n 80 "${TMPDIR:-/tmp}/soulwalker-api.log"` |

Longer operator notes: [`docs/manual/getting-started.md`](docs/manual/getting-started.md).
