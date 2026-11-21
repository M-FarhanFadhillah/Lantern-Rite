"""Lantern Tide fish generator: stylized low-poly fish, coloured through the shared palette atlas.

One JSON spec (art/blender/specs/fish/<name>.json) in; a GLB, the palette atlas and a preview PNG out.

Live, through the Blender MCP:
    import importlib.util
    spec = importlib.util.spec_from_file_location(
        "fish_gen", r"E:/Claude/Lantern-Tide/art/blender/fish_gen.py")
    fish_gen = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(fish_gen)
    stats = fish_gen.build("art/blender/specs/fish/kelp_snapper.json")

Headless (the Steam build of Blender is not on PATH):
    blender.exe -b -P art/blender/fish_gen.py -- --spec art/blender/specs/fish/kelp_snapper.json
                [--out art/blender/exports] [--preview art/blender/previews/<name>.png]

Relative paths resolve from the repo root, found from this file's location, never from the cwd.

Frame shared by every fish: length along Y with the head toward -Y (Blender's front), up +Z,
symmetric across X. 1 Blender unit = 1 stud and the export applies no scale factor. The glTF
exporter's default Y-up conversion maps Blender -Y (head) to glTF +Z, glTF's front, and Roblox's
importer turns glTF's front into its LookVector (-Z), so the head faces the MeshPart's LookVector.
Blender +Z (dorsal fin) becomes glTF and Roblox +Y. The M0 smoke test confirmed this in Studio: an
earlier head-toward-+Y build imported facing +Z, backwards.

The build runs in its own scene, "FishGen", created or cleared on every run. Other scenes are never
touched, the .blend is never saved, and in the live UI the previously active scene comes back at
the end.
"""

import argparse
import bisect
import json
import math
import re
import struct
import sys
import traceback
import zlib
from pathlib import Path

import bpy
from mathutils import Matrix, Vector
from mathutils.geometry import tessellate_polygon


def _script_path() -> Path:
    try:
        return Path(__file__).resolve()
    except NameError:  # exec'd as text: fall back to Blender's -P / --python argument
        for flag in ("-P", "--python"):
            if flag in sys.argv:
                return Path(sys.argv[sys.argv.index(flag) + 1]).resolve()
        raise RuntimeError("fish_gen: cannot locate fish_gen.py; load it from its file") from None


SCRIPT = _script_path()
BLENDER_DIR = SCRIPT.parent  # <repo>/art/blender
REPO_ROOT = BLENDER_DIR.parent.parent
PALETTE_PATH = BLENDER_DIR / "palette.json"
DEFAULT_OUT_DIR = BLENDER_DIR / "exports"
DEFAULT_PREVIEW_DIR = BLENDER_DIR / "previews"
ATLAS_FILENAME = "palette_atlas.png"

SCENE_NAME = "FishGen"
MATERIAL_NAME = "MAT_PaletteAtlas"
IMAGE_NAME = "FishGen_PaletteAtlas"
CAMERA_NAME = "FishGen_Camera"
LIGHT_NAME = "FishGen_Light"
WORLD_NAME = "FishGen_World"

TRI_MIN, TRI_MAX = 300, 1500  # PRD section 13 budget for one fish
UV_INSET = 0.25  # each face's UVs fill this fraction of its swatch cell, centred in the cell
UV_CORNERS = ((-1.0, -1.0), (1.0, -1.0), (0.0, 1.0))  # small triangle inside that square
PREVIEW_SIZE = 512
PREVIEW_VIEW_DIR = (1.0, -0.55, 0.35)  # target -> camera: a flank, a little from the front (-Y), above
PREVIEW_LENS_MM = 50.0
PREVIEW_MARGIN = 1.12
PREVIEW_BACKGROUND = (0.32, 0.42, 0.47)  # linear RGB, a muted sea grey-blue


def repo_path(p) -> Path:
    p = Path(p)
    return p if p.is_absolute() else REPO_ROOT / p


def _lerp(a, b, t):
    return a + (b - a) * t


def _clamp01(t):
    return max(0.0, min(1.0, t))


def _bbox(points):
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return lo, hi


# --------------------------------------------------------------------------- palette and atlas


def _hex_rgb(value):
    h = value.strip().lstrip("#")
    if len(h) != 6:
        raise ValueError(f"bad swatch colour {value!r}; expected #RRGGBB")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


