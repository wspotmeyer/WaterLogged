#!/usr/bin/env python3
"""Build a static SF Symbols template (27 variants) from a plain SVG icon.

See README.md in this folder for the why, the geometry, and the limitations.

Usage:
    ./build_symbol_template.py ARTWORK.svg --symbolset PATH.symbolset
    ./build_symbol_template.py ARTWORK.svg -o TEMPLATE.svg --height 100

The artwork is expected to be ordinary filled paths (no strokes, no nested
transforms) — an Illustrator export like the icons in
WaterLogged/Assets.xcassets/Icons. Every path in the file is treated as one
monochrome layer of a single symbol.
"""

import argparse
import json
import pathlib
import re
import sys

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import pathkit

# --- Template geometry -------------------------------------------------------
# These constants are read off a genuine v6.0 template that ships inside
# SF Symbols.app, so the canvas, guides and row positions are exactly what the
# SF Symbols app and Xcode expect. Do not "tidy" them.

WEIGHTS = ['Ultralight', 'Thin', 'Light', 'Regular', 'Medium',
           'Semibold', 'Bold', 'Heavy', 'Black']
SCALES = {'S': 0.783, 'M': 1.0, 'L': 1.29}   # documented scale factors
ROW_BASELINE = {'S': 696.0, 'M': 1126.0, 'L': 1556.0}
CAP_HEIGHT = 70.459                           # baseline - capline
BAND_ABOVE = 95.215                           # baseline -> top of margin guide
BAND_BELOW = 24.121                           # baseline -> bottom of margin guide
DESIGN_BAND = BAND_ABOVE + BAND_BELOW         # 119.336: the full design area
COL0 = 559.711                                # centre of the Ultralight column
COL_STEP = 296.711                            # column pitch
CAP_CENTRE = -CAP_HEIGHT / 2.0                # glyph centre, relative to baseline

DEFAULT_TEMPLATE_DIR = pathlib.Path('/Applications/SF Symbols.app/Contents/Resources')
DEFAULT_TEMPLATE = DEFAULT_TEMPLATE_DIR / 'badge.record.svg'

STYLE = """ <style>.monochrome-0 {fill:#000000}
.multicolor-0:tintColor {fill:#000000}
.hierarchical-0:primary {fill:#000000}

.SFSymbolsPreviewWireframe {fill:none;opacity:1.0;stroke:black;stroke-width:0.5}
</style>"""

PATH_CLASS = 'monochrome-0 multicolor-0:tintColor hierarchical-0:primary SFSymbolsPreviewWireframe'


def find_donor_template(explicit=None):
    """Locate a real SF Symbols template to copy the Notes and guides from."""
    if explicit:
        path = pathlib.Path(explicit)
        if not path.is_file():
            sys.exit(f'error: template not found: {path}')
        return path
    if DEFAULT_TEMPLATE.is_file():
        return DEFAULT_TEMPLATE
    # The bundle layout may change between SF Symbols releases; fall back to
    # any bundled SVG that carries the guide layer we need.
    if DEFAULT_TEMPLATE_DIR.is_dir():
        for candidate in sorted(DEFAULT_TEMPLATE_DIR.glob('*.svg')):
            if 'Baseline-S' in candidate.read_text():
                return candidate
    sys.exit('error: no donor template found. Install SF Symbols.app, or pass '
             '--template with a template exported from it.')


def group_block(src, start_tag):
    """Extract a top-level <g id="..."> block, depth-matching on <g>/</g>."""
    i = src.index(start_tag)
    depth = 0
    j = i
    while True:
        nxt_open = src.find('<g', j + 1)
        nxt_close = src.find('</g>', j + 1)
        if nxt_close == -1:
            raise ValueError('unbalanced <g> in donor template')
        if nxt_open != -1 and nxt_open < nxt_close:
            depth += 1
            j = nxt_open
        else:
            if depth == 0:
                return src[i:nxt_close + 4]
            depth -= 1
            j = nxt_close


def unwrap(block):
    """Strip the outer <g ...> / </g> from a block, keeping nested groups whole.

    Sliced rather than line-filtered on purpose: the Guides layer contains
    multi-line <g id="H-reference"> groups, and dropping every line that holds
    a </g> would leave those groups unclosed.
    """
    inner = block[block.index('>') + 1:]
    return inner[:inner.rindex('</g>')]


