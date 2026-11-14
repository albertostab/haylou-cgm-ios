# Background synchronization: implementation and validation

Based on main a50d767 (v0.2). No v0.2.1 branch exists on origin; the available Desktop archive is the original project. Existing v0.2 behavior is preserved and extended; WeatherCodec.swift is byte-for-byte unchanged.

Foreground polling: 60 seconds, immediate check on resume and GATT readiness. BLE readiness retries the cached fresh reading before fetching again. API write-without-response requests advance the deduplication watermark; this is NOT a receipt or display acknowledgement. Failed/disconnected writes do not advance it. After relaunch a new network fetch recovers pending latest data. Intermediate readings missed during suspension are not replayed as historical weather: the latest valid reading wins.

Reconnect targets only the user-selected saved UUID via retrievePeripherals. Pending connections are not duplicated. Connection and discovery failures retry with 2..300 second exponential backoff. Pending Core Bluetooth requests and subscriptions support restoration. Timer-based retry itself cannot run while suspended. No pairing reset or attempts to disconnect Haylou Fun. Notification subscription failures are logged; a subsequent reconnect rediscovers and resubscribes.

BGAppRefresh requests earliestBeginDate +60 seconds, resubmits at a grant, records grants and scheduler failures, cancels network work on expiration and completes exactly once. This date is a lower bound, not an interval guarantee. Spontaneous BLE callbacks may trigger a network check (60-second rate limit). A background callback does not prove the process had been suspended: logs distinguish observed callbacks from BG scheduler grants. The initial revision did not add a Live Activity; v0.3 below adds an explicitly unverified experiment. Push would require APNs/server infrastructure and signing entitlements; not included. No silent audio, fictitious location or synthetic keepalive.

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


## v0.3 Live Activity experiment
Adds an embedded WidgetKit extension and local ActivityKit session, started explicitly while foregrounded (or when automatic mode is enabled/resumed). No APNs tokens or server required. Shows Nightscout glucose, session state and reading age on Lock Screen and Dynamic Island. This is personal health data visible on the lock screen; privacySensitive marks value views for system privacy handling. Dismiss the Activity to hide it. Stops with automatic mode off; system/user may end it independently. A 60-second timer attempts a check only while foregrounded or an Activity is active AND iOS actually allows execution. It does not awaken a suspended process. No claim of stable execution on iOS 27.2 or with screen off. Compare physical 30-minute runs with/without the Activity; export logs after each.

GATT discovery is gated per connection and subscriptions are issued once; reset on disconnect/power loss. Network requests carry generation identifiers: expired requests are cancelled, callbacks cannot overwrite replacement requests, and concurrent triggers share completion. A request older than 30 seconds is replaced at the next opportunity. Obsolete Nightscout responses still never reach the watch.

Windows installation: Sideloadly must retain and sign the embedded LiveActivity.appex. If the Activity button fails, export logs and verify the extension was not stripped by the signing tool. Free signing/device compatibility is a separate physical installation check.


## Trend icons experiment
User requested RT2 weather icons to represent trend. Only climate=1 (sunny) has been physically verified. Proposed codes 2..6 and unknown=0 are provisional, NOT established firmware mappings: confirm visible icons before interpreting them. Proposed legend: sun Flat; partial cloud FortyFiveUp; cloud SingleUp/DoubleUp; light rain FortyFiveDown; rain SingleDown; storm DoubleDown. The RT2 mapping intentionally groups both upward rates; iPhone arrows preserve all seven standard Nightscout directions and show ? for missing/unrecognized direction. No inference of trend from glucose values. Framing/command/CRC/temperature conversion remain unchanged. The golden original sunny frame still must match exactly; each icon code is tested for valid frame/checksum. Device display/meaning still needs calibration.


## v0.4: retry after real-device suspension evidence

The supplied device log shows completed Nightscout/BLE/ActivityKit calls in some background opportunities, and long gaps where timers execute next to foreground transitions. It does not prove periodic wakeups. Two actionable defects: full-day history was fetched on every brief opportunity, and delayed reconnect could leave no pending connection before suspension.

