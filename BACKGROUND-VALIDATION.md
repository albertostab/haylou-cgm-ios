# Background synchronization: implementation and validation

Based on main a50d767 (v0.2). No v0.2.1 branch exists on origin; the available Desktop archive is the original project. Existing v0.2 behavior is preserved and extended; WeatherCodec.swift is byte-for-byte unchanged.

Foreground polling: 60 seconds, immediate check on resume and GATT readiness. BLE readiness retries the cached fresh reading before fetching again. API write-without-response requests advance the deduplication watermark; this is NOT a receipt or display acknowledgement. Failed/disconnected writes do not advance it. After relaunch a new network fetch recovers pending latest data. Intermediate readings missed during suspension are not replayed as historical weather: the latest valid reading wins.

Reconnect targets only the user-selected saved UUID via retrievePeripherals. Pending connections are not duplicated. Connection and discovery failures retry with 2..300 second exponential backoff. Pending Core Bluetooth requests and subscriptions support restoration. Timer-based retry itself cannot run while suspended. No pairing reset or attempts to disconnect Haylou Fun. Notification subscription failures are logged; a subsequent reconnect rediscovers and resubscribes.

BGAppRefresh requests earliestBeginDate +60 seconds, resubmits at a grant, records grants and scheduler failures, cancels network work on expiration and completes exactly once. This date is a lower bound, not an interval guarantee. Spontaneous BLE callbacks may trigger a network check (60-second rate limit). A background callback does not prove the process had been suspended: logs distinguish observed callbacks from BG scheduler grants. No Live Activity is added: there is no measured benefit for this app. Push would require APNs/server infrastructure and signing entitlements; not included. No silent audio, fictitious location or synthetic keepalive.

The persistent log retains the latest 2000 events and can be shared as text. Includes reading timestamps, age at write, origins, retries and lifecycle. No request URL, token, response body or localized network error is logged. Export contains CGM timestamps and should be treated as personal data. Diagnostic export computes age of the last queued reading at export time; the actual watch contents remain unconfirmed.

## Physical acceptance test (NOT YET PERFORMED)
1. Install PR IPA, enter a read-only token locally, select RT2, enable automatic sync. Confirm one foreground update.
2. Export baseline log; record Nightscout reading time and actual watch display.
3. Lock iPhone for at least 30 minutes, do not reopen app. Record watch display/time externally after each change; at least three newer Nightscout readings should be observed on the watch.
4. Unlock and export log. Compare reading timestamps, HTTP check origins, BG grants, BLE callbacks and write requests against observed display updates. Measure gaps of 1/5/12+ minutes. Absence of callbacks/grants during a gap is an OS opportunity gap, not proof of an HTTP failure.
5. Repeat with brief range loss and Bluetooth off/on; check saved UUID reconnection, GATT subscriptions and pending latest reading. Also test expired data, network loss and automatic mode off.

Build/unit success cannot substitute for this physical test. User previously reported two locked-screen updates with irregular intervals; no new physical evidence is available in this change.

## Apple references
- https://developer.apple.com/documentation/backgroundtasks/bgtaskrequest/earliestbegindate
- https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules
- https://developer.apple.com/documentation/uikit/using-background-tasks-to-update-your-app
