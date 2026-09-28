# iPad window and external-display test matrix

Run this matrix with the dual mock bridge connected. At every size, keep a
device or log selected while resizing across the next breakpoint; selection,
filters, search text, and the active section must remain intact.

| Target | Window coverage | Expected shell |
|---|---|---|
| iPad mini | Full screen portrait and landscape; narrow and wide Stage Manager tiles | Compact fallback at narrow width; two-column split when space permits |
| iPad 11-inch | One-third, half, two-thirds, and full-screen widths | Compact, standard, then expansive transitions without clipped controls |
| iPad 13-inch | One-third, half, two-thirds, and full-screen widths | Same breakpoint behavior; three columns at expansive widths |
| External display | 1080p and 4K scaled modes; full window and side-by-side windows | Full multi-column layout based on scene width, not the iPad's orientation |

For each row verify:

- Home, Devices, Groups, Activity, Settings, and Network Map remain reachable.
- The selected tab, bridge, device/group/log, filters, and navigation path do not reset while resizing.
- Device and group context menus, pointer highlights, keyboard shortcuts, sheets, and popovers stay attached to the active Shellbee window.
- Notification banners remain inside the safe area and never span beyond their capped readable width.
- The compact fallback exposes the sidebar back path and no column becomes unreachable.
- Open Network Map in a separate window, move it to the external display, then zoom, pan, fit, and select a node at each display scale.
- Background and foreground both windows; confirm only one connection loop exists per bridge and closing either window leaves the other connected.