class Palette:
    """Ordered swatches from palette.json, laid out as a grid of square cells in the atlas."""

    def __init__(self, path: Path):
        data = json.loads(path.read_text(encoding="utf-8"))
        atlas = data.get("atlas", {})
        self.size = int(atlas.get("size", 512))
        self.columns = int(atlas.get("columns", 8))
        if self.size % self.columns:
            raise ValueError(f"atlas size {self.size} does not divide into {self.columns} columns")
        self.cell = self.size // self.columns
        self.rows = self.size // self.cell  # square cells in a square atlas
        self.unused = _hex_rgb(atlas.get("unused_hex", "#FF00FF"))
        self.names, self.colors = [], []
        for swatch in data["swatches"]:
            if swatch["name"] in self.names:
                raise ValueError(f"palette.json repeats swatch {swatch['name']!r}")
            self.names.append(swatch["name"])
            self.colors.append(_hex_rgb(swatch["hex"]))
        if len(self.names) > self.columns * self.rows:
            raise ValueError(f"{len(self.names)} swatches do not fit a {self.columns}x{self.rows} atlas")

    def index(self, name):
        try:
            return self.names.index(name)
        except ValueError:
            raise KeyError(f"swatch {name!r} is not in palette.json") from None

    def uv_center(self, index):
        """Blender UV of a swatch cell's centre (row 0 is the top row of the PNG; v=0 is the bottom)."""
        col, row = index % self.columns, index // self.columns
        return (col + 0.5) / self.columns, 1.0 - (row + 0.5) / self.rows

    def write_atlas(self, path: Path):
        rows = []
        for py in range(self.size):  # PNG rows run top to bottom
            line = bytearray()
            for col in range(self.columns):
                i = (py // self.cell) * self.columns + col
                line += bytes(self.colors[i] if i < len(self.colors) else self.unused) * self.cell
            rows.append(bytes(line))
        _write_png(path, self.size, self.size, rows)


def _write_png(path: Path, width, height, rows):
    """Minimal 8-bit RGB PNG writer, so the atlas bytes are exactly the palette's sRGB values."""

    def chunk(tag, data):
        crc = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", crc)

    raw = b"".join(b"\x00" + row for row in rows)  # filter type 0 on every row
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"sRGB", b"\x00")
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


# --------------------------------------------------------------------------- geometry (pure Python)


class Curve:
    """Monotone cubic (Fritsch-Carlson) through [s, value] stations: smooth and never overshoots."""

    def __init__(self, xs, ys):
        if len(xs) < 2 or any(b <= a for a, b in zip(xs, xs[1:])):
            raise ValueError("a profile needs two or more stations with strictly increasing s")
        self.xs, self.ys = list(xs), list(ys)
        n = len(xs)
        d = [(ys[i + 1] - ys[i]) / (xs[i + 1] - xs[i]) for i in range(n - 1)]
        m = [d[0]] + [0.0 if d[i - 1] * d[i] <= 0 else (d[i - 1] + d[i]) / 2 for i in range(1, n - 1)]
        m.append(d[-1])
        for i in range(n - 1):
            if d[i] == 0:
                m[i] = m[i + 1] = 0.0
                continue
            a, b = m[i] / d[i], m[i + 1] / d[i]
            if a * a + b * b > 9:
                t = 3 / math.sqrt(a * a + b * b)
                m[i], m[i + 1] = t * a * d[i], t * b * d[i]
        self.m = m

    def __call__(self, x):
        xs, ys, m = self.xs, self.ys, self.m
        if x <= xs[0]:
            return ys[0]
        if x >= xs[-1]:
            return ys[-1]
        i = bisect.bisect_right(xs, x) - 1
        h = xs[i + 1] - xs[i]
        t = (x - xs[i]) / h
        t2, t3 = t * t, t * t * t
        return (
            (2 * t3 - 3 * t2 + 1) * ys[i]
            + (t3 - 2 * t2 + t) * h * m[i]
            + (-2 * t3 + 3 * t2) * ys[i + 1]
            + (t3 - t2) * h * m[i + 1]
        )


class BodyShape:
    """The lofted body in design units (total fish length = 1): nose tip at y=0, body toward -Y."""

    def __init__(self, spec):
        body = spec["body"]
        self.length = 1.0 - float(spec["tail"]["length"])  # nose to end of the peduncle
        side = sorted(body["side_profile"])
        top = sorted(body["top_profile"])
        self.top = Curve([p[0] for p in side], [p[1] for p in side])
        self.bottom = Curve([p[0] for p in side], [p[2] for p in side])
        self.half_width = Curve([p[0] for p in top], [p[1] for p in top])
        self.exponent = float(body.get("section_exponent", 2.0))

    def y(self, s):
        return -s * self.length

    def section(self, s):
        """(centre z, half height, half width) of the cross-section at s."""
        zt, zb = self.top(s), self.bottom(s)
        return (zt + zb) / 2, (zt - zb) / 2, self.half_width(s)

    def surface_x(self, s, z):
        zc, hh, hw = self.section(s)
        q = min(1.0, abs(z - zc) / hh) if hh > 0 else 1.0
        return hw * (1.0 - q**self.exponent) ** (1.0 / self.exponent)


