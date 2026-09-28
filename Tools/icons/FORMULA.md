# Icon Production Formula

Every Casita icon must land inside the acceptance envelope measured from
the approved navigation reference set (home, areas, settings, history,
activity, search, studio, addCard, automations). Icons outside this
envelope read as foreign to the family, regardless of craft quality.

## Acceptance envelope

### Hard gates — reject if outside

| Property | Range | How to measure |
|---|---|---|
| Stroke vs home | 0.85 – 1.15 | `python3 icontools.py <name>.d` |
| Ink coverage | 15% – 40% | same tool, `ink%` column |
| Aspect (w/h) | 0.90 – 1.10 | `extract.py` or `build_symbolset.bbox` |
| Parts | 1 – 4 | `icontools.py`, `parts` column |

**Aspect exception**: an object whose universally recognized silhouette is
inherently non-square (a lightning bolt, a key) keeps its natural
proportion. Write down why, and pair it with a rendered comparison proving
the square version is less recognizable.

**Sibling rule**: paired icons (windowOpen/windowClose, lock/lockOpen) must
share the same aspect ratio, stroke weight, and overall silhouette mass.
Build both from the same generation batch or from the same base drawing.

### Soft signals — inspect visually, do not auto-reject

- Holes sealed vs raw (leak count > 0 means broken linework)
- Hairline subpaths (may be legitimate interior detail)
- Sliver subpaths above 6:1 aspect (may be legitimate, e.g. a radiator fin)

## Production method

### Step 0: Visual research (before touching Recraft)

The prompt must describe how the object is **universally depicted in icon
design**, not how you imagine it. Every wasted round in this project came
from prompting an idea of the object instead of studying the convention
first.

1. **Study the canonical depiction.** Search existing icon sets (MDI, Font
   Awesome, Phosphor, Lucide, iOS native) for this object. Note what every
   successful version shares — viewing angle, dominant feature, level of
   detail. That shared core is the convention people already read instantly.

2. **Name the identity feature from the real object.** Ask: "what physical
   feature would a person name to distinguish this from a similar shape?"
   A tire vs a wheel vs a plate → tread. A clock vs a dial → hands and
   feet. A vent vs a grid → visible slats. The answer goes into the
   prompt's `[IDENTITY FEATURE]` slot and is the one thing the icon cannot
   survive without.

3. **Lock the viewing angle from the convention.** Front-facing for a tire,
   side profile for a car, top-down for a toilet seat. These are
   established readings, not creative choices — picking a "more
   interesting" angle produces an icon nobody recognises.

4. **Write down what this is NOT.** List the objects this could be mistaken
   for at 34pt (tire → gear, plate, film roll; vent → grid, waffle; hood →
   envelope, trapdoor). These go into the `MUST NOT INCLUDE` list and into
   explicit exclusions in the subject line.

Skip this step only for an object you have already shipped a successful
icon for in this family and are regenerating for weight or proportion.

### Step 1: Generate with Recraft

Generate 3 candidates using the locked Casita style. Use a `_vector` model
variant (SVG required). Pass `input_style_id` on every call.

Locked style IDs (use the 6-icon seed):
- `f4e85aed-8d97-43bc-a3d8-53ef3dd1f3c7` (seeded from all 6 nav icons)
- `0531d05a-18e7-46bf-b74b-c458d118bcaa` (original 2-icon seed, fallback)

### Step 2: Extract and measure

```bash
python3 extract.py candidate1 candidate2 candidate3
python3 icontools.py candidate1.d candidate2.d candidate3.d
```

Reject any candidate outside the hard gates. If fewer than 2 survive,
generate again with an adjusted prompt — do not ship the least bad.

### Step 3: Build into symbolsets and render

```bash
python3 build_symbolset.py candidate1.d nav_template.svg candidate1_preview.svg
```

Render all survivors at 34pt, 60pt, and 160pt beside casita.home and
casita.areas. The 34pt rendering is the acceptance gate — if the icon
doesn't read in under a second at that size, it fails.

### Step 4: Present all survivors for approval

Show every surviving candidate to the user. Never pick on their behalf.
The measurements break ties; the eye chooses.

### Step 5: Ship the approved candidate

Move the approved symbolset SVG into the asset catalogue.

### When to reach for hand-built centrelines instead

Only when the icon's identity depends on an exact numeric relationship
between two parts of the same glyph — a lock's shackle-to-body ratio, a
house's eave angle. Recraft treats prompted proportions as targets, not
constraints, and cannot hold them.

For everything else, Recraft's organic curves produce the "friendly
storybook object" character that defines this family. A hand-built
trapezoid with a seam line (hood, trunk) is geometrically correct and
reads as a diagram; the same subject from Recraft reads as an object.

## Prompt template

Use this template for every generation. Adjust only the subject-specific
lines (3–7).

```
SF Symbols style monoline icon, single solid color, transparent
background, centered, generously rounded corners.

THE MOST IMPORTANT RULE: draw exactly ONE dominant, bold,
instantly-recognizable silhouette that fills most of the square frame.
A viewer must identify the object from the outer silhouette alone, at a
glance, at very small size — before noticing any interior detail. Do not
add a second independent shape, a floating prop, dots, or ornamental
marks alongside the main silhouette; every stroke must belong to and
reinforce the ONE silhouette, not compete with it.

COMPOSITION — equally important: the object must read as one compact,
balanced, solidly-drawn mass that fills the square evenly and sits
visually centred. Nothing trails off toward a corner. No long thin
spindly parts. Where the object has a slender element, keep it short,
thick, and tucked close to the body. The finished icon should look like
a friendly, confidently drawn storybook object, not a technical diagram.

[SUBJECT]: draw ONLY [object]. No [excluded context].

[PROPORTION]: the silhouette fits a square bounding box, width within
10% of height.

[STROKE]: one consistent stroke weight, about 1/7 of the icon's height,
drawn as one filled compound path with fully rounded caps and joins, no
sharp corners.

[IDENTITY FEATURE]: [describe the one small detail inside the
silhouette]. This is the ONLY interior detail.

MUST NOT INCLUDE: [list specific elements Recraft tends to volunteer for
this subject], shading, gradients, 3D effects, multiple colors.

At most 1–2 enclosed white areas.
```

## Common prompt adjustments

- **Glyph too heavy (ink > 40%)**: ask for fewer interior details, thinner
  line, more white space inside the silhouette
- **Glyph too light (ink < 15%)**: ask for a bolder line, fill in thin
  areas
- **Aspect too wide**: specify "taller than wide" or "portrait orientation"
- **Aspect too narrow**: specify "wider composition" or "landscape leaning"
- **Stroke too heavy**: ask for 1/9 or 1/11 of height instead of 1/7
- **Stroke too light**: ask for 1/5 of height

## Reference measurements (approved navigation set)

```
Icon                  vs home    ink%   aspect   parts
home                    1.00    33.2    1.021       1
areas                   1.05    36.6    1.004       1
settings                0.79    30.8    0.917       2
history                 0.87    30.1    0.963       4
activity                0.92    18.0    1.054       1
search                  0.92    20.6    1.004       1
studio                  1.05    33.1    0.980       1
addCard                 1.05    17.8    1.000       1
automations             0.92    33.0    1.000       2
seatHeater (vehicle)    0.92    34.4    1.065       4
speedometer (vehicle)   0.92    24.2    1.053       2
```