Changes:
- Every background check fetches only the latest three entries; foreground fetches full-day history at most once per five minutes. Merge and persist the last 24 hours locally so a small response does not erase the graph. History cache contains glucose data, no URL or access token. Changing source clears this cache. Background request timeout is 15 seconds, still bounded by task expiry.
- First unexpected disconnect immediately submits a connect request for the saved RT2; a pending connect is left with Core Bluetooth instead of duplicating it. Repeated connection failures retain bounded backoff. Each actual network opportunity also attempts saved-device recovery when no retry delay is pending.
- Discover all services/characteristics of the selected peripheral, subscribe only characteristics advertising Notify/Indicate, and write only the existing weather characteristic. This expands observation of events such as Find Phone; their meaning is not assumed. Service invalidation rediscovery and up to three subscription retries are included. No unknown vendor commands, sensor-start commands, firmware modifications, audio or location keepalives.
- Log short BLE payloads and time since the last weather request for correlation, timer gaps instead of claiming a wake, request scope, OS/background-refresh/low-power state at a new test. Logs can contain accessory or glucose data and should not be posted publicly. A new test-log button avoids mixing old versions with the current experiment.
- Guard UIKit lease expiration by request generation, end the old lease before invoking callbacks, and clear BG expiration handler on completion.

### Two build variants (same app identifier)
`HaylouCGM-standard-unsigned-IPA`: current authorization model plus the changes above. Recommended first test.
`HaylouCGM-accessory-setup-unsigned-IPA`: adds the optional iOS AccessorySetupKit authorization experiment. Because declaring ASK changes Core Bluetooth permission and discovery semantics, this is deliberately a separate IPA, not a runtime toggle in the standard build. It does NOT add an APNs entitlement, server, subscription or special signing entitlement. Free-account signing/installation and the actual RT2 authorization still require physical verification.

In the ASK variant, Core Bluetooth is initialized only after the authorized saved device is obtained or the picker finishes. With a saved RT2 the system picker requests migration of that same UUID (no pairing deletion); a fresh setup filters FEE7/custom weather service plus Haylou/LS10/RT2 name. The firmware's advertised identity and system picker compatibility are unverified. No automatic switch to another device. If the picker cannot authorize the saved RT2, reinstall the standard IPA with the same signing identity to preserve local settings.

Apple TN3115 note 5 describes ASK improvements for specific restoration cases (force-quit, Control Center Bluetooth toggle, some airplane-mode conditions), NOT a minute-based network wakeup. BGContinuedProcessingTask is not used: an indefinite follower poll does not have finite user work and meaningful completion progress. ASK does not fix the absence of spontaneous accessory events by itself.

### Required physical comparison
1. Install standard v0.4, keep the configured Nightscout URL/read-only token and selected RT2. Check one foreground write. Tap “Inizia nuovo registro di prova”.
2. Ensure Background App Refresh is enabled, Low Power Mode off; do not force-quit. Lock for 30 minutes, observe actual RT2 values externally before reopening. Look for 3+ newer readings. Export log.
3. On a separate run, after five locked minutes press Find Phone on RT2 and note exact time and whether phone rings. Wait 30 seconds; observe watch before opening app. Correlate a received HEX event BEFORE a network check or weather write. Do not call a response after our write an unsolicited wakeup.
4. Repeat with ASK IPA, explicitly use “Autorizza RT2 con iOS” once, and verify system authorization completes before locking. Export a fresh test log. Compare observed gaps; no guaranteed cadence is claimed.
5. Test range loss/reconnect, graph retained with latest-only checks, stale data blocked, automatic mode disabled, no duplicate GATT readiness storm.

References:
- https://developer.apple.com/documentation/technotes/tn3115-bluetooth-state-restoration-app-relaunch-rules
- https://developer.apple.com/videos/play/wwdc2024/10203/ (ASK changes Core Bluetooth visibility)
- https://developer.apple.com/documentation/accessorysetupkit/discovering-and-configuring-accessories
- https://developer.apple.com/documentation/backgroundtasks/bgcontinuedprocessingtask

No v0.4 physical result has yet been measured. Compilation and unit tests are necessary but insufficient to claim continuous background updates.