class Part:
    """Triangles of one closed shell, each tagged with a face group (back, belly, fins...)."""

    def __init__(self, name):
        self.name = name
        self.verts = []
        self.faces = []  # ((a, b, c), group)

    def vert(self, co):
        self.verts.append(Vector(co))
        return len(self.verts) - 1

    def tri(self, a, b, c, group):
        self.faces.append(((a, b, c), group))

    def quad(self, a, b, c, d, group):
        v = self.verts
        if (v[a] - v[c]).length_squared <= (v[b] - v[d]).length_squared:
            self.tri(a, b, c, group)
            self.tri(a, c, d, group)
        else:
            self.tri(a, b, d, group)
            self.tri(b, c, d, group)

    def orient_outward(self):
        v = self.verts
        volume = sum(v[a].dot(v[b].cross(v[c])) for (a, b, c), _ in self.faces) / 6.0
        if volume < 0:
            self.faces = [((a, c, b), g) for (a, b, c), g in self.faces]
        return self

    def mirrored_x(self, name):
        p = Part(name)
        p.verts = [Vector((-co.x, co.y, co.z)) for co in self.verts]
        p.faces = [((a, c, b), g) for (a, b, c), g in self.faces]
        return p


def _ring_positions(segments, bias, edges):
    """Ring stations along s: (i/segments)**bias, plus every stripe edge so stripes stay crisp."""
    base = [(i / segments) ** bias for i in range(1, segments + 1)]
    gap = 0.35 / segments
    keep = [s for s in base if s >= 1.0 or all(abs(s - e) >= gap for e in edges)]
    return sorted({round(s, 6) for s in keep + [e for e in edges if 0.0 < e < 1.0]})


def _superellipse(sn, cs, exponent):
    if exponent == 2.0:
        return sn, cs
    f = 2.0 / exponent
    return math.copysign(abs(sn) ** f, sn), math.copysign(abs(cs) ** f, cs)


def build_body(spec, shape):
    body = spec["body"]
    n = int(body["ring_verts"])
    belly_from = float(body.get("belly_from_deg", 90.0))
    stripes = spec.get("stripes", [])
    edges = sorted({float(e) for st in stripes for e in (st["from"], st["to"])})
    ring_s = _ring_positions(int(body["segments"]), float(body.get("ring_bias", 1.0)), edges)
    part = Part("body")

    def group(k, s_mid):
        phi = (k + 0.5) * 360.0 / n  # angle of the face centre, from the top toward +X
        from_top = phi if phi <= 180.0 else 360.0 - phi
        if from_top > belly_from:
            return "belly"
        for st in stripes:
            if st["from"] <= s_mid <= st["to"] and from_top <= st.get("max_deg", belly_from):
                return "stripe"
        return "back"

    tip = part.vert((0.0, 0.0, shape.section(0.0)[0]))
    rings = []
    for s in ring_s:
        zc, hh, hw = shape.section(s)
        ring = []
        for k in range(n):
            theta = 2.0 * math.pi * k / n
            sx, cz = _superellipse(math.sin(theta), math.cos(theta), shape.exponent)
            ring.append(part.vert((hw * sx, shape.y(s), zc + hh * cz)))
        rings.append(ring)

    for k in range(n):
        part.tri(tip, rings[0][k], rings[0][(k + 1) % n], group(k, ring_s[0] / 2))
    for i in range(len(rings) - 1):
        r0, r1, s_mid = rings[i], rings[i + 1], (ring_s[i] + ring_s[i + 1]) / 2
        for k in range(n):
            k1 = (k + 1) % n
            part.quad(r0[k], r1[k], r1[k1], r0[k1], group(k, s_mid))
    cap = part.vert((0.0, shape.y(ring_s[-1]), shape.section(ring_s[-1])[0]))
    for k in range(n):
        part.tri(rings[-1][k], cap, rings[-1][(k + 1) % n], group(k, 1.0))
    return part.orient_outward(), ring_s


def _cross2(a, b, c):
    return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])


