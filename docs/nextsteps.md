# Race to Dead End — Implementation Plan

## Engine: Godot 4.4+

**Why Godot?** MIT-licensed open source, excellent 2D isometric support via TileMapLayers, built-in physics (or Jolt integration), GDScript for fast prototyping, strong community, cross-platform export (Windows, Linux, macOS, web, mobile). No royalties or licensing fees.

---

## Phase 0: Prototype Stabilization & LSP Resolutions (COMPLETED)

We conducted a deep static analysis of the prototype codebase and resolved several critical LSP errors, compiler failures, and gameplay bugs that blocked building and execution.

---

## Phases 1–7 (All COMPLETED)

All previous phases (Parts 11-90) have been implemented. See archived documentation for details.

---

## Phase 8: Deep Codebase Audit — 10 Bugfix & Performance Suggestions (COMPLETED)

All 10 parts (S91-S100) implemented and tested:
- Mine proximity detonation, Garage variable capture fix, Highway clone leak, InputRemap joystick axis, DroneBomb warning visual, EMP stun refresh, Civilian player group lookup, Bullet pool contamination (already fixed), Main controls label duplication, Highway weight formula

---

## Phase 9: Deep Codebase Audit — 10 New Improvement Suggestions (New)

10 additional issues identified via systematic codebase-wide analysis of all 40 active scripts. Focus: data loss bugs (save/load), pool lifecycle correctness, visual feedback gaps, code quality/consistency, and performance overhead.

### Suggestion 101: InputRemap JoypadMotion Axis Value Lost on Save/Load

**Problem:** `InputRemap._serialize_event()` for `InputEventJoypadMotion` saves only the axis index as `"jaxis:AXIS"`, discarding `axis_value` (direction: -1.0 or 1.0). On deserialize in `_deserialize_event()`, `axis_value` is hardcoded to 1.0. This means analog stick left vs right become indistinguishable after save/load. Left-stick-left bound to `move_left` becomes left-stick-right with value 1.0, effectively breaking the binding.

**Current code:**
```gdscript
if event is InputEventJoypadMotion:
    return "jaxis:" + str(event.axis)
```

**Fix:**
1. Change serialization format to `"jaxis:AXIS:VALUE"` where VALUE is `event.axis_value` (e.g., `"jaxis:0:-1.0"`).
2. Update `_deserialize_event()` to parse the 3-part format and set `axis_value` accordingly.
3. Maintain backward compatibility with old `"jaxis:AXIS"` format (treat as axis_value = 1.0).

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 102: ObjectPool Pickup Fallback Causes Unbounded Pool Growth

**Problem:** `ObjectPool.acquire_pickup()` fallback path calls `fallback.set_meta("_pool_name", "pickup")` on the fallback instance. When `ObjectPool.release()` is called on this fallback, it checks `_pool_name` meta and returns the instance to the pool, growing the pool by one. Over a long game with many pickups, the `"pickup"` pool grows unboundedly. The non-pickup `acquire()` fallback was fixed in S82 (removed `_pool_name` setting) but the pickup variant was missed.

**Current code:** Fallback in `acquire_pickup()` sets `_pool_name` meta.
```gdscript
var fallback = _create_pickup_node()
fallback.set_meta("_pool_name", "pickup")
```

**Fix:**
1. Remove `fallback.set_meta("_pool_name", "pickup")` from the fallback path in `acquire_pickup()`.
2. Fallback pickups will not have `_pool_name`, so `release()` will call `queue_free()` — same behavior as non-pickup fallbacks.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 103: Highway Guardrail Colors Not Centralized in Constants

**Problem:** `Highway._build_tiles_into()` hardcodes guardrail colors: `Color(1.0, 1.0, 0.8)` for standard/debris/ice/construction chunks and `Color(0.0, 0.8, 1.0)` for bridge chunks. These should be centralized in `Constants.gd` for consistency and themability.

**Current code:**
```gdscript
left_rail.default_color = Color(1.0, 1.0, 0.8) if chunk_type != ChunkType.BRIDGE else Color(0.0, 0.8, 1.0)
```

