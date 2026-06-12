# Performance and Feature Improvement Plan - Next Steps

Status: PROPOSED (4 New Feature Improvements)

---

## 1. Advanced Customization Pack Visual Previews in Garage
**Effort: Moderate | Impact: Moderate | Category: Feature**

*   **Problem:** In the Garage UI (`Garage.gd`), discovered customization packs (music, skins, themes) are listed with simple "Enable / Disable" buttons. The player has no way to preview the custom player skin (such as the neon bunny design) or the theme's color palette before loading it into the game.
*   **Proposed Solution:** Add a preview panel to the Customize tab. Display a sprite preview of the player skin, dynamic colored swatches of the theme palette (highway lane/guardrail colors), and details about the music track list from the selected pack.
*   **Verification Plan:** Manually verify that selecting a pack displays its corresponding skin texture (including the neon bunny decals) and theme colors in the preview frame.

---

## 2. Encrypted Save Game System
**Effort: Low | Impact: High | Category: Feature (Security)**

*   **Problem:** `GameManager.gd` saves credits and upgrade progress to `user://save.dat` as a plaintext Dictionary check-summed with a simple hash function. Users can easily bypass the hash check or modify the save data, making progression exploits trivial.
*   **Proposed Solution:** Encrypt the save file using Godot's built-in `FileAccess.open_encrypted_with_pass` with a secure key. This protects player progression, upgrades, and bunny boss defeat records from manual tampering.
*   **Verification Plan:** Write a test checking that reading the save file without the correct key fails and fails gracefully on corrupted data.

---

## 3. Dynamic Rain Splashes and Road Reflection Effects
**Effort: Moderate | Impact: Moderate | Category: Feature (Visual Polish)**

*   **Problem:** During rainy and stormy weather, the rain droplets fall down the screen but have no interaction with the highway surface, making the environment feel static.
*   **Proposed Solution:** Implement micro-splash particles where rain hits the highway, and add a simple screen-space shader or modulating layer to simulate a wet road surface with glowing neon reflections from the synthwave sun, neon signs, and glowing bunny eyes in the background.
*   **Verification Plan:** Visual inspection during CLEAR -> LIGHT_RAIN -> ACID_RAIN weather transitions.

---

## 4. EMP Shockwave Screen-Space Distortion
**Effort: Moderate | Impact: Moderate | Category: Feature (Visual Polish)**

*   **Problem:** The EMP blast is functionally complete but visually underwhelming, lacking weight and feedback when activated.
*   **Proposed Solution:** Implement a screen-space shockwave distortion shader on the EMP node. The shader will warp the underlying pixels outwards in an expanding circle, matching the collision radius of the EMP, making it feel powerful as it hits nearby zombie bunnies and other enemy vehicles.
*   **Verification Plan:** Trigger the EMP blast and confirm that the screen-space distortion circle scales correctly in line with the shockwave.

---

## Summary Statistics (Target Metrics)

| Metric | Current | Target |
|--------|---------|--------|
| Target Test count | 698 | 705+ |
| Pass rate | 100% | 100% |
| Save file security | Plaintext | Encrypted |
