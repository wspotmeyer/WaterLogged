"""Minimal SVG path parser / transformer for building an SF Symbols template.

Normalises every command into absolute cubic segments so the geometry can be
affine-transformed and re-emitted without nested <g> transforms (real SF Symbols
templates put plain <path> elements straight inside each variant group).
"""

import re

NUM = re.compile(r'[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?')
CMD = re.compile(r'([MmLlHhVvCcSsQqTtAaZz])')


def _numbers(text):
    return [float(n) for n in NUM.findall(text)]


def parse(d):
    """Return a list of subpaths; each is (start_point, [cubic segments], closed).

    A cubic segment is (c1, c2, end); lines are expressed as cubics too.
    """
    tokens = [t for t in CMD.split(d) if t.strip()]
    subpaths = []
    cur = None            # current subpath dict
    pos = (0.0, 0.0)
    start = (0.0, 0.0)
    prev_c2 = None        # second control point of the previous cubic
    i = 0
    while i < len(tokens):
        cmd = tokens[i]
        args = _numbers(tokens[i + 1]) if i + 1 < len(tokens) and not CMD.fullmatch(tokens[i + 1]) else []
        i += 2 if args else 1

        def line_to(pt):
            nonlocal pos, prev_c2
            # A straight line as a cubic with controls on the segment.
            c1 = (pos[0] + (pt[0] - pos[0]) / 3.0, pos[1] + (pt[1] - pos[1]) / 3.0)
            c2 = (pos[0] + 2.0 * (pt[0] - pos[0]) / 3.0, pos[1] + 2.0 * (pt[1] - pos[1]) / 3.0)
            cur['segs'].append((c1, c2, pt))
            pos = pt
            prev_c2 = None

        def cubic_to(c1, c2, pt):
            nonlocal pos, prev_c2
            cur['segs'].append((c1, c2, pt))
            pos = pt
            prev_c2 = c2

        if cmd in 'Mm':
            rel = cmd.islower()
            for k in range(0, len(args), 2):
                x, y = args[k], args[k + 1]
                pt = (pos[0] + x, pos[1] + y) if rel else (x, y)
                if k == 0:
                    cur = {'start': pt, 'segs': [], 'closed': False}
                    subpaths.append(cur)
                    pos = start = pt
                    prev_c2 = None
                else:
                    line_to(pt)
        elif cmd in 'Ll':
            rel = cmd.islower()
            for k in range(0, len(args), 2):
                x, y = args[k], args[k + 1]
                line_to((pos[0] + x, pos[1] + y) if rel else (x, y))
        elif cmd in 'Hh':
            rel = cmd.islower()
            for x in args:
                line_to((pos[0] + x, pos[1]) if rel else (x, pos[1]))
        elif cmd in 'Vv':
            rel = cmd.islower()
            for y in args:
                line_to((pos[0], pos[1] + y) if rel else (pos[0], y))
        elif cmd in 'Cc':
            rel = cmd.islower()
            for k in range(0, len(args), 6):
                a = args[k:k + 6]
                if rel:
                    c1 = (pos[0] + a[0], pos[1] + a[1])
                    c2 = (pos[0] + a[2], pos[1] + a[3])
                    pt = (pos[0] + a[4], pos[1] + a[5])
                else:
                    c1, c2, pt = (a[0], a[1]), (a[2], a[3]), (a[4], a[5])
                cubic_to(c1, c2, pt)
        elif cmd in 'Ss':
            rel = cmd.islower()
            for k in range(0, len(args), 4):
                a = args[k:k + 4]
                # Reflect the previous second control point about the current point.
                c1 = (2 * pos[0] - prev_c2[0], 2 * pos[1] - prev_c2[1]) if prev_c2 else pos
                if rel:
                    c2 = (pos[0] + a[0], pos[1] + a[1])
                    pt = (pos[0] + a[2], pos[1] + a[3])
                else:
                    c2, pt = (a[0], a[1]), (a[2], a[3])
                cubic_to(c1, c2, pt)
        elif cmd in 'Zz':
            if cur is not None:
                cur['closed'] = True
                pos = cur['start']
                prev_c2 = None
        else:
            raise ValueError(f'unsupported path command: {cmd}')

    return [(s['start'], s['segs'], s['closed']) for s in subpaths]


def _cubic_extrema(p0, c1, c2, p3):
    """Exact axis extrema of one cubic, per axis, including endpoints."""
    out = []
    for axis in (0, 1):
        a = -p0[axis] + 3 * c1[axis] - 3 * c2[axis] + p3[axis]
        b = 2 * (p0[axis] - 2 * c1[axis] + c2[axis])
        c = c1[axis] - p0[axis]
        ts = []
        if abs(a) < 1e-12:
            if abs(b) > 1e-12:
                ts.append(-c / b)
        else:
            disc = b * b - 4 * a * c
            if disc >= 0:
                r = disc ** 0.5
                ts += [(-b + r) / (2 * a), (-b - r) / (2 * a)]
        vals = [p0[axis], p3[axis]]
        for t in ts:
            if 0 < t < 1:
                mt = 1 - t
                vals.append(mt ** 3 * p0[axis] + 3 * mt * mt * t * c1[axis]
                            + 3 * mt * t * t * c2[axis] + t ** 3 * p3[axis])
        out.append((min(vals), max(vals)))
    return out


def bbox(subpaths):
    xs = [float('inf'), float('-inf')]
    ys = [float('inf'), float('-inf')]
    for start, segs, _ in subpaths:
        pos = start
        xs = [min(xs[0], pos[0]), max(xs[1], pos[0])]
        ys = [min(ys[0], pos[1]), max(ys[1], pos[1])]
        for c1, c2, end in segs:
            (xlo, xhi), (ylo, yhi) = _cubic_extrema(pos, c1, c2, end)
            xs = [min(xs[0], xlo), max(xs[1], xhi)]
            ys = [min(ys[0], ylo), max(ys[1], yhi)]
            pos = end
    return xs[0], ys[0], xs[1], ys[1]


def fmt(v, places=7):
    s = f'{v:.{places}f}'.rstrip('0').rstrip('.')
    return '0' if s in ('', '-0') else s


def emit(subpaths, sx, sy, tx, ty, places=7):
    """Re-emit as an absolute path string under x' = sx*x + tx, y' = sy*y + ty."""
    def T(p):
        return (sx * p[0] + tx, sy * p[1] + ty)

    out = []
    for start, segs, closed in subpaths:
        s = T(start)
        out.append(f'M{fmt(s[0], places)},{fmt(s[1], places)}')
        for c1, c2, end in segs:
            a, b, e = T(c1), T(c2), T(end)
            out.append('C{},{},{},{},{},{}'.format(
                fmt(a[0], places), fmt(a[1], places),
                fmt(b[0], places), fmt(b[1], places),
                fmt(e[0], places), fmt(e[1], places)))
        if closed:
            out.append('Z')
    return ''.join(out)