**Fix:**
1. Add `GUARDRAIL_COLOR = Color(1.0, 1.0, 0.8)` and `BRIDGE_GUARDRAIL_COLOR = Color(0.0, 0.8, 1.0)` to `Constants.gd`.
2. Update `Highway.gd` to reference these constants.

**Effort:** Low — **Impact:** Low — **Priority:** P3

---

### Suggestion 104: HUD Boost Active Visual Indicator

**Problem:** The HUD shows boost charge count (number of boosts available) via `boost_indicators` but provides no visual feedback when boost is actively running. The player must check the boost charge count changing (which only happens when boost runs out or recharges) to know boost is active. The Interceptor emits `boost_activated` and `boost_depleted` signals, but the HUD never connects to them.

**Current code:** HUD connects only to `boost_charge_updated` which fires on charge changes (start and end of boost), but doesn't distinguish "boost is active" from "boost is charging."

**Fix:**
1. Connect `boost_activated` and `boost_depleted` signals from the player in HUD.
2. Store `_boost_active: bool` in HUD.
3. While boost is active, pulse the first visible boost indicator with a color cycling effect (orange -> white cycle).
4. Restore normal appearance when boost depletes.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 105: Options.load_bindings Called Twice Redundantly

**Problem:** `Options.gd` calls `input_remap.load_bindings()` twice — once unconditionally in `_ready()` and once after awaiting `input_remap.ready`. Since `load_bindings()` is idempotent (it calls `InputMap.action_erase_events` before re-adding), this is not a bug but it's redundant. On systems where `is_inside_tree()` is false initially (due to scene tree ordering), the first call may operate on an InputRemap that hasn't finished its own `_ready()`, potentially loading bindings before the action list is built.

**Current code:**
```gdscript
input_remap.load_bindings()  # First call - unconditional
if not input_remap.is_inside_tree():
    await input_remap.ready
input_remap.load_bindings()  # Second call - after ready
```

**Fix:**
1. Remove the first unconditional `load_bindings()` call.
2. Keep only the guarded call that awaits `ready` if needed.
3. Since `_ready()` already guarantees tree membership, the await is never actually needed in practice.

**Effort:** Low — **Impact:** Low — **Priority:** P3

---

### Suggestion 106: AudioManager play_sfx Doesn't Skip When All Players Have Higher Priority

**Problem:** `AudioManager.play_sfx()` searches for a free SFX player. When all 16 players are busy, it selects the one with the lowest priority and preempts it — even if the incoming sound has lower priority than ALL currently playing sounds. This means a low-priority sound (e.g., background engine hum) can preempt a high-priority sound (e.g., explosion).

**Current code:** Always selects a player (preempts lowest priority) when all are busy, regardless of the incoming priority:
```gdscript
if best_idx == -1:
    best_idx = 0
```

**Fix:**
1. Track whether a free player was found separate from the low-priority fallback.
2. If no free player exists AND the incoming priority is lower or equal to the lowest busy priority, skip playback entirely.
3. Only preempt if the incoming priority is strictly higher than the lowest busy priority.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 107: EMPBlast Collision Shape Radius Not Reset on Pool Reuse

**Problem:** When `EMPBlast` reaches max radius (400.0) and is released to the ObjectPool, `_col_shape.shape.radius` remains at 400.0. On pool re-acquire, `init()` sets `current_radius = 0.0` but does NOT reset the collision shape radius. The first frame of `_process()` runs `_update_collision_radius()` which sets the shape radius to the updated `current_radius`. But for 1 frame, the collision shape retains the previous max radius (400.0), making the EMP instantly detect overlapping bodies at full range.

**Current code:** `init()` zeroes `current_radius` but doesn't touch the shape:
```gdscript
func init(pos: Vector2) -> void:
    global_position = pos
    _pooled = has_meta("_pool_name")
    current_radius = 0.0
    _stunned_bodies.clear()
```

**Fix:**
1. In `init()`, also reset the collision shape radius: `if _col_shape and _col_shape.shape is CircleShape2D: _col_shape.shape.radius = 0.0`.
2. This eliminates the 1-frame window where the shape reports max range.

**Effort:** Low — **Impact:** Low — **Priority:** P3

---

### Suggestion 108: WeatherSystem Redundant Local Const Declarations

