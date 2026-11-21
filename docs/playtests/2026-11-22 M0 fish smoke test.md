# 2026-11-22 M0 fish smoke test
Milestone: M0
Build / commit: "M0: fish faces its LookVector; loaded by asset ID in a playtest"
Platforms tested: PC only (Studio playtest driven through the Studio MCP). Phone not yet: see Decisions to make.
Testers: Claude (automated)
Session: [[sessions/2026-11-21 2137 M0 foundations]] · Plan: [[plans/2026-11-21 M0 Foundations]]

![[img/2026-11-22 M0 fish hero.jpg]]

## What was tested
- **The M0 gate:** the generated fish loads from its asset ID (`AssetIds.Fish.FSH_KelpSnapper`) in a Studio playtest, spawned by `SmokeTestService` with `InsertService:LoadAsset`.
- Studio's import checklist (rbx-import-asset): part count, texture, size, orientation, anchoring, placement.

## What felt good
- Console: `[SmokeTest] FSH_KelpSnapper 87926189441992 loaded, size 0.84 x 1.12 x 2.40 studs`, alongside `[Server] 1 services started` and `[Client] 0 controllers started`. No errors from our code.
- **Part count:** one MeshPart, matching the one source mesh.
- **Size:** 0.844 × 1.117 × 2.400 studs, exactly the Blender size, so a GLB modeled in studs needs no scale factor.
- **Placement:** upright (UpVector +Y), anchored, resting on the ground (bottom y = 0) 10 studs beside the spawn.
- **Facing:** the head faces the MeshPart's LookVector (−Z).
- **Texture:** `TextureID = rbxassetid://76272778184597` (the palette atlas, created by the importer), with colours matching the Blender preview. The second upload reused the same image ID, so an identical atlas doesn't create a new image asset.
- Jest suite still 4/4 (Edit mode).

Blender preview, then the same fish in Studio from +X (screen right is −Z):
![[img/2026-11-22 FSH_KelpSnapper preview.png]]
![[img/2026-11-22 M0 fish side.jpg]]

## What felt bad
- **The first upload faced backwards.** Asset 85973780481219 imported with its head toward +Z: Roblox's importer turns glTF's front (+Z) into Roblox's front (−Z, LookVector), and `fish_gen.py` had put the nose at glTF −Z.
  - Fix: `fish_gen.py` now turns the fish 180° about Z, so the head faces Blender −Y, which is glTF +Z. Re-exported and re-uploaded as 87926189441992.
  - The old asset is unused; archive it in the Creator Dashboard if you want it gone.
  ![[img/2026-11-22 M0 fish side backwards (first upload).jpg]]
- **Uploads were refused five times.** Studio's Assistant Settings → MCP Permissions → "Open Cloud upload directories" listed only `E:/Claude/Lantern-Tide/studio`. Adding a folder only counts once **Save** is pressed. Claude added `art/blender/exports`, `art/figma` and `art/audio` (each through the folder picker) and saved.
- Right after the first upload, the texture logged "Asset content representation is being generated" (x3). It was gone a minute later.

## Bugs
- None in our code. The `rbxassetid://203785492` warnings on Play start are still there and aren't ours.

## Decisions to make (link to [[decisions/README|Decisions]])
- PRD §16 says a milestone is done only when its gate passes in a playtest on PC **and a phone**. M0's gate passed in a PC Studio playtest. A phone check needs the place published and joined from a phone: does M0 need one?
- Export conventions are recorded in [[decisions/2026-11-22 Export fish as GLB modeled in studs]].
