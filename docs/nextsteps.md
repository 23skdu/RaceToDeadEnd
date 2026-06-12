# Performance & Feature Improvement Plan - Next Steps

Status: PROPOSED (10 New Performance and Feature Improvements)

---

## 1. Weather System GPUParticles2D Optimization
**Effort: Low | Impact: High | Category: Performance**

*   **Problem:** In `WeatherSystem.gd`, weather transitions dynamically scale the rain particle density by modifying `_rain_particles.amount` (e.g., `_rain_particles.amount = int(Constants.RAIN_DROP_COUNT * 0.5 * weather_intensity)`). In Godot 4, changing the `amount` property of a GPUParticles2D node at runtime triggers a GPU buffer reallocation, causing a noticeable micro-stutter/frame drop.
*   **Proposed Solution:** Initialize the particle system once with a constant `amount = Constants.RAIN_DROP_COUNT`. Control rain density and visibility during transitions by dynamically adjusting the process material's alpha/color, or the particle emitter's `speed_scale` and lifetime parameters. This keeps the GPU memory layout stable and eliminates reallocation spikes.
*   **Verification Plan:** Run profiling on weather transitions; verify particle count remains stable in GPUMonitor, and check that frame times stay consistent.

---

## 2. Static Parallax Background Generation & Caching
**Effort: Low | Impact: High | Category: Performance**

*   **Problem:** The cyberpunk synthwave background layers are generated procedurally on startup/restart in `Game.gd` (`_setup_parallax()`). Generating 4 layers pixel-by-pixel (up to 512x384 each) in GDScript loops utilizing complex math (`sin`, `sqrt`, `fmod`, `Color.lerp`) blocks the main thread, leading to a prominent 0.5s–1.0s freeze when reloading the scene on restart/death.
*   **Proposed Solution:** Introduce a static dictionary to cache the generated `ImageTexture` objects. Generate them once on the first run, and on subsequent scene reloads, directly retrieve the cached textures instead of regenerating them.
*   **Verification Plan:** Profile the restart sequence. Verify that reload times drop under 100ms and the parallax textures remain identical.

---

## 3. Homing Bullet Target Stickiness & Throttling
**Effort: Low | Impact: Moderate | Category: Performance**

*   **Problem:** Homing bullets in `Bullet.gd` query the nearest target from the global enemy list inside `_physics_process(delta)` on every physics frame. When there are many bullets and enemies on screen, this results in significant distance-squared math operations every frame.
*   **Proposed Solution:** Implement "target stickiness." Let the bullet lock onto a single target node and follow it. Only re-evaluate or scan for a closer target every `Constants.ENEMY_CACHE_INTERVAL` (0.25 seconds) or when the current locked target dies/exits the screen, reducing distance calculations by over 90%.
*   **Verification Plan:** Create a unit test `test_bullet_homing_target_stickiness` to verify target locking behavior and scan throttling.

---

## 4. MultiMeshInstance2D for Obstacles and Decor
**Effort: Moderate | Impact: Moderate | Category: Performance**

*   **Problem:** In `Highway.gd`, static obstacles (barrels, rocks) and desert decor (cacti, skulls, rusted cars) are instantiated as individual nodes (`Polygon2D`, `Line2D`, `StaticBody2D`) for each highway chunk. When chunks are generated or recycled, instantiating/freeing dozens of nodes creates scene-tree modification overhead and increases draw calls.
*   **Proposed Solution:** Consolidate the visuals of static obstacles and decor into `MultiMeshInstance2D` nodes per chunk type, just like lanes and shoulders. Maintain simple pooled collision objects (`StaticBody2D` with simple circle/rect shape) separate from the complex drawing nodes.
*   **Verification Plan:** Verify chunk instantiation time and draw call counts in the Godot debugger.

---

## 5. Threaded Procedural Audio Synth Generation
**Effort: Moderate | Impact: High | Category: Performance**

