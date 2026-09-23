# Card icon plan

The **Bridge health** card (the server health reference) sets the direction: one clear mark, a confident rounded stroke, open space around it, and colour only when state matters. Its pulse line reads at the 22 pt card-header size without a surrounding badge. New card icons should be just as legible at 16 pt and still look intentional at 48 pt in the Icon Gallery.

| Surface | Direction | Status |
|---|---|---|
| Bridge health | Keep the single pulse line as the reference. Green means healthy; warning colour is reserved for a problem. | Reference |
| Vendors | Keep the three maker marks already in the app. Match their stroke weight and spacing to the health pulse. | Existing, refine only if gallery review finds a scale issue |
| Network | A central coordinator linked to a few distinct outer nodes. The topology should read as a network even at card-header size. | Refine current instrument |
| Link quality | A small, ascending signal trace with strength shown by the active part of the mark. Avoid a generic Wi-Fi symbol. | Refine current instrument |
| Batteries | A simple battery outline and visible fill level. Use attention colour only for low or critical readings. | Refine current instrument |
| Device types | A router and a smaller end device as two recognizable silhouettes, using shape as well as colour to distinguish them. | New instrument |
| Power sources | A compact plug and battery pair; the two forms should remain separable at 16 pt. | New instrument |
| Models | Three different device silhouettes on one baseline, with fewer details than the current drawing. | Refine current instrument |
| Now: Updating | A device outline with an upward progress arrow, drawn in the same stroke language as Bridge health. | New variant |
| Now: Interviewing | A small device under a magnifying arc; keep the progress spinner as the separate live-state cue. | New variant |

## Order of work

1. Draw **Device types** and **Power sources** together; these are the clearest missing card-specific metaphors.
2. Add the **Updating** and **Interviewing** variants so the Now card's states do not share a generic pairing mark.
3. Review **Network**, **Link quality**, **Batteries**, **Models**, and **Vendors** against Bridge health in the Icon Gallery. Change only marks that lose meaning at 16 or 22 pt.
4. Check every candidate in light and dark appearance at 16, 22, 30, 40, and 48 pt, then on its actual Home or Device Statistics card. Verify meaning without relying on colour alone.

Keep the existing permit-join bee for Pairing. Recent Activity remains event rows with event-specific instruments, so it does not need a single card icon.
