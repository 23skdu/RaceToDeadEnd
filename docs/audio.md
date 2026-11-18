# Audio system

`scripts/autoload/AudioManager.gd` owns all procedural music/SFX synthesis,
playback, and the audio bus graph. It is a single autoload exposed as
`AudioManager`.

## Buses and mastering chain

The bus graph is created at boot by `_setup_audio_buses()`:

```text
Music ──────────────────────────────────────┐
                                            ├─> Master ─> output
SFX ──> [insert reverb] ──> Reverb ─────────┘
```

- **Master**: `AudioEffectEQ6` (gentle low/high lift, low-mid cut),
  `AudioEffectCompressor`, `AudioEffectLimiter`, and a very subtle
  `AudioEffectReverb`.
- **Reverb**: dedicated send/return bus with `AudioEffectReverb`; SFX sends to
  it and it returns to Master. The original SFX insert reverb is retained for
  continuity with existing behaviour.
- Per-bus volumes are restored from `SettingsManager.get_volume()` at boot.
  `set_bus_volume()` writes back through `SettingsManager.set_volume()` so
  volume changes persist in `user://settings.cfg`.

## 24-bit-resolution synthesis (roadmap item 6)

All procedural audio is **computed at 24-bit resolution** and then exported to
the best PCM format the running engine actually supports.

> **Engine limitation:** Godot 4.7.2's `AudioStreamWAV` does **not** expose a
> `FORMAT_24_BITS` constant. Its `Format` enum contains only `FORMAT_8_BITS`
> (`0`), `FORMAT_16_BITS` (`1`), `FORMAT_IMA_ADPCM` (`2`), and `FORMAT_QOA`
> (`3`). Referencing `AudioStreamWAV.FORMAT_24_BITS` is a parse error.

The implementation therefore:

- synthesizes samples into little-endian signed 24-bit PCM via
  `AudioManager.encode_s24()`;
- chooses the export format at runtime in `AudioManager.preferred_wav_format()`,
  which probes `ClassDB.class_get_enum_constants("AudioStreamWAV", "Format")`
  and prefers `FORMAT_16_BITS` (falling back to `FORMAT_8_BITS`), so the stored
  `AudioStreamWAV` is 16-bit on current engines;
- down-converts the s24 buffer to the chosen format in `_build_stream()`.

Public helpers:

| API | Description |
| --- | --- |
| `static has_native_24bit_wav() -> bool` | Reports whether the engine has a native 24-bit WAV format constant. |
| `static preferred_wav_format() -> int` | Best `AudioStreamWAV.Format` supported by this engine. |
| `static encode_s24(data, byte_offset, sample) -> void` | Writes a clamped little-endian s24 sample. |
| `static decode_s24(data, byte_offset) -> int` | Reads a signed s24 sample. |

`SAMPLE_RATE` remains `44100`.

## Randomized and polyphonic SFX (roadmap item 5)

- **Randomized**: laser, explosion, hurt, hit, and death sounds use
  `AudioStreamRandomizer` pools with `PLAYBACK_RANDOM_NO_REPEATS`, per-stream
  weights, `random_pitch`, and `random_volume_offset_db`. Hit/death pools mix
  all four enemy variants. Pools are created lazily and cached.
- **Polyphonic**: an `AudioStreamPlayer2D` with `AudioStreamPolyphonic`
  (`POLYPHONIC_VOICES = 48`) is always created. `play_sfx()` routes to it when
  the feature is enabled; if a voice cannot be allocated it falls back to the
  original 16-player 2D pool.
- `is_polyphonic_sfx_active() -> bool` reports whether polyphonic playback is
  both enabled and available.

## Adaptive layered music (roadmap item 4)

`get_adaptive_music_stream()` lazily builds an `AudioStreamInteractive` with
four clips (`Cruise`, `Chase`, `Overdrive`, `Boss`). Each clip is an
`AudioStreamSynchronized` of four looping stems (drums, bass, melody,
intensity). Clips differ by per-stem volume, so layers fade in as intensity
rises. Every clip pair has a `FADE_CROSS` transition at the next bar.

`set_music_intensity(boss_active, difficulty_tier, enemy_density)` selects a
clip:

- boss active → clip 3;
- otherwise `score = tier / 12 * 0.45 + density * 0.55`, with tier clamped to
  `[0, 20]` and density to `[0, 1]` (NaN/Inf → 0):
  - `score >= 0.68` → clip 2
  - `score >= 0.32` → clip 1
  - otherwise → clip 0

`get_adaptive_clip_index()` returns the last selected clip. Adaptive switching
is skipped when the feature is disabled, a custom playlist is active, or an
explicit non-`dynamic` music track is selected.

## Feature toggles

Flags are read via `SettingsManager.is_feature_enabled(key, default)` and live
under the `features` section of `user://settings.cfg`:

| Key | Default | Effect |
| --- | --- | --- |
| `polyphonic_sfx` | `false` | Use the 48-voice polyphonic SFX player. |
| `randomized_sfx` | `true` | Use randomized SFX pools. |
| `adaptive_music` | `true` | Allow `set_music_intensity()` to switch adaptive clips. |

## Public API added

- `has_native_24bit_wav()`
- `preferred_wav_format()`
- `encode_s24(data, byte_offset, sample)`
- `decode_s24(data, byte_offset)`
- `is_polyphonic_sfx_active()`
- `get_adaptive_music_stream()`
- `get_adaptive_clip_index()`
- `set_music_intensity(boss_active, difficulty_tier, enemy_density)`

## Known limitations

- 24-bit data is an internal synthesis resolution only; the engine cannot store
  it in `AudioStreamWAV`, so exported streams are 16-bit on Godot 4.7.2.
- `FORMAT_QOA` was not selected: compressed output would change the existing
  PCM-data assertions and is not required for this roadmap item.
- Adaptive clip transitions are defined at bar boundaries; WAV stems carry no
  BPM metadata, so the engine may begin a requested crossfade immediately if
  no beat grid is available.
- Polyphonic voices use the `SFX` bus via `play_stream()`'s bus argument; 2D
  panning is applied per player position, not per individual voice.
