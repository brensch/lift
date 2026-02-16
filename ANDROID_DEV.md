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
