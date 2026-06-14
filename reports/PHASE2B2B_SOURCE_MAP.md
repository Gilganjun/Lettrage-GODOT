# Phase 2B2B Source Map — Shields + Enemy Word Collection

**Layouts:** `Main2_heallthbartest` (authoritative), `Main2_RedoAI_CharAnim` (reference only)  
**Source:** `SnatchWord1/GAME25.json`

---

## Group index correction

| Feature | JSON path | Notes |
|---------|-----------|-------|
| Player shield toggle | `events[2]` → `g/2/12` **Player SHIELD** | **Not** in group #13 |
| Shield letter break FX | `events[13]` → `g/13/79` | Pop ring + delete letter |
| Player word / collection | `events[13]` | `ShieldToggle=0` collects |
| Enemy word / shield / chase | `events[14]` **ENEMY AI** | Authoritative for 2B2B |
| RedoAI g/14 chase | `Main2_RedoAI_CharAnim` | **`AddForceVers` actions empty** — use heallthbartest |

---

## Player shield (`g/2/12`)

| Item | Source value | Godot |
|------|--------------|-------|
| Control | **LControl** (Once per press) | Input action `player_shield` → Left Ctrl |
| Mode | **Toggle** (not hold) | Press ON, press again OFF |
| State machine | `ShieldToggle` 0→1 activate, 1→2 deactivate→0 | `ShieldComponent.is_active` |
| Duration | **Indefinite** until second press | No auto expiry |
| Cooldown | **None** | — |
| Activate SFX | `ShieldUp1.mp3` ch4 vol25 pitch12 loop; hum ch14; trill ch15 | `ShieldComponent` streams |
| Deactivate SFX | `ShieldDown1.mp3` ch4 vol25 | On deactivate |
| Visual | Glow on Player; `ShieldFizz` + `FaceShield` particles | Temp: shield ring + sprite modulate |
| Movement | Unaffected | Shield is separate component |

### Shield inactive (`ShieldToggle=0`)
Normal letter collection via Player collector.

### Shield active (`ShieldToggle=1`)
- **No** append to `SpellWord`
- **No** spoken-letter WAV
- **No** collection score / LLimit
- Letter **deleted** on contact
- Pop FX: `PopPoopFx` + random pop MP3 vol50 (`463388` / `463389`)
- Shield **stays active** after break (no auto-down)

**Disabled:** auto-shield on jump (`g/2/7/16`, g/13 Jump-AUTOSHIELD), RControl branch.

---

## Enemy shield (`g/14`)

Dual use of `ShieldToggleEnemy`:

### A — Collection gate
| Condition | Action |
|-----------|--------|
| Letter in box around Enemy, **not** target (`Distance >= 20`) | `ShieldToggleEnemy = 1` |
| `Distance(Enemy, target Ln) < 100` | `ShieldToggleEnemy = 0` (Once) — allows collection |
| After collect | `Wait(0.3)` → `ShieldToggleEnemy = 1` |
| Collect | `CollisionNP` + `ShieldToggleEnemy = 0` + Once |

### B — Destroy while shielded
| Condition | Action |
|-----------|--------|
| DepartScene | Toggle bool → enemy **starts shielded** (glow on) |
| `ShieldToggleEnemy = 1` + collision Enemy × letter | **Delete** letter |
| SFX | `444136__lurpsis__glass-shatter-3.wav` ch7 pitch 5–14 vol 5–10 |

No timed duration; **0.3s re-shield** after successful target collect.

---

## Enemy target selection (`g/14` heallthbartest)

