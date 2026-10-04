# SymbolTemplate

Turns a plain SVG icon (the Illustrator exports in `WaterLogged/Assets.xcassets/Icons`)
into an **SF Symbols template**, so the icon can live in a `.symbolset` and behave
like a real symbol instead of a fixed-size bitmap-ish image.

These are developer tools. They are **not part of any Xcode target** and nothing
in the build runs them — you run them by hand when an icon needs to become a
symbol, and commit the generated `.symbolset`.

## Why this exists

Every icon in `Assets.xcassets/Icons` is a 1200×1200 Illustrator export, so its
intrinsic size is **1200×1200 points**. That is invisible in most of the app
because the call sites apply `.resizable()` and a frame — but anything that
renders an image at its natural size has no frame to clamp it. Using
`scuba.diver` as a tab icon painted a 1200pt cropped diver over the whole tab
bar.

Declaring a small `width`/`height` on the SVG fixes the blow-up but leaves you
with a fixed-size image. A symbol set is the real fix: it scales with the font,
tints properly, and aligns to the text baseline.

## Usage

Generate a ready-to-use asset directly into the catalog:

```sh
cd Scripts/SymbolTemplate
./build_symbol_template.py \
    ../../WaterLogged/Assets.xcassets/Icons/scuba.diver.imageset/scuba.diver.svg \
    --symbolset ../../WaterLogged/Assets.xcassets/Icons/scuba.diver.symbol.symbolset
```

That writes the template SVG plus a `Contents.json`. The folder name sets the
asset name, so the example above would be used as
`Image("scuba.diver.symbol")` or `Tab("Dives", image: "scuba.diver.symbol", value: …)`.
(The app's Dives tab currently uses an SF Symbol instead; the symbol set is kept
in the catalog as this script's worked example.)

Or just inspect the template without touching the catalog:

```sh
./build_symbol_template.py path/to/icon.svg -o /tmp/icon-template.svg --height 100
```

| Option | Meaning |
|---|---|
| `--symbolset DIR` | Write `DIR/<name>.svg` + `Contents.json`, ready for Xcode |
| `-o, --output FILE` | Write just the template SVG |
| `--height N` | Glyph height at Regular-M, in template units (default `100`; the design band is `119.336`) |
| `--template FILE` | Donor template to copy the Notes/guides from (defaults to one inside SF Symbols.app) |

The artwork must be **ordinary filled paths** — no strokes, no nested
transforms. Outline any strokes in Illustrator first. Every `<path>` in the file
is treated as one monochrome layer of a single symbol.

## What it produces, and the catch

A **static** template: all 27 weight/scale variants, but only *one drawn weight*.
The nine weights are geometrically identical and only the S/M/L scale factors
differ. So the symbol scales and tints correctly, and it will **not** get heavier
next to bold text the way a real SF Symbol does.

To get genuine weight variants, export a **variable** template from SF Symbols
(File ▸ Export Template ▸ Variable — three variants: `Ultralight-S`,
`Regular-S`, `Black-S`, from which the system interpolates the other 24) and draw
the three weights in Illustrator. This script can lay the artwork into the
Regular slot as a starting point.

Also worth knowing: **iOS keeps tab-bar icon metrics fixed across Dynamic Type
sizes** (verified at AX 3 — the stock SF Symbols beside it don't grow either).
The Dynamic Type benefit shows up in toolbars, labels and list rows, not the tab
bar.

## How it works

`pathkit.py` parses an SVG path, normalises every command — including the
relative `c`, `s`, `l`, `h`, `v` that Illustrator emits — into absolute cubic
segments. That makes two things possible: an exact bounding box from the cubic
extrema (not a control-point approximation), and an affine transform applied to
the coordinates themselves.

`build_symbol_template.py` bakes that transform into the path data, so each
variant group contains a plain `<path>` with no nested `<g transform>` — the same
shape as Apple's own templates.

Geometry constants come from a genuine v6.0 template that ships inside
`SF Symbols.app/Contents/Resources` (`badge.record.svg`), so the canvas and
guides are exactly what the SF Symbols app and Xcode expect:

| Constant | Value |
|---|---|
| Canvas | `viewBox="0 0 3300 2200"` |
| Row baselines (S / M / L) | `696` / `1126` / `1556` |
| Cap height | `70.459` |
| Design band | baseline − `95.215` to baseline + `24.121` |
| Weight columns | centred at `559.711 + 296.711·k`, k = 0…8 |
| Scale factors (S / M / L) | `0.783` / `1.0` / `1.29` |

The `Notes` layer and the H-reference / baseline / capline guides are copied
verbatim from the donor; margin guides are emitted per variant. Each glyph is
placed with its left edge on the left margin and centred on the cap-height band.

## Verifying a generated symbol

1. Build. `actool` validates symbol sets and will fail the build on a malformed
   template — that's the check that matters for shipping.
2. Confirm it really became a symbol rather than a plain image:

   ```swift
   let image = UIImage(named: "scuba.diver.symbol")
   print(image?.isSymbolImage as Any)   // must be true
   ```

   `scuba.diver.symbol` measures 14.7pt at `caption2`, 22.3pt at `body` and
   44.3pt at `largeTitle`.
3. Optionally open the symbol set in Xcode's asset editor to eyeball all 27
   variants, or run SF Symbols ▸ File ▸ Validate Templates.

## Gotchas hit while writing this

- When stripping the outer `<g id="Guides">` wrapper, **slice** it off; don't
  filter out lines containing `</g>`. The guides layer holds multi-line
  `<g id="H-reference">` groups, and line-filtering leaves them unclosed —
  the file stays plausible-looking but is no longer well-formed XML.
- Keep all of an icon's paths in the same `monochrome-0` layer. Splitting them
  across layers implies hierarchical/multicolor annotation data, which then has
  to stay in sync across variants.
- Don't rely on the source SVG filling its own `viewBox`. `scuba.diver`'s
  artwork actually occupies `1072.516 × 829.379` of its 1200 box, which is why
  placement is computed from the measured bbox.
