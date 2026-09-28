# iPad Test Matrix

The iPad shell is covered in layers so a simulator-launch failure does not
erase the compile-time safety net:

1. `ipad-build` builds the complete app for an available iPad simulator.
2. `ipad-ui-tests` runs focused behavior tests on an iPad mini and a 13-inch
   iPad Pro during scheduled Full CI, manual Full CI, and `run-ui-tests` PRs.
3. The manual matrix below covers Stage Manager and intermediate geometry that
   XCTest cannot resize reliably.

The UI matrix connects two live mock bridges containing duplicate device and
group names but different IEEE addresses. Tests select the Secondary bridge,
assert `Bridge: Secondary` in device and group destinations, and verify the
Activity workspace contains Secondary logs without leaking Primary logs. This
is deliberately stricter than checking only that navigation occurred.

## Automated matrix

| Geometry | Orientations exercised | Behavior |
| --- | --- | --- |
| iPad mini | Landscape, portrait, landscape return | Workspace smoke, duplicate-name routing, narrow fallback and restoration |
| 13-inch iPad Pro | Landscape, portrait, landscape return | Workspace smoke, duplicate-name routing, expansive-to-standard adaptation and restoration |

Every UI test failure retains XCTest's automatic screenshots in the
`.xcresult`. Full CI uploads the bundle, build/test logs, and both
bridge/seeder logs for 14 days.
Do not quarantine the whole matrix. If an OS-specific XCTest defect is proven,
skip only the affected assertion with a linked issue and an expiry condition.

## Manual release checklist

Run this checklist on the current iPadOS release before a v2.0 release. Record
the device/runtime and attach screenshots for any failure.

| Form factor | Portrait | Landscape | Stage Manager narrow | Stage Manager medium | Stage Manager wide |
| --- | --- | --- | --- | --- | --- |
| iPad mini | Required | Required | When supported | When supported | When supported |
| 11-inch iPad | Required | Required | Required | Required | Required |
| 13-inch iPad | Required | Required | Required | Required | Required |

For each available cell:

- Open Home, Devices, Groups, Activity, Network Map, Settings, and Device
  Library. Confirm the shell does not overlap, clip controls, or lose the
  sidebar selection.
- Select a device, group, and log. Resize across compact, standard, and
  expansive widths, then return to the starting width. Confirm the same detail
  remains selected.
- Rotate portrait to landscape and back while a detail is selected. Confirm
  selection and scrollable content remain usable.
- With both mock bridges connected, filter to Secondary and open duplicate
  device and group names. Confirm both details show `Bridge: Secondary`,
  Activity shows only Secondary logs, and actions affect only that bridge.
- Open a second Activity window, resize both windows independently, background
  and foreground Shellbee, then close the second window. Confirm each scene
  restores its own route and the original window remains intact.

Stage Manager automation is not part of the scheduled gate because XCTest has
no stable public API for dragging arbitrary window chrome to exact widths. The
rotation test is the automated compact/regular restoration proxy; the manual
Stage Manager rows remain required release evidence.
