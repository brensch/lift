# Android Development (Physical Device)

## Prerequisites

- Android device with USB debugging enabled
- `adb` installed on your host machine
- Flutter SDK installed (see `make install-deps`)

## Enabling USB Debugging on Android

1. Go to **Settings > About phone**
2. Tap **Build number** 7 times to enable Developer options
3. Go to **Settings > Developer options**
4. Enable **USB debugging**
5. Connect the device via USB and accept the debugging prompt on the device

## Connecting to localhost gRPC over USB

Android devices can't reach your host machine's `localhost` directly. The `adb reverse` command forwards a port from the device's localhost to the host's localhost:

```bash
~/android-sdk/platform-tools/adb reverse tcp:50051 tcp:50051
```

This is already included in `make run-android` and `make run-app`, so it happens automatically.

To verify the connection manually:

```bash
adb reverse --list
```

To remove the reverse mapping:

```bash
adb reverse --remove tcp:50051
```

## Running the App on Android

1. Start the backend:
   ```bash
   make run-backend
   ```

2. Connect your Android device via USB

3. Run the app (sets up `adb reverse` automatically):
   ```bash
   make run-android
   ```

   Flutter will detect the connected device and deploy to it. If multiple devices are connected, use:
   ```bash
   ~/android-sdk/platform-tools/adb reverse tcp:50051 tcp:50051
   cd app && flutter run -d <device-id>
   ```

   List available devices with:
   ```bash
   flutter devices
   ```

## Connecting A Wear OS Device (Pixel Watch) From WSL2

Wear OS debugging is wireless on modern watches. `adb pair` alone is not enough; you must also run `adb connect`.

1. On watch:
   - Enable **Developer options**
   - Enable **ADB debugging**
   - Open **Wireless debugging**
   - Note:
     - pairing endpoint: `<watch_ip>:<pair_port>`
     - debugging endpoint: `<watch_ip>:<debug_port>`
     - pairing code

2. In the same shell you use for `make` (important in WSL2):
   ```bash
   ~/android-sdk/platform-tools/adb kill-server
   ~/android-sdk/platform-tools/adb start-server
   ~/android-sdk/platform-tools/adb pair <watch_ip>:<pair_port>
   ~/android-sdk/platform-tools/adb connect <watch_ip>:<debug_port>
   ~/android-sdk/platform-tools/adb devices
   ```

3. Run the Wear app:
   - Auto-detect first connected device:
     ```bash
     make run-wear
     ```
   - Or explicitly target the watch serial:
     ```bash
     WEAR_SERIAL=<watch_ip>:<debug_port> make run-wear
     ```

If your phone is attached over USB (for example via `usbipd`), auto-detect may pick the phone first. In that case, pass `WEAR_SERIAL` explicitly.

## Building a Release APK

```bash
cd app && flutter build apk --release
```

The APK will be at `app/build/app/outputs/flutter-apk/app-release.apk`.

Install it directly to a connected device:

```bash
adb install app/build/app/outputs/flutter-apk/app-release.apk
```

## Troubleshooting

- **Device not detected**: Run `adb devices` to check. If unauthorized, re-accept the USB debugging prompt on the device.
- **gRPC connection refused**: Make sure the backend is running (`make run-backend`) and `adb reverse` is active (`adb reverse --list`).
- **Multiple devices**: Specify which device with `adb -s <serial> reverse tcp:50051 tcp:50051`.
- **Wear watch not listed in WSL2**: re-run both commands in WSL shell: `adb pair ...` then `adb connect ...`.
