# Find Phone classification, v0.4.1

The user supplied an external APK-analysis report: hl_cmds field 36 contains r_find_phone; nested field 1 m_ring_status uses 0=start and nonzero=stop. The APK and the Linux-local patch are not available in this Windows workspace. This is an independent implementation, not an application of commit a03d502 or an independent verification of that APK. It is based on cf793d1, preserving the published v0.4 changes above the report's older c26b92a base.

## Read-only integration

- Complete frames are checked with the existing weather CRC/framing validator. No outgoing packet changes.
- Bounded per-characteristic streams reassemble split notifications and multiple frames. Malformed, overflowing, oversized or expired input is rejected. Unsupported transport formats remain unclassified.
- The reported Find Phone start/stop fields and command 26 are classified. No undocumented arm/start command is sent to the watch, and this change does not implement a phone ringtone.
- Complete classified weather ACKs, stop events, malformed input and incomplete frames never trigger Nightscout. Unclassified data retains the throttled v0.4 fallback, suppressed within five seconds of a weather write. The former rate limits already prevented a deterministic immediate write/ACK loop; excluding known ACKs makes this explicit.
- Find Phone start requests an immediate Nightscout check or joins an existing request, with a five-second repeated-press limit. It does not require the generic 55-second waiting period.
- Existing lightweight background reads, graph history/cache, UI, pending BLE reconnect and optional AccessorySetupKit build are preserved.

## Important corrections to the external report

The remote branch is newer than c26b92a. Do not apply a replacement BridgeModel from that older revision.

Lack of MFi certification does not by itself exclude Bluetooth LE accessories from AccessorySetupKit. Apple's accessory pages distinguish ASK/Core Bluetooth from ExternalAccessory/MFi. RT2 authorization and any benefit still require physical verification; ASK creates no periodic network timer.

An APK inspection finding no periodic event in that implementation does not prove that no firmware event exists in every configuration. No automatic periodic mechanism has been demonstrated here.

## Tests and physical evidence

Synthetic Swift fixtures cover explicit/default start, stop, invalid wire encoding, malformed/overflowing protobuf, bad CRC, all split positions of a start frame, fragmented weather frames, multiple frames, expiry and bounded arbitrary input. These are not RT2 captures.

1. Install the standard v0.4.1 IPA, connect RT2 and start a new diagnostic log.
2. With the app open, press Find Phone and record the exact time and whether the phone rings. Check for a classified findPhoneStart before the Nightscout check and weather write. Preserve UUID and HEX evidence.
3. Repeat after at least five minutes locked, without opening the app. Observe the actual RT2 display for 30 seconds before exporting the log.
4. If the data remains unclassified, provide the short HEX/UUID/timestamp section. Do not reinterpret an ACK after our write as an unsolicited event.
5. A successful wrist-triggered refresh is manual, not evidence of continuous background sync. Retain the separate 30-minute locked/three-new-readings test for that claim.

Sources for the MFi distinction:
- https://developer.apple.com/bluetooth/
- https://developer.apple.com/accessories/
- https://developer.apple.com/documentation/accessorysetupkit/setting-up-and-authorizing-a-bluetooth-accessory