def build(artwork_path, donor_path, glyph_height):
    donor = donor_path.read_text()
    notes = group_block(donor, '<g id="Notes">')
    guide_lines = [ln for ln in unwrap(group_block(donor, '<g id="Guides">')).splitlines()
                   if ln.strip() and 'margin' not in ln]

    artwork = artwork_path.read_text()
    subpaths = [sp for d in re.findall(r'<path[^>]*\sd="([^"]+)"', artwork)
                for sp in pathkit.parse(d)]
    if not subpaths:
        sys.exit(f'error: no <path d="…"> found in {artwork_path}')

    bx0, by0, bx1, by1 = pathkit.bbox(subpaths)
    art_h = by1 - by0
    aspect = (bx1 - bx0) / art_h
    art_cy = (by0 + by1) / 2.0

    margins, symbols = [], []
    for scale, factor in SCALES.items():
        baseline = ROW_BASELINE[scale]
        h = glyph_height * factor
        w = h * aspect
        s_art = h / art_h
        for k, weight in enumerate(WEIGHTS):
            origin_x = COL0 + COL_STEP * k - w / 2.0
            name = f'{weight}-{scale}'

            # Coordinates are baked into group-local space — x = 0 at the left
            # margin, y = 0 on the baseline, glyph centred on the cap height —
            # so each variant group can hold a plain <path>, like Apple's own
            # templates do. A nested <g transform> here is not worth the risk.
            d = pathkit.emit(subpaths, s_art, s_art,
                             -s_art * bx0, -s_art * art_cy + CAP_CENTRE)

            symbols.append(
                f'  <g id="{name}" transform="matrix(1 0 0 1 {pathkit.fmt(origin_x)} '
                f'{pathkit.fmt(baseline)})">\n'
                f'   <path class="{PATH_CLASS}" d="{d}"/>\n'
                f'  </g>')
            for side, x, colour in (('left', origin_x, '#00AEEF'),
                                    ('right', origin_x + w, '#FF3B30')):
                margins.append(
                    f'  <line id="{side}-margin-{name}" style="fill:none;stroke:{colour};'
                    f'stroke-width:0.5;opacity:1.0;" x1="{pathkit.fmt(x)}" '
                    f'x2="{pathkit.fmt(x)}" y1="{pathkit.fmt(baseline - BAND_ABOVE)}" '
                    f'y2="{pathkit.fmt(baseline + BAND_BELOW)}"/>')

    doc = '\n'.join([
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<!--Generator: WaterLogged Scripts/SymbolTemplate/build_symbol_template.py-->',
        '<!DOCTYPE svg',
        'PUBLIC "-//W3C//DTD SVG 1.1//EN"',
        '       "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">',
        '<svg version="1.1" xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" viewBox="0 0 3300 2200">',
        f'<!--{artwork_path.name}: static template, single drawn weight, '
        f'glyph height {pathkit.fmt(glyph_height)} at Regular-M-->',
        STYLE,
        notes,
        ' <g id="Guides">',
        '\n'.join(guide_lines),
        '\n'.join(margins),
        ' </g>',
        ' <g id="Symbols">',
        '\n'.join(symbols),
        ' </g>',
        '</svg>',
        '',
    ])

    stats = {
        'artwork_size': (bx1 - bx0, art_h),
        'aspect': aspect,
        'variants': len(symbols),
    }
    return doc, stats


def write_symbolset(directory, svg_name, doc):
    directory.mkdir(parents=True, exist_ok=True)
    (directory / svg_name).write_text(doc)
    contents = {
        'info': {'author': 'xcode', 'version': 1},
        'symbols': [{'filename': svg_name, 'idiom': 'universal'}],
    }
    (directory / 'Contents.json').write_text(json.dumps(contents, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(
        description='Build a static SF Symbols template from a plain SVG icon.')
    parser.add_argument('artwork', type=pathlib.Path,
                        help='source SVG (plain filled paths)')
    parser.add_argument('-o', '--output', type=pathlib.Path,
                        help='write the template SVG here')
    parser.add_argument('--symbolset', type=pathlib.Path,
                        help='write a ready-to-use .symbolset folder here '
                             '(SVG + Contents.json); the folder name sets the asset name')
    parser.add_argument('--height', type=float, default=100.0,
                        help=f'glyph height at Regular-M in template units '
                             f'(default 100; the design band is {DESIGN_BAND:.3f})')
    parser.add_argument('--template', help='donor template SVG to copy Notes/guides from')
    args = parser.parse_args()

    if not args.output and not args.symbolset:
        parser.error('pass --output and/or --symbolset')
    if not args.artwork.is_file():
        sys.exit(f'error: artwork not found: {args.artwork}')

    donor = find_donor_template(args.template)
    doc, stats = build(args.artwork, donor, args.height)

    print(f'donor template: {donor}')
    print('artwork bbox: {:.3f} x {:.3f} (aspect {:.4f})'.format(*stats['artwork_size'],
                                                                 stats['aspect']))
    for scale, factor in SCALES.items():
        h = args.height * factor
        print(f'  {scale}: glyph {h:.2f} tall x {h * stats["aspect"]:.2f} wide')
    print(f'variants: {stats["variants"]}')

    if args.output:
        args.output.write_text(doc)
        print(f'wrote {args.output}')
    if args.symbolset:
        name = args.symbolset.name.removesuffix('.symbolset')
        write_symbolset(args.symbolset, f'{name}.svg', doc)
        print(f'wrote {args.symbolset}/ ({name}.svg + Contents.json)')


if __name__ == '__main__':
    main()