def _fin_part(name, outline, thickness, origin, u_axis, v_axis, group="fins"):
    """A closed fin slab: the 2D outline (u, v) on the plane origin + u*U + v*V, thick along U x V."""
    u_axis, v_axis = Vector(u_axis).normalized(), Vector(v_axis).normalized()
    n_axis = u_axis.cross(v_axis).normalized()
    origin = Vector(origin)
    n = len(outline)
    area = sum(_cross2((0, 0), outline[i], outline[(i + 1) % n]) for i in range(n))
    if area < 0:  # make the outline counter-clockwise in (u, v)
        outline, thickness = outline[::-1], thickness[::-1]
    part = Part(name)
    mids = [origin + u * u_axis + v * v_axis for u, v in outline]
    plus = [part.vert(m + n_axis * (0.5 * t)) for m, t in zip(mids, thickness)]
    minus = [part.vert(m - n_axis * (0.5 * t)) for m, t in zip(mids, thickness)]
    for a, b, c in tessellate_polygon([[Vector((u, v, 0.0)) for u, v in outline]]):
        if _cross2(outline[a], outline[b], outline[c]) < 0:
            b, c = c, b
        part.tri(plus[a], plus[b], plus[c], group)
        part.tri(minus[a], minus[c], minus[b], group)
    for i in range(n):
        j = (i + 1) % n
        part.quad(minus[i], minus[j], plus[j], plus[i], group)
    return part.orient_outward()


def build_tail(spec, shape):
    t = spec["tail"]
    length, spread = float(t["length"]), float(t["spread"])
    root, overlap = float(t["root_half_height"]), float(t["root_overlap"])
    style = t.get("style", "forked")
    if style == "forked":
        notch = (1.0 - float(t.get("fork_depth", 0.5))) * length
        upper = [(0.40 * length, 0.68 * spread), (length, spread), (0.82 * length, 0.38 * spread)]
        lower = [(u, -v) for u, v in reversed(upper)]
        outline = [(-overlap, root)] + upper + [(notch, 0.0)] + lower + [(-overlap, -root)]
    elif style == "rounded":
        steps = int(t.get("arc_steps", 6))
        arc = [math.radians(75.0 - 150.0 * j / steps) for j in range(steps + 1)]
        outline = [(-overlap, root)] + [(length * math.cos(a), spread * math.sin(a)) for a in arc]
        outline.append((-overlap, -root))
    else:
        raise ValueError(f"tail.style must be 'forked' or 'rounded', not {style!r}")
    th_root, th_tip = float(t["thickness_root"]), float(t["thickness_tip"])
    thickness = [_lerp(th_root, th_tip, _clamp01(u / length)) for u, _ in outline]
    zc_end = shape.section(1.0)[0]
    return _fin_part("tail", outline, thickness, (0.0, shape.y(1.0), zc_end), (0, -1, 0), (0, 0, 1))


def build_median_fin(name, fin, shape, side=1.0):
    """A fin on the midline: side=+1 rises from the back (dorsal), -1 hangs from the belly."""

    def edge_z(s):
        return shape.top(s) if side > 0 else shape.bottom(s)

    embed = float(fin["embed"])
    s0, s1 = float(fin["base_from"]), float(fin["base_to"])
    outline = [(shape.y(s0), edge_z(s0) - side * embed)]
    outline += [(shape.y(s), edge_z(s) + side * h) for s, h in fin["outline"]]
    outline.append((shape.y(s1), edge_z(s1) - side * embed))
    h_max = max(h for _, h in fin["outline"])
    tb, te = float(fin["thickness_base"]), float(fin["thickness_edge"])
    thickness = [tb] + [_lerp(tb, te, h / h_max) for _, h in fin["outline"]] + [tb]
    return _fin_part(name, outline, thickness, (0.0, 0.0, 0.0), (0, 1, 0), (0, 0, 1))


def build_pectorals(spec, shape):
    p = spec["pectoral"]
    s, length = float(p["s"]), float(p["length"])
    zc, hh, _ = shape.section(s)
    z = zc + float(p["height"]) * hh
    root = Vector((shape.surface_x(s, z) - float(p["embed"]), shape.y(s), z))
    sweep, droop = math.radians(p["sweep_deg"]), math.radians(p["droop_deg"])
    u_axis = Vector((math.sin(sweep) * math.cos(droop), -math.cos(sweep) * math.cos(droop), -math.sin(droop)))
    up = Vector((0.0, 0.0, 1.0))
    v_axis = (up - up.dot(u_axis) * u_axis).normalized()
    if p.get("twist_deg"):
        v_axis = Matrix.Rotation(math.radians(p["twist_deg"]), 3, u_axis) @ v_axis
    outline = [(u * length, v * length) for u, v in p["outline"]]
    th_root, th_tip = float(p["thickness_root"]), float(p["thickness_tip"])
    thickness = [_lerp(th_root, th_tip, _clamp01(u)) for u, _ in p["outline"]]
    right = _fin_part("pectoral_R", outline, thickness, root, u_axis, v_axis)
    return [right, right.mirrored_x("pectoral_L")]


