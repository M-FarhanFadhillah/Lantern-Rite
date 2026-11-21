# 2026-11-22 Export fish as GLB modeled in studs
PRD section: §13 (Pipeline steps 3 and 4)
Was: "Export FBX or glTF with consistent naming … and one fixed export scale. A Roblox stud is about 0.28 m, so choose a scale once and check it in Studio's 3D Importer on the first asset."
Now: Facts confirmed by the M0 smoke test.
- Export GLB (glTF binary, texture embedded) with `art/blender/fish_gen.py`, modeled in studs: 1 Blender unit = 1 stud, no export scale factor. Roblox imported the test fish at exactly the Blender size, 0.844 × 1.117 × 2.400 studs.
- Orientation for every fish: head toward Blender −Y (Blender's front), which becomes glTF +Z (glTF's front). Roblox's importer turns glTF's front into its LookVector (−Z), so the head faces the MeshPart's LookVector. The dorsal fin goes Blender +Z → Roblox +Y. The first upload had the head toward Blender +Y and imported facing backwards; the generator now turns every fish 180° about Z.
- Colour: faces are UV-mapped into the shared 512 px palette atlas, generated from `art/blender/palette.json` (32 provisional swatches until the Figma style guide). The atlas is embedded in the GLB; Roblox's importer creates the image asset and sets `MeshPart.TextureID`, and an identical atlas reuses the same image ID.
- One joined mesh per fish, which imports as one MeshPart. Fish budget 300-1,500 triangles, enforced by the generator; the test fish has 484.
- Specs live in `art/blender/specs/fish/<name>.json`, previews in `art/blender/previews/`.
- Headless batch: `& "E:\SteamLibrary\steamapps\common\Blender\blender.exe" -b -P art/blender/fish_gen.py -- --spec art/blender/specs/fish/<name>.json`.
Why: Studio's import guide says FBX usually imports at 1 cm = 1 stud (28× too big) while GLB imports at 1 unit = 1 stud. Flat material colours often import as default grey, but a texture survives. Matching glTF's front lets M1 code aim fish with `CFrame.lookAt`.

Links: [[PRD]] · [[sessions/2026-11-21 2137 M0 foundations]] · [[playtests/2026-11-22 M0 fish smoke test]]
