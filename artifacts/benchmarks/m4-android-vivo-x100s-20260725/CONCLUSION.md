# M4 vivo X100s signal-core frame probe

The named Android reference-device gate passed for sustained 120 Hz rendering.
The device was a vivo X100s (`V2359A`) running Android 16/API 36 on a MediaTek
MT6989 and Mali-G720-Immortalis MC12. The profile APK used Flutter 3.44.6 with
Impeller/Vulkan at 1260×2800 and an observed refresh rate of 120.000 Hz. Low
power mode was off and Android reported thermal status 0 before and after the
runs.

The first attached run immediately after installing the rebuilt profile APK is
preserved as `cold-measurements.jsonl`. It failed the strict 8,333 microsecond
`FrameTiming.totalSpan` latency gate on 2 of 55 measured frames: the run's total
P50 was 1,082 microseconds and P95 was 6,640 microseconds. This result is not
silently removed or presented as a pass.

Two subsequent process relaunches without reinstalling the APK both passed
after the specified five warmup frames:

- the primary hot run measured total P50 1,044 microseconds and P95 2,029
  microseconds, with 0 of 55 frames over budget;
- the independent repeat measured total P50 968 microseconds and P95 2,084
  microseconds, with 0 of 55 frames over budget.

Flutter defines `buildDuration` or `rasterDuration` above the frame budget as a
missed frame, while
[`totalSpan`](https://api.flutter.dev/flutter/dart-ui/FrameTiming/totalSpan.html)
above budget also detects more-than-one-frame latency. The repository keeps the
stricter existing `totalSpan` gate. Together with the Fedora 60 Hz result, the
two repeatable hot Android runs close M4's 60/120 Hz sustained-rendering gate.
The rejected post-install run remains an explicit cold-start observation for
later release profiling; it does not prove a cold-start latency pass.

The probe originally used `stdout.writeln` immediately before process exit.
That produced no Android log record even when Flutter was attached. The final
profile APK emits timing-only JSON synchronously through Flutter logging, which
preserves the existing `I/flutter`-prefix parser contract. The Android project
also now follows Flutter 3.44.6's effective API 24 floor instead of being
silently migrated from the obsolete explicit API 23 value on every build.

Reproduce the attached post-install run:

```bash
cd apps/client
flutter build apk --profile \
  --dart-define=VOXHANDOFF_M4_RENDER_BENCHMARK=true
flutter run --profile -d <android-device-serial> \
  --use-application-binary=build/app/outputs/flutter-apk/app-profile.apk \
  2>&1 | tee /tmp/voxhandoff-m4-android-attached.log
cd ../..
npm run benchmark:m4:summary -- \
  /tmp/voxhandoff-m4-android-attached.log
```

For a hot repeat, clear logcat, start a `flutter`-tag logcat capture, and launch
the installed activity without reinstalling the APK. Normalize the resulting
log by retaining only the benchmark header and sample JSON before committing
it; device serials, VM service URLs, host paths, and unrelated Android logs are
not part of these artifacts.
