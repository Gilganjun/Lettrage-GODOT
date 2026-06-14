# Phase 2B1 Source Map — Letter Drop (Group #13)

**Layout:** `Main2_heallthbartest`  
**Source:** `reference/GAME25.json` — event group index **13**, name **"Letter Drop"**  
**Scope:** Player-side letter/word gameplay only. **Enemy / Bullet / ShieldToggle branches excluded.**

---

## Active objects (group #13)

| GDevelop object | Godot Phase 2B1 |
|-----------------|-----------------|
| `Alphabet2` (L1–L26 sprites) | `scenes/letters/letter.tscn` + `AlphabetCatalog` |
| `Alphabet3vowels` (LV1–LV5) | Same letter scene, vowel tint `255;181;60` |
| `LetterDelBoundary` | Spawner `delete_y = 648` |
| `TopBoundary` | Spawner `spawn_y = -256` |
| `Spelling` / `SpellingShadow` | `WordGameHud` word label |
| `PlayerScore` text | HUD score label |
| `DeleteArrow` | **Backspace** (`delete_letter` action) — interpreted test binding |
| `LetterFlash` / `PopPoopFx` | Collection pop audio (+ glow deferred) |
| `Letter1` (TextObject Physics2) | **Not used** in active drop events — obsolete for this group |
| `Bullet` collision branches | **Excluded** (Enemy phase) |

Letter textures: `Images\Alphabet\{A-Z}.png` → `res://images/Alphabet/`

---

## Spawn timing

| Parameter | Source value | Godot |
|-----------|--------------|-------|
| `LetterTimer` reset interval | **0.30 s** (event `/62`: timer ≥ 0.30 → reset) | `LetterSpawner.spawn_interval = 0.3` |
| Sequence spawn trigger | timer ≤ **0.1**, `CurrentLetter` 1–26 | Every interval, cycle L1–L26 |
| Vowel spawn trigger | timer ≤ **0.2**, `CurrentVowel` 0–5 | `vowel_spawn_interval = 0.2`, A/E/I/O/U |
| Initial timer reset | Scene start `DepartScene` | Spawner starts on `_ready` |

---

## Spawn position and size

| Parameter | Source | Godot |
|-----------|--------|-------|
| X range | `RandomInRange(100, 2000)` | `spawn_x_min/max` |
| Y | `TopBoundary.Y()` → **-256** | `spawn_y = -256` |
| Size | `RandomInRange(25, 50)` | Scale from 25–50 px target |
| Consonant colour | Random RGB 128–255 | `AlphabetCatalog.random_modulate` |
| Vowel colour | Fixed `255;181;60` | `vowel_modulate` |

---

## Fall behaviour

Source uses **manual Y increment** each frame (event `/64`), **not** Physics2 simulation for L1/LV sprites:

| Object | Y delta / frame |
|--------|-----------------|
| `Alphabet2` | `RandomInRange(1, 3.5)` |
| `Alphabet3vowels` | `RandomInRange(1.5, 4)` |

Godot equivalent: **Area2D** constant fall **120–210 px/s** (≈ 2–3.5 px/frame @ 60 FPS).  
Letters **do not** collide with platforms — they pass over the playfield.

---

## Deletion boundary

| Item | Source | Godot |
|------|--------|-------|
| Object | `LetterDelBoundary` at y=**648**, w=2912 | `delete_y = 648` |
| Trigger | `CollisionNP` Alphabet2/LV × boundary | Y threshold cleanup |

---

## Simultaneous / word limits

| Variable | Behaviour |
|----------|-----------|
| `LLimit` | +1 on collection; when **≥ 20**, clear `SpellWord` and reset (event `/46`) |
| Active world letters | **No explicit cap in JSON** — Godot uses `max_active_letters = 30` safety cap |

---

## Collection

**Condition:** `CollisionNP` Player × L# / LV# (ShieldToggle = 0).  
**Excluded:** Bullet × letter (Enemy).

| Step | Source | Godot |
|------|--------|-------|
| Append | `SpellWord += "A "` (letter + space in source) | Append single uppercase char (display trimmed) |
| HUD | Set `Spelling` text | `WordGameHud` |
| SFX | `LetterCollectSFX` random 1–4 | `463388` / `463389` pop MP3 |
| FX | Create `LetterFlash` | Audio only in v1 |
| Remove letter | `Delete` L# / LV# | `Letter.queue_free()` once |