| Item | Source | Godot |
|------|--------|-------|
| Target word | `Choose::RandomString(EnemyDictionary)` at DepartScene | `EnemyWordState.pick_new_word()` |
| Dictionary file | `Dictionary/EnemyDictionary.txt` | `res://dictionary/EnemyDictionary.txt` |
| Current letter | `StrAt(EnemyWord, EnemyLetterIndex)` each frame | `EnemyWordState.current_needed_letter()` |
| Target object | **PickNearest** matching L1–L26 for current letter | Nearest active `Letter` with matching `character` |
| Proximity pre-check | `Distance < 200` → reset jump roll | Targeting range 200px |
| Movement | `AddForceVers(Enemy, Ln, 300)` | Chase direction via movement controller |
| Flip | Ln.X vs Enemy.X ±60 | Facing from chase |
| Jump toward letter | `EnemyJump = RandomInRange(1,4)`; jump if `=1` on floor | 25% hop when chasing |

**Not used:** 26 duplicate hardcoded branches — replaced by single nearest-match query.  
**RedoAI wander** (>250px nearest letter left/right) — **not** in heallthbartest; deferred.

---

## Enemy word state

| Variable | Role |
|----------|------|
| `EnemyWord` | Target string from dictionary |
| `EnemyLetterIndex` | 0-based; +1 per collect |
| `EnemyCollectedLetters` | Appended chars |
| `EnemyCurrentLetter` | Derived from word[index] |

On collect: delete letter, SFX `361334__spoonsandlessspoons__charge-up-shot.wav` vol30 pitch 10–20, index++, append.

**No spoken alphabet for Enemy** (source uses charge-up SFX only).

---

## Enemy word completion / validation

| Trigger | `EnemyCollectedLetters == EnemyWord` (automatic, Once) |
| Min length | Implicit from dictionary word |
| Dictionary re-check | **None** — letters collected in order from preset word |
| Invalid path | **None** |
| Valid outcome | Score + reset after Wait(2) + new random word |
| Score formula | `(len/2) + len + len` → `(len >> 1) + 2*len` |
| Player damage on complete | Present in g/12 — **out of scope 2B2B** |

---

## Letter resolution (Godot architecture)

Single `Letter.resolve(outcome, source)` — outcomes:

| Outcome | Effect |
|---------|--------|
| `PLAYER_COLLECT` | Player word append + pop/spoken audio |
| `ENEMY_COLLECT` | Enemy word append + charge SFX |
| `PLAYER_SHIELD` | Pop SFX, no word change |
| `ENEMY_SHIELD` | Glass shatter SFX, no word change |
| `BOUNDARY` | Silent delete |

After resolve begins: ignore all further contacts.

---

## Collision layers (Godot)

| Layer | Name | Users |
|-------|------|-------|
| 1 | world | Level |
| 2 | ladder | Ladders |
| 3 | player | Player body |
| 4 | letters | Letter Area2D |
| 5 | enemy | Enemy body |
| 6 | player_shield | Player shield area |
| 7 | enemy_collector | Enemy collection area |
| 8 | enemy_shield | Enemy shield area |

Player collector: mask letters only. Shield areas: mask letters. Enemy body: does **not** collect.

---

## Disabled / obsolete (g/14)

Target-X patrol, ladder jump dup, raycast letter delete, Platform3 auto-jump, 3× word tween variants — all **disabled** in JSON.

---

## Ambiguities

1. Enemy starts shielded via scene-start toggle — implemented as `start_active = true`.
2. `ShieldToggle` typed string in JSON — compare as 0/1/2.
3. Score event vs string-equality — both fire at completion; Godot scores once on equality.
4. RedoAI g/14 missing chase forces — **heallthbartest only** for movement.

---

## Godot file map

| System | Files |
|--------|-------|
| Shared shield | `scripts/components/shield_component.gd`, `scenes/components/shield_component.tscn` |
| Letter resolution | `scripts/letters/letter.gd` |
| Player shield input | `player_shield.gd` → wraps component |
| Enemy shield AI | `scripts/enemy/enemy_shield_controller.gd` |
| Enemy word | `scripts/enemy/enemy_word_state.gd`, `enemy_word_controller.gd` |
| Enemy targeting | `scripts/enemy/enemy_letter_targeting.gd` |
| Enemy collection | `scripts/enemy/enemy_letter_collector.gd` |
| Test scene | `scenes/test/phase2b2b_shield_word_test.tscn` |
