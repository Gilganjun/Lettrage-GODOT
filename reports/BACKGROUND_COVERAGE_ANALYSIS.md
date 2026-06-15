# Background Coverage Analysis

**Date:** 2026-06-13  
**Task:** Document white areas at level edges — analysis only (no visual changes in stabilization pass).

## Summary

White (empty) regions at level edges are caused by **camera limits extending beyond background sprite coverage**, exposing the **default viewport clear color**. This is not missing platform collision or a stretch-mode bug.

## Background sprites

Both layers live under `Backgrounds/` in `main2_heallthbartest_level.tscn`:

| Node | Texture | Position | Scale | z_index |
|------|---------|----------|-------|---------|
| `BG1_001` | `out_18.jpg` | (-136, -214) | (1.15625, 0.6666667) | -2 |
| `BG2_001` | `out_18_3.png` | (-136, -214) | (1.15625, 0.6666667) | -1 |

GDevelop manifest (`layout_manifest.json`) lists each BG at **2664×1024** displayed pixels:

| Axis | BG coverage (world px) |
|------|------------------------|
| X | **-136** → **2528** (-136 + 2664) |
| Y | **-214** → **810** (-214 + 1024) |

Sprites use `centered = false`, so the position is the top-left corner.

## Camera limits

From `scenes/player/player.tscn` → `Camera2D`:

| Limit | Value |
|-------|-------|
| left | 0 |
| top | **-256** |
| right | **2272** |
| bottom | **766** |

| Setting | Value |
|---------|-------|
| zoom | 1.0 |
| viewport | 960×540 (`project.godot`) |
| stretch | `canvas_items` (16:9 window override 1280×720 — no letterboxing) |

With zoom 1.0, half-viewport is **480×270**. Camera center is clamped so the view stays inside limits.

### Visible world at camera extremes

| Edge | Camera center (approx.) | Visible range |
|------|-------------------------|---------------|
| Left | x = 480 | x **0** → 960 |
| Right | x = 1792 | x **1312** → **2272** |
| Top | y = 14 | y **-256** → -16 |
| Bottom | y = 496 | y **226** → **766** |

## Uncovered regions (root cause)

| Region | Camera shows | BG covers | Gap |
|--------|--------------|-----------|-----|
| **Top** | y from **-256** | y from **-214** | **~42 px** above BG — clear color visible |
| Right | up to x **2272** | up to x **2528** | BG extends past camera — **no gap** |
| Left | from x **0** | from x **-136** | BG extends past camera — **no gap** |
| **Bottom** | y up to **766** | y up to **810** | BG extends past camera — **no gap** |

The primary user-visible white band is the **top strip** when the camera reaches `limit_top = -256`.

Horizontal white at the right edge can still appear if:

1. The imported texture renders slightly smaller than the manifest 2664 px width after Godot scale, or
2. The player camera follows into platform areas where vertical framing shifts and the top gap becomes more noticeable.

Enemy physics probe (`validate_phase2b2a`) reached **x ≈ 2040**, within both platform collision and BG horizontal coverage.

## Ruled out

| Hypothesis | Verdict |
|------------|---------|
| Missing background sprites | **No** — both BG layers present |
| Viewport stretch letterboxing | **Unlikely** — 960×540 and 1280×720 are both 16:9 |
| Platform collision regression | **Unrelated** — separate from background fill |
| Rebake overwriting BG | **Not run** in this pass |

## Recommended fix (later — not Phase 2B2B stabilization)

Combination approach:

1. **Tighter camera `limit_top`** — set to **-214** (or -220 with small margin) to match BG top.
2. **Optional BG extension** — duplicate or tile `out_18` layers if wider horizontal coverage is needed after limit changes.
3. **Clear-color fallback** — set `Rendering > Environment > Default Clear Color` to a sky-tone matching BG edge pixels (cosmetic only).
4. **Do not** stretch backgrounds automatically without matching GDevelop art intent.

## Files referenced

- `scenes/levels/main2_heallthbartest_level.tscn`
- `scenes/player/player.tscn`
- `resources/phase2a/layout_manifest.json`
- `project.godot` (display / stretch)
