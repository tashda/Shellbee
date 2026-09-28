# Card icon plan

The **Bridge health** card (the server health reference) sets the direction: one clear mark, a confident rounded stroke, open space around it, and colour only when state matters. Its pulse line reads at the 22 pt card-header size without a surrounding badge. New card icons should be just as legible at 16 pt and still look intentional at 48 pt in the Icon Gallery.

| Surface | Direction | Status |
|---|---|---|
| Bridge health | Keep the single pulse line as the reference. Green means healthy; warning colour is reserved for a problem. | Reference |
| Vendors | Keep the three maker marks already in the app. Match their stroke weight and spacing to the health pulse. | Existing, refine only if gallery review finds a scale issue |
| Network | A central coordinator linked to three distinct outer nodes. The topology should read as a network even at card-header size. | Updated; review on real card |
| Link quality | A single ascending signal trace with strength shown by the active part of the mark. | Updated; review on real card |
| Batteries | A simple battery outline and visible fill level. Use attention colour only for low or critical readings. | Refine current instrument |
| Energy | A single open lightning stroke, with no filled gradient. | Updated; review on real card |
| Device types | A router and a smaller end device as two recognizable silhouettes, using shape as well as colour to distinguish them. | New instrument |
| Power sources | A compact plug and battery pair; the two forms should remain separable at 16 pt. | New instrument |
| Models | Three solid device silhouettes on one baseline: a plug, light, and sensor. | Updated; review on real card |
| Now: Pairing | Two linked endpoints instead of the old chain or radio badge. | Updated; review on real card |
| Now: Updating | An open upward arrow with a quiet progress line; success and failure remain distinct. | Updated; review on real card |
| Now: Interviewing | A small device under a magnifying arc; keep the progress spinner as the separate live-state cue. | New variant |

## Order of work

1. Draw **Device types** and **Power sources** together; these are the clearest missing card-specific metaphors.
2. Add the **Interviewing** variant so it does not share Pairing's mark.
3. Review the updated **Network**, **Link quality**, **Models**, **Pairing**, and **Updating** marks on real cards. Review **Batteries** and **Vendors** alongside them. Change only marks that lose meaning at 16 or 22 pt.
4. Check every candidate in light and dark appearance at 16, 22, 30, 40, and 48 pt, then on its actual Home or Device Statistics card. Verify meaning without relying on colour alone.

Keep the existing permit-join bee for toolbar and sheet actions. Recent Activity remains event rows with event-specific instruments, so it does not need a single card icon.