**Problem:** `WeatherSystem.gd` re-declares `const RAIN_DROP_COUNT`, `const LIGHTNING_DAMAGE`, etc. locally that duplicate the values in `Constants.gd`. These local constants can drift from the `Constants.gd` definitions. Scripts should reference `Constants.*` directly to ensure consistency.

**Current code:**
```gdscript
const RAIN_DROP_COUNT: int = Constants.RAIN_DROP_COUNT
const LIGHTNING_DAMAGE: int = Constants.LIGHTNING_DAMAGE
...
```

**Fix:**
1. Remove all local const declarations that simply mirror `Constants.*`.
2. Replace all local references with `Constants.*` equivalents.
3. The only local consts to keep are those that are truly local (computed or unique to the script).

**Effort:** Low — **Impact:** Low — **Priority:** P3

---

### Suggestion 109: Spawner wave_timer Not Properly Initialized on Game Start

**Problem:** `Spawner.wave_timer` starts at 0.0 and is never explicitly set on game start. When `GameManager.state` becomes `PLAYING` (via `GameManager.start_game()` called in `Game._ready()`), the first `_process()` call finds `wave_timer <= 0.0` and immediately triggers wave 1 — the first enemies appear on frame 1. The intended behavior is a proper 5-second delay before the first wave.

**Current code:** No connection to game_started signal, wave_timer starts at 0.0.

**Fix:**
1. Connect to `GameManager.game_started` signal in `_ready()`.
2. In the handler, set `wave_timer = wave_interval` to give a proper delay before the first wave.
3. Reset `current_wave = 0` and `_bosses_spawned = 0` on game start.

**Effort:** Low — **Impact:** Medium — **Priority:** P2

---

### Suggestion 110: Civilian Sprite Texture Regeneration Overhead on Pool Acquire

**Problem:** `Civilian.on_pool_acquire()` calls `_generate_sprite_texture()` which creates a new `Image` (8×16 = 128 pixels), fills it pixel by pixel via a double loop, and creates a new `ImageTexture`. This is a small allocation (~512 bytes per image) but happens every pool acquire (~4 times per civilian lifecycle). The texture is identical every time since colors are constant. The same work is also done in `_ready()`, making `on_pool_acquire()` redundant for the texture.

**Current code:**
```gdscript
func on_pool_acquire() -> void:
    _generate_sprite_texture()  # Redundant - generates identical texture every time
    _protect_bonus_awarded = false
    _player = null
    velocity = Vector2.ZERO
    visible = true
    process_mode = Node.PROCESS_MODE_INHERIT
```

**Fix:**
1. Remove `_generate_sprite_texture()` from `on_pool_acquire()`.
2. The texture is already generated in `_ready()`, which runs once when the Civilian scene is first instantiated. Pool lifecycle does not destroy the node, so the texture persists.
3. Keep `_generate_sprite_texture()` call in `_ready()` and remove from `on_pool_acquire()`.

**Effort:** Low — **Impact:** Low — **Priority:** P3

---

## Priority Matrix (Phase 9)

| Suggestion | Title | Effort | Impact | Priority |
|------------|-------|--------|--------|----------|
| 101 | InputRemap JoypadMotion Axis Value Lost | Low | Medium | P2 |
| 102 | ObjectPool Pickup Fallback Pool Growth | Low | Medium | P2 |
| 104 | HUD Boost Active Visual Indicator | Low | Medium | P2 |
| 106 | AudioManager play_sfx Priority Skip | Low | Medium | P2 |
| 109 | Spawner wave_timer Not Initialized on Start | Low | Medium | P2 |
| 103 | Highway Guardrail Colors Not Centralized | Low | Low | P3 |
| 105 | Options.load_bindings Redundant Call | Low | Low | P3 |
| 107 | EMPBlast Shape Radius Not Reset | Low | Low | P3 |
| 108 | WeatherSystem Redundant Const Declarations | Low | Low | P3 |
| 110 | Civilian Sprite Texture Regeneration | Low | Low | P3 |

**Previously deferred (unchanged):** Part 22 (TileMapLayer Highway, P3), Part 35 (class_name EnemyBase, P3), Part 40 (Integration Tests, P1).
