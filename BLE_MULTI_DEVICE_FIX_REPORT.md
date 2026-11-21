# BLE Multi-Device and Data Flow Fix Report

## Scope

This work implements the iOS-side multi-device BLE architecture on branch `feat/ipad-view-fix`. Each active bath can now persist and address its own ESP32 peripheral instead of sharing one global selected peripheral and measurement continuation.

The actively flashed ESP32 sketch at `/Users/rickysuprayudi/Documents/Arduino/serona_esp32_connectble/serona_esp32_connectble.ino` was inspected to confirm the service UUID, characteristic UUID, and JSON schema. The conflicted sketch copy inside this repository is not the firmware currently used by the sensor and is excluded from the runtime findings in this report.

## Architecture changes

- Added an optional, persisted `perangkatID` UUID to `Proyek`. Existing records remain loadable and require device reselection when no UUID exists.
- Corrected project creation and scan setup to save the selected peripheral UUID and device name. Customer-name input no longer overwrites device metadata.
- Changed `DeviceConnectionService` into a device connector and device-bound measurement-source provider.
- Added a `BLEMeasurementSource` bound to exactly one peripheral UUID.
- Replaced the BLE singleton's global peripheral, characteristic, read continuation, and measurement stream with per-peripheral sessions.
- Routed connection, discovery, notification, value, failure, and disconnection callbacks by `CBPeripheral.identifier`.
- Added per-session fan-out streams so multiple UI consumers can observe one sensor without stealing the stream from one another.
- Added restoration through `retrievePeripherals(withIdentifiers:)` and bounded reconnect behavior after unexpected disconnection.
- Corrected the BLE sequence to connect, discover the Serona service, discover the measurement characteristic, enable notifications, confirm `isNotifying`, and only then mark the session ready.
- Added connection, discovery, and initial-read timeouts. Pending continuations now complete on errors, empty values, disconnects, cancellation, and timeout.
- Added JSON frame reassembly for fragmented or concatenated BLE notifications, a 4 KB buffer limit, and validation for channel count, finite readings, and pH range.

## View-model and UI changes

- `ProyekDetailViewModel` obtains a source bound to `proyek.perangkatID` and reports a clear reselection error for legacy projects without an ID.
- Measurement timestamps are recorded so the UI can distinguish a ready connection with stale sensor data.
- Project-specific `batasKepekatan` and `batasPH` now drive displayed measurements and warnings instead of hard-coded defaults.
- The first successful sensor reading during bath creation/setup is now persisted automatically as that bath's immutable 100% initial-color baseline.
- Reconnection and restoration reuse the saved baseline. A reading received after a disconnect is treated as a current-color reading and cannot silently replace the initial baseline.
- Removed the invalid fallback that interpreted the raw AS7341 `visibleAverage` count as a percentage before a baseline existed. This prevents a false immediate “Kualitas larutan menurun” warning.
- Device switching updates and rolls back both device name and UUID atomically.
- Sensors assigned to another active bath are disabled in the device picker and identified with text and an icon.
- Bath cards distinguish disconnected, connecting, reconnecting, failed, connected, and stale-data states using text plus SF Symbols rather than color alone.
- Status uses semantic text styles, meaningful accessibility labels/hints, adaptive metric layout, and a minimum 44-point action target. An Accessibility 5 preview was added.

## Tests added and updated

- Multi-device routing: sensor A readings reach only sensor A subscribers and sensor B readings reach only sensor B subscribers.
- Fan-out: multiple subscribers for one sensor receive the same measurement.
- Framing: split JSON notifications are reassembled and concatenated JSON messages are separated.
- Payload validation: invalid channel counts are rejected.
- Project creation verifies the selected peripheral UUID is persisted.
- First-time setup verifies that the first successful measurement is saved as the 100% baseline.
- Reopening/reconnecting verifies that later measurements are calculated against the saved baseline instead of replacing it.
- Test stubs support device-bound measurement-source creation.

## Validation results

- `BuildProject(buildForTesting: true)` on iPhone 17 simulator (iOS 27.2): **passed**.
- New BLE routing and framing tests: **5 passed, 0 failed**.
- Full suite: **176 passed, 24 failed**. The remaining failures cover pre-existing recipe color persistence, dye/soda calculations, repair-step behavior, clean-water calibration, and initial-color behavior; they are outside this BLE change and were not modified to avoid broadening scope.
- Apple Developer Program agreement and iPad registration were completed. The app now builds, installs, and launches successfully on the connected physical destination `iPad (4)`.
- The first physical scan initially failed before BLE access because `TambahProyekView` bypassed its corrected view-model save path. It saved no peripheral UUID and incorrectly stored the customer name as the device name. The view now persists the selected sensor UUID and actual device name for both new and existing baths.
- Physical-device logging confirmed continuous, complete 126-byte BLE notifications from peripheral `587AD684-E2F4-EF2D-A4E8-0AB735211D1F`. Frames were not fragmented or truncated in the observed run.
- The received JSON contained `visibleAverage`, both clear readings, NIR, all eight AS7341 channels, and pH. Example decoded readings were approximately `visibleAverage=2865.8`, `ph=8.09`, and `channels=8`.
- iOS decoded the notified pH correctly and continuously (`8.08–8.09`). This confirms that the ESP32 sensor, BLE payload, frame decoder, JSON decoder, and per-device callback routing all operate end to end.
- Automatic first-reading baseline and saved-baseline reconnection tests: **2 passed, 0 failed**.
- The updated baseline lifecycle was installed and confirmed working on `iPad (4)`: setup captures 100%, while subsequent/reconnected readings are current measurements.
- SwiftFormat and SwiftLint could not run because neither executable is installed. The required `brew bundle` is blocked because `/opt/homebrew/Cellar` and Homebrew's lock directory are not writable by the current user. No system ownership or permissions were changed.
- Simulator interaction verified launch, the empty project screen, add-bath presentation, and device selection. Root dependency injection now uses the simulated service on Simulator instead of invoking CoreBluetooth, and the affected sheets/buttons were made width-adaptive with 44-point minimum targets after inspecting the screenshot and accessibility hierarchy.

## Remaining verification

1. Exercise a physical disconnect/reconnect cycle and confirm the displayed concentration continues to use the originally persisted baseline.
2. Verify the stale-data UI transition by stopping ESP32 notifications without deleting the bath.
3. Confirm warning behavior using known samples above and below each project's concentration and pH limits.
4. When a second sensor is available, connect two baths simultaneously and verify values never cross between projects.
