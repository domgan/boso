# boso

Android app for per-room control of TECH L-4X WiFi underfloor heating through the eModul cloud API. No server of its own: the phone talks to `https://emodul.eu/api/v1` directly.

The API spec is in `api/emodul.yaml`, with the referenced path files under `api/tags/`. Temperatures go over the wire in tenths of a degree.

## Token

The app authenticates with an API token generated on emodul.pl, baked in at build time. There's no login screen.

```bash
cp secrets.example.json secrets.json   # paste the token; secrets.json is gitignored
```

Anyone holding the APK can extract the token, so don't publish the APK. Generate one token per phone so a lost phone can be revoked on its own. After revoking a token, rebuild with a new one.

## Commands

Scripts live in `pubspec.yaml` under `scripts:` and run with [rps](https://pub.dev/packages/rps), the npm-scripts equivalent for Dart. Install it once with `dart pub global activate rps`; `~/.pub-cache/bin` has to be on `PATH`.

```bash
rps dev      # run on a phone with USB debugging (r = hot reload, q = quit)
rps check    # format check, analyze, tests
rps apk      # release APK in build/app/outputs/flutter-apk/
rps install  # build the APK and install it on the connected phone
```

`dev`, `apk` and `install` pass `--dart-define-from-file=secrets.json`. To install on a second phone with its own token, swap `secrets.json`, then run `rps install` with only that phone connected.

## Behaviour worth knowing

Changing a room's temperature switches the zone to `constantTemp`, which overrides its schedule. To go back to the schedule, use the official eModul app.