def build_eyes(spec, shape):
    e = spec["eyes"]
    s = float(e["s"])
    zc, hh, _ = shape.section(s)
    z = zc + float(e["height"]) * hh
    surface = Vector((shape.surface_x(s, z), shape.y(s), z))
    yaw, pitch = math.radians(e["yaw_deg"]), math.radians(e["pitch_deg"])
    axis = Vector((math.cos(pitch) * math.cos(yaw), math.cos(pitch) * math.sin(yaw), math.sin(pitch)))
    up = Vector((0.0, 0.0, 1.0))
    c_axis = (up - up.dot(axis) * axis).normalized()
    b_axis = c_axis.cross(axis)
    radius = float(e["radius"])
    r_axis = radius * float(e["flatten"])
    center = surface - axis * (r_axis * (1.0 - float(e["protrude"])))
    segments, rings, pupil_deg = int(e["segments"]), int(e["rings"]), float(e["pupil_deg"])
    step = 180.0 / rings

    part = Part("eye_R")
    outer = part.vert(center + axis * r_axis)
    ring_ids = []
    for j in range(1, rings):
        phi = math.pi * j / rings
        ring_ids.append(
            [
                part.vert(
                    center
                    + axis * (r_axis * math.cos(phi))
                    + (b_axis * math.cos(th) + c_axis * math.sin(th)) * (radius * math.sin(phi))
                )
                for th in (2.0 * math.pi * k / segments for k in range(segments))
            ]
        )
    inner = part.vert(center - axis * r_axis)

    def group(phi_mid):
        return "pupil" if phi_mid < pupil_deg else "eye"

    for k in range(segments):
        k1 = (k + 1) % segments
        part.tri(outer, ring_ids[0][k], ring_ids[0][k1], group(step / 2))
        part.tri(ring_ids[-1][k], inner, ring_ids[-1][k1], group(180.0 - step / 2))
        for j in range(rings - 2):
            r0, r1 = ring_ids[j], ring_ids[j + 1]
            part.quad(r0[k], r1[k], r1[k1], r0[k1], group(step * (j + 1.5)))
    part.orient_outward()
    return [part, part.mirrored_x("eye_L")]


def build_parts(spec):
    shape = BodyShape(spec)
    body, ring_s = build_body(spec, shape)
    parts = [body, build_tail(spec, shape), build_median_fin("dorsal", spec["dorsal"], shape)]
    if "anal" in spec:
        parts.append(build_median_fin("anal", spec["anal"], shape, side=-1.0))
    parts += build_pectorals(spec, shape)
    parts += build_eyes(spec, shape)
    return parts, ring_s


def _head_to_front(v):
    """Turn 180 degrees about Z, so the head (built toward +Y) faces -Y, Blender's and glTF's front.

    A rotation, not a mirror: negating X as well as Y keeps the face winding and normals intact.
    """
    return Vector((-v.x, -v.y, v.z))


def assemble(parts, length):
    """Scale design units to studs (total Y extent = length), put the origin at the body's centre,
    and turn the fish so its head faces -Y."""
    every = [v for p in parts for v in p.verts]
    lo, hi = _bbox(every)
    scale = length / (hi.y - lo.y)
    blo, bhi = _bbox(parts[0].verts)
    center = (blo + bhi) * (0.5 * scale)
    verts, faces, groups, tris = [], [], [], {}
    for p in parts:
        base = len(verts)
        verts += [_head_to_front(v * scale - center) for v in p.verts]
        for (a, b, c), g in p.faces:
            faces.append((base + a, base + b, base + c))
            groups.append(g)
        tris[p.name] = len(p.faces)
    return verts, faces, groups, tris


# --------------------------------------------------------------------------- Blender side


def _enum_pick(ids, want):
    if want in ids:
        return want
    return next((i for i in ids if want.lower() in i.lower()), None)


