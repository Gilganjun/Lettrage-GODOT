# Lettrage Asset Studio v1.0

## Stored here for reference

This tool lives at `Tools/LettrageAssetStudio/` inside the Lettrage repo so it stays easy to find alongside the game project.

## NOT integrated into Godot

This is a **separate Python desktop application**. It is not part of the Godot game:

- Does **not** modify `project.godot`, scenes, scripts, or Godot assets
- Does **not** run inside or require the Godot editor
- Only writes files when **you** run an operation (e.g. Export copies PNGs to `Assets/Characters/`)

Create a Desktop shortcut to `LettrageAssetStudio.py` (or a built EXE) for quick launch.

## Run

```bash
cd Tools/LettrageAssetStudio
python LettrageAssetStudio.py
```

When stored in this folder, the Export tab auto-detects the parent Lettrage Godot project. You can change it via **Export → Link Lettrage Project…**

## Build EXE

```bash
pip install pyinstaller
pyinstaller --onefile --windowed LettrageAssetStudio.py
```

The EXE can live here, on the Desktop, or anywhere — it never becomes part of the Godot project.

## Tabs

1. **Video Extract** — MP4 to PNG frames
2. **Green2Alpha** — Green-screen removal
3. **Resize** — Batch resize images
4. **Animation Tester** — Preview and clean up frame sequences
5. **Auto-Font Cutter** — Split A–Z grid sheets into letter PNGs
6. **Export** — Copy finished frames to `Assets/Characters/<Name>/<AnimationType>/`

## Output folders

Green2Alpha and Resize save into `Outputs/` inside this app folder:

```
Outputs/
  Preset_Pipeline_YYYYMMDD_HHMM/
    1_extract/
    2_green2alpha/
    3_final/          ← preset pipeline ends here; Animation Tester opens this
  Green2Alpha_Output_YYYYMMDD_HHMM/
  Shrink_Output_YYYYMMDD_HHMM/
  AnimationTester_Output_YYYYMMDD_HHMM/
```

Use **Run Preset Pipeline** on the Video Extract tab to chain extract → green screen → shrink in one step.

## Auto-Font Cutter

Import a generated A–Z alphabet grid (transparent or green-screen) and export 26 letter PNGs plus `metadata.json`.

Default grid: **7×4** (A–G, H–N, O–U, V–Z, last two cells empty).  
Default export size: **512×512** transparent PNG per letter.

Export destination: `assets/fonts/<FontName>/` in your Lettrage Godot project (auto-created).

Video Extract (manual mode) still saves next to the source MP4 as `<video_name>_frames/`.