*   **Problem:** `AudioManager.gd` builds 16-bit procedural WAV streams (especially the 16-second looping background music tracks) using `_build_16bit_stream()`. Executing GDScript math functions (`sin`, `fmod`, `lerpf`) 350,000+ times sequentially blocks the main thread, causing startup lag.
*   **Proposed Solution:** Move the procedural generation loops onto background threads using Godot's `WorkerThreadPool`. Generate the next required music track asynchronously in the background so it is ready before the level/boss phase transitions, completely eliminating the audio-related main thread freeze.
*   **Verification Plan:** Measure frame time during background music changes; ensure zero frame-rate stutter on track transitions.

---

## 6. ObjectPool Dynamic Expansion Throttling
**Effort: Low | Impact: Moderate | Category: Performance**

*   **Problem:** If the pre-warmed pool in `ObjectPool.gd` is exhausted during high-action gameplay (e.g. boss minion waves), fallback objects are instantiated on the spot. This causes sudden spike stutters as multiple scenes are loaded/instantiated in a single frame.
*   **Proposed Solution:** Pre-allocate fallback objects progressively over multiple frames when the pool capacity drops below a critical threshold (e.g. 20% left), rather than instantiating them on-demand when `acquire()` is called.
*   **Verification Plan:** Mock pool exhaustion and verify that the frame time does not spike during fallback instantiations.

---

## 7. Advanced Customization Pack Visual Previews in Garage
**Effort: Moderate | Impact: Moderate | Category: Feature**

*   **Problem:** In the Garage UI (`Garage.gd`), discovered customization packs (music, skins, themes) are listed with simple "Enable / Disable" buttons. The player has no way to preview the custom player skin or the theme's color palette before loading it into the game.
*   **Proposed Solution:** Add a preview panel to the Customize tab. Display a sprite preview of the player skin, dynamic colored swatches of the theme palette (highway lane/guardrail colors), and details about the music track list from the selected pack.
*   **Verification Plan:** Manually verify that selecting a pack displays its corresponding skin texture and theme colors in the preview frame.

---

## 8. Encrypted Save Game System
**Effort: Low | Impact: High | Category: Feature (Security)**

*   **Problem:** `GameManager.gd` saves credits and upgrade progress to `user://save.dat` as a plaintext Dictionary check-summed with a simple hash function. Users can easily bypass the hash check or modify the save data, making progression exploits trivial.
*   **Proposed Solution:** Encrypt the save file using Godot's built-in `FileAccess.open_encrypted_with_pass` with a secure key. This prevents players from manually tempering with high scores or credit values.
*   **Verification Plan:** Write a test checking that reading the save file without the correct key fails and fails gracefully on corrupted data.

---

## 9. Dynamic Rain Splashes & Road Reflection Effects
**Effort: Moderate | Impact: Moderate | Category: Feature (Visual Polish)**

*   **Problem:** During rainy and stormy weather, the rain droplets fall down the screen but have no interaction with the highway surface, making the environment feel static.
*   **Proposed Solution:** Implement micro-splash particles where rain hits the highway, and add a simple screen-space shader or modulating layer to simulate a wet road surface with glowing neon reflections from the synthwave sun and background lights.
*   **Verification Plan:** Visual inspection during CLEAR -> LIGHT_RAIN -> ACID_RAIN weather transitions.

---

## 10. EMP Shockwave Screen-Space Distortion
**Effort: Moderate | Impact: Moderate | Category: Feature (Visual Polish)**

*   **Problem:** The EMP blast is functionally complete but visually underwhelming, lacking weight and feedback when activated.
*   **Proposed Solution:** Implement a screen-space shockwave distortion shader on the EMP node. The shader will warp the underlying pixels outwards in an expanding circle, matching the collision radius of the EMP, making it feel powerful.
*   **Verification Plan:** Trigger the EMP blast and confirm that the screen-space distortion circle scales correctly in line with the shockwave.

---

## Summary Statistics (Target Metrics)

| Metric | Current | Target |
|--------|---------|--------|
| Target Test count | 324 | 335+ |
| Pass rate | 100% | 100% |
| Scene reload time (Restart) | ~800ms | <100ms |
| Homing calculation overhead | High | Low |
| Save file security | Plaintext | Encrypted |
| Draw call count (Debris Chunk) | High (~30) | Low (~5) |