def _set_enum(owner, prop, want):
    """Assign an enum from identifiers read at runtime (Blender 5.x renames some of them)."""
    try:
        ids = [item.identifier for item in owner.bl_rna.properties[prop].enum_items]
    except (KeyError, AttributeError):
        ids = []
    pick = _enum_pick(ids, want)
    if pick is None:  # dynamic enums (render engine, view transform) under-report; the error lists them
        try:
            setattr(owner, prop, "__fish_gen_probe__")
        except TypeError as err:
            ids = re.findall(r"'([^']+)'", str(err))
        pick = _enum_pick(ids, want)
    if pick is None:
        raise RuntimeError(f"{type(owner).__name__}.{prop}: no option like {want!r}; valid: {ids}")
    setattr(owner, prop, pick)
    return pick


def _socket(sockets, identifier):
    for sock in sockets:
        if sock.identifier == identifier:
            return sock
    for sock in sockets:
        if sock.name == identifier:
            return sock
    raise KeyError(f"node socket {identifier!r} not found")


def _purge(collection, name):
    block = collection.get(name)
    if block is not None and block.users == 0:
        collection.remove(block)


def _prepare_scene(name):
    """Create the FishGen scene, or empty it, and drop the datablocks the last run left behind."""
    scene = bpy.data.scenes.get(SCENE_NAME) or bpy.data.scenes.new(SCENE_NAME)
    for ob in list(scene.objects):
        if {s.name for s in ob.users_scene} <= {scene.name}:
            bpy.data.objects.remove(ob, do_unlink=True)
        elif ob.name in scene.collection.objects:
            scene.collection.objects.unlink(ob)
    for child in list(scene.collection.children):
        scene.collection.children.unlink(child)
    _purge(bpy.data.meshes, name)
    _purge(bpy.data.cameras, CAMERA_NAME)
    _purge(bpy.data.lights, LIGHT_NAME)
    _purge(bpy.data.materials, MATERIAL_NAME)
    _purge(bpy.data.images, IMAGE_NAME)
    return scene


def _configure_scene(scene):
    scene.unit_settings.scale_length = 1.0  # 1 Blender unit = 1 stud
    world = bpy.data.worlds.get(WORLD_NAME) or bpy.data.worlds.new(WORLD_NAME)
    world.color = PREVIEW_BACKGROUND
    scene.world = world
    render = scene.render
    render.resolution_x = PREVIEW_SIZE
    render.resolution_y = PREVIEW_SIZE
    render.resolution_percentage = 100
    render.film_transparent = False
    _set_enum(render, "engine", "WORKBENCH")
    _set_enum(render.image_settings, "file_format", "PNG")
    _set_enum(render.image_settings, "color_mode", "RGB")
    _set_enum(scene.display.shading, "light", "STUDIO")
    _set_enum(scene.display.shading, "color_type", "TEXTURE")
    try:
        _set_enum(scene.view_settings, "view_transform", "Standard")  # show palette colours as authored
    except RuntimeError as err:
        print(f"fish_gen: keeping the default view transform ({err})")


def _make_material(image):
    mat = bpy.data.materials.new(MATERIAL_NAME)
    if mat.node_tree is None:  # Blender before 5.0; 5.x always has a tree and deprecates use_nodes
        mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None) or nodes.new("ShaderNodeBsdfPrincipled")
    out = next((n for n in nodes if n.type == "OUTPUT_MATERIAL"), None) or nodes.new("ShaderNodeOutputMaterial")
    if not any(link.from_node == bsdf and link.to_node == out for link in links):
        links.new(_socket(bsdf.outputs, "BSDF"), _socket(out.inputs, "Surface"))
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.location = (bsdf.location.x - 340.0, bsdf.location.y)
    _set_enum(tex, "interpolation", "Closest")
    links.new(_socket(tex.outputs, "Color"), _socket(bsdf.inputs, "Base Color"))
    _socket(bsdf.inputs, "Roughness").default_value = 0.9
    _socket(bsdf.inputs, "Metallic").default_value = 0.0
    nodes.active = tex  # Workbench's Texture colour mode draws the active image node
    return mat