Collection order: **collision order / append sequence** (source uses per-letter event blocks 84–109).

---

## Delete letter

**Source:** Player collides `DeleteArrow` (falls like letters, event `/74–75`).  
**Phase 2B1 binding:** **Backspace** (`delete_letter`) — documented interpretation.

| Action | Source |
|--------|--------|
| Remove last char | `SubStr(SpellWord, 0, WordLength - 1)` |
| SFX | `176238__melissapons__sci-fi-short-error.wav` |
| Score | Unchanged |

---

## Word submission / validation

**Source submit key:** **C** (valid: event `/20`, invalid: event `/24`).  
**Godot:** `submit_word` = **Enter + C** (Enter documented as convenience alias).

### Dictionary lookup

```
StrFind(NewLine() + Dictionary + NewLine(), NewLine() + SpellWord + NewLine()) != -1
```

File: `EnglishWords4.txt` → `res://dictionary/EnglishWords4.txt`  
Godot: uppercase trim + hash set lookup.

### Valid word (key C, in dictionary, SpellWord not empty)

| Effect | Source |
|--------|--------|
| Score | `PlayerScore += (len/2) + len + len` (integer division on first term) |
| Example len=4 | +2 +4 +4 = **+10** |
| Clear word | `SpellWord = ""` |
| Reset LLimit | `LLimit = 0` |
| SFX | `487436__elijahdanie__game-win.mp3` vol 50–100 |
| FX | Glow on Spelling + Player (deferred in Godot v1) |

### Invalid word (key C, not in dictionary)

| Effect | Source |
|--------|--------|
| Score | **No change** |
| Word | **Retained** |
| FX | Shake Spelling 1 s |
| SFX | `369520__kinoton__bass-power-down.wav` vol 65 |

### Invalid word (key X, not in dictionary) — **out of v1 scope**

Clears word + `game-fx-hypnoshroom` — not wired in Phase 2B1 test.

---

## Scene / global variables (group #13)

| Variable | Role |
|----------|------|
| `SpellWord` | Current player word |
| `PlayerScore` | Numeric score |
| `PlayerLetterIndex` | Set on valid submit |
| `PlayerCollectedLetters` | Tracking string |
| `Dictionary` | Loaded EnglishWords4 content |
| `LLimit` | Letters collected toward 20-cap |
| `CurrentLetter` | 1–26 spawn sequence index |
| `CurrentVowel` | 0–5 vowel stream index |
| `LetterCollectSFX` | 1–4 pop variant |
| `ShieldToggle` | Shield mode — **excluded** from 2B1 |
| `LetterTimer` / `DeleteLetterTimer` | Spawn / delete-arrow timers |

---

## Collision layers (Godot)

| Layer | Bit | Name | Usage |
|-------|-----|------|-------|
| 1 | 1 | world | Platforms (unchanged Phase 2A) |
| 2 | 2 | ladder | Ladders |
| 3 | 4 | player | CharacterBody2D |
| 4 | 8 | letters | Letter Area2D (mask detects player) |

Letters: `collision_layer=8`, `collision_mask=4`. No world mask — no walkable letter surfaces.

---

## Ambiguities / deferred

| Item | Status |
|------|--------|
| DeleteArrow falling pickup vs key | **Backspace** used |
| Key X invalid-word clear | Not implemented in 2B1 |
| Spoken alphabet WAV on collect | Deferred (pop SFX only) |
| LetterFlash / PopPoopFx particles | Deferred |
| ShieldToggle collection branch | Excluded (Enemy/shield phase) |
| Bullet-assisted collection | Excluded |

---

## Phase 2B1 test scene

| Role | Path |
|------|------|
| **F5 main scene** | `scenes/test/phase2b1_word_game_test.tscn` |
| Phase 2A reference (unchanged) | `scenes/test/phase2a_movement_corrected.tscn` |
| Authoritative level | `scenes/levels/main2_heallthbartest_level.tscn` (**do not rebake**) |