def _make_object(scene, name, verts, faces, groups, uv_centers, material, columns):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    if mesh.validate(verbose=True):
        raise RuntimeError(f"{name}: the generated mesh had invalid geometry (details in the console)")
    if hasattr(mesh, "shade_flat"):
        mesh.shade_flat()
    else:
        mesh.polygons.foreach_set("use_smooth", [False] * len(mesh.polygons))
    uv_layer = mesh.uv_layers.new(name="UVMap")
    half = 0.5 * UV_INSET / columns  # half the side of the small square inside one cell
    for poly in mesh.polygons:
        cu, cv = uv_centers[groups[poly.index]]
        for corner, loop_index in enumerate(poly.loop_indices):
            du, dv = UV_CORNERS[corner]
            uv_layer.data[loop_index].uv = (cu + du * half, cv + dv * half)
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    if obj.name != name or mesh.name != name:
        raise RuntimeError(f"the name {name!r} is taken outside the {SCENE_NAME} scene; free it and rerun")
    return obj


def _override(scene, obj=None):
    kwargs = {"scene": scene, "view_layer": scene.view_layers[0]}
    if obj is not None:
        kwargs.update(active_object=obj, object=obj, selected_objects=[obj], selected_editable_objects=[obj])
    return bpy.context.temp_override(**kwargs)


def _export_glb(scene, obj, path: Path):
    view_layer = scene.view_layers[0]
    for ob in scene.objects:
        ob.select_set(ob == obj, view_layer=view_layer)
    view_layer.objects.active = obj
    props = bpy.ops.export_scene.gltf.get_rna_type().properties

    def pick(prop, want):
        ids = [item.identifier for item in props[prop].enum_items]
        if not ids:  # dynamic enum (export_format lists its items through a callback): try it below
            return want
        found = _enum_pick(ids, want)
        if found is None:
            raise RuntimeError(f"glTF exporter {prop}: no option like {want!r}; valid: {ids}")
        return found

    kwargs = {"filepath": str(path), "export_format": pick("export_format", "GLB")}
    wanted = {
        "use_selection": True,
        "use_active_scene": True,
        "use_visible": False,
        "use_renderable": False,
        "use_active_collection": False,
        "export_yup": True,  # default Y-up conversion: Blender -Y (head) -> glTF +Z (front), +Z -> +Y
        "export_apply": True,
        "export_texcoords": True,
        "export_normals": True,
        "export_tangents": False,
        "export_attributes": False,
        "export_cameras": False,
        "export_lights": False,
        "export_animations": False,
        "export_skins": False,
        "export_morph": False,
        "export_extras": False,
        "export_draco_mesh_compression_enable": False,
        "will_save_settings": False,
    }
    kwargs.update({k: v for k, v in wanted.items() if k in props.keys()})
    if "export_materials" in props.keys():
        kwargs["export_materials"] = pick("export_materials", "EXPORT")
    if "export_image_format" in props.keys():
        kwargs["export_image_format"] = pick("export_image_format", "AUTO")  # keeps the PNG a PNG
    with _override(scene, obj):
        try:
            result = bpy.ops.export_scene.gltf(**kwargs)
        except TypeError as err:  # a dynamic enum rejected the guess; the message lists the options
            fmt = _enum_pick(re.findall(r"'([^']+)'", str(err)), "GLB")
            if fmt is None or fmt == kwargs["export_format"]:
                raise
            kwargs["export_format"] = fmt
            result = bpy.ops.export_scene.gltf(**kwargs)
    if "FINISHED" not in result or not path.exists():
        raise RuntimeError(f"glTF export failed ({result}) for {path}")


def _frame_camera(cam_obj, points):
    """Aim along PREVIEW_VIEW_DIR and back off until every vertex fits the square frame."""
    lo, hi = _bbox(points)
    center = (lo + hi) * 0.5
    forward = -Vector(PREVIEW_VIEW_DIR).normalized()  # the camera looks along this
    right = forward.cross(Vector((0.0, 0.0, 1.0))).normalized()
    up = right.cross(forward)
    cam_obj.data.lens = PREVIEW_LENS_MM
    tan_half = (cam_obj.data.sensor_width / 2.0) / PREVIEW_LENS_MM / PREVIEW_MARGIN
    distance = 0.0
    for co in points:
        p = co - center
        reach = max(abs(p.dot(right)), abs(p.dot(up))) / tan_half
        distance = max(distance, reach - p.dot(forward))
    cam_obj.location = center - forward * distance
    cam_obj.rotation_euler = forward.to_track_quat("-Z", "Y").to_euler()


def _render_preview(scene, obj, path: Path):
    cam_data = bpy.data.cameras.new(CAMERA_NAME)
    cam = bpy.data.objects.new(CAMERA_NAME, cam_data)
    light_types = [item.identifier for item in bpy.types.Light.bl_rna.properties["type"].enum_items]
    light_data = bpy.data.lights.new(LIGHT_NAME, type=_enum_pick(light_types, "SUN") or light_types[0])
    light = bpy.data.objects.new(LIGHT_NAME, light_data)
    light.rotation_euler = (math.radians(50.0), 0.0, math.radians(35.0))
    for ob in (cam, light):
        scene.collection.objects.link(ob)
    _frame_camera(cam, [obj.matrix_world @ v.co for v in obj.data.vertices])
    scene.camera = cam
    scene.render.filepath = str(path)
    try:
        with _override(scene):
            bpy.ops.render.render(write_still=True, scene=scene.name)
    finally:  # the camera and light are temporary
        scene.camera = None
        bpy.data.objects.remove(cam, do_unlink=True)
        bpy.data.objects.remove(light, do_unlink=True)
        bpy.data.cameras.remove(cam_data)
        bpy.data.lights.remove(light_data)
    if not path.exists():
        raise RuntimeError(f"the preview render did not write {path}")


def build(spec_path, out_dir=None, preview_path=None) -> dict:
    """Generate one fish from a JSON spec. Returns stats: triangles, size in studs, files written."""
    spec_file = repo_path(spec_path)
    spec = json.loads(spec_file.read_text(encoding="utf-8"))
    name = spec["name"]
    out_dir = repo_path(out_dir) if out_dir else DEFAULT_OUT_DIR
    preview = repo_path(preview_path) if preview_path else DEFAULT_PREVIEW_DIR / f"{name}.png"
    palette = Palette(PALETTE_PATH)

    # Geometry is pure Python, so a spec that breaks the budget fails before Blender data changes.
    parts, ring_s = build_parts(spec)
    verts, faces, groups, part_tris = assemble(parts, float(spec["length"]))
    triangles = len(faces)
    if not TRI_MIN <= triangles <= TRI_MAX:
        raise ValueError(f"{name}: {triangles} triangles is outside the {TRI_MIN}-{TRI_MAX} fish budget")
    colors = spec["colors"]
    missing = sorted({g for g in groups if g not in colors})
    if missing:
        raise KeyError(f"{name}: spec 'colors' has no swatch for face group(s) {missing}")
    uv_centers = {g: palette.uv_center(palette.index(colors[g])) for g in set(groups)}

    out_dir.mkdir(parents=True, exist_ok=True)
    preview.parent.mkdir(parents=True, exist_ok=True)
    atlas_path = out_dir / ATLAS_FILENAME
    palette.write_atlas(atlas_path)
    glb_path = out_dir / f"{name}.glb"

    wm = bpy.context.window_manager
    window = bpy.context.window or (wm.windows[0] if wm is not None and len(wm.windows) else None)
    previous = window.scene if window is not None else None
    scene = _prepare_scene(name)
    try:
        if window is not None:
            window.scene = scene
        _configure_scene(scene)
        image = bpy.data.images.load(str(atlas_path), check_existing=False)
        image.name = IMAGE_NAME
        material = _make_material(image)
        obj = _make_object(scene, name, verts, faces, groups, uv_centers, material, palette.columns)
        _export_glb(scene, obj, glb_path)
        _render_preview(scene, obj, preview)
    finally:
        if window is not None and previous is not None and window.scene != previous:
            window.scene = previous

    lo, hi = _bbox(verts)
    return {
        "name": name,
        "triangles": triangles,
        "triangles_by_part": part_tris,
        "body_rings": len(ring_s),
        "size_studs": [round(c, 4) for c in (hi - lo)],
        "bounds_min": [round(c, 4) for c in lo],
        "bounds_max": [round(c, 4) for c in hi],
        "origin": "centre of the body's bounding box",
        "orientation": "head toward -Y (glTF +Z, Roblox LookVector -Z), dorsal fin toward +Z, symmetric across X",
        "swatches": {g: colors[g] for g in sorted(set(groups))},
        "scene": SCENE_NAME,
        "files": {"glb": str(glb_path), "atlas": str(atlas_path), "preview": str(preview)},
    }


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser(prog="fish_gen.py", description="Build one fish from a JSON spec.")
    parser.add_argument("--spec", required=True, help="spec JSON; relative paths start at the repo root")
    parser.add_argument("--out", help="export folder (default art/blender/exports)")
    parser.add_argument("--preview", help="preview PNG (default art/blender/previews/<name>.png)")
    args = parser.parse_args(argv)
    stats = build(args.spec, args.out, args.preview)
    print("FISH_GEN_STATS " + json.dumps(stats))


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:  # make headless runs fail with a non-zero exit code
        traceback.print_exc()
        sys.exit(1)
