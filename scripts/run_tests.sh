#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
GODOT="${GODOT:-godot}"

run_batch() {
    local label="$1"
    local tests="$2"
    echo "=== BATCH $label ==="
    if ! "$GODOT" --headless -s "$ROOT_DIR/addons/gut/gut_cmdln.gd" \
        -gtest="$tests" -gexit -glog=3; then
        echo "FAILED: $label"
        return 1
    fi
}

FIRST="res://tests/unit/test_audio_manager.gd,res://tests/unit/test_bosses.gd,res://tests/unit/test_boss_war_rig.gd,res://tests/unit/test_bullet.gd,res://tests/unit/test_camera_shake.gd,res://tests/unit/test_civilian.gd,res://tests/unit/test_constants.gd,res://tests/unit/test_constants_extended.gd,res://tests/unit/test_drone.gd,res://tests/unit/test_drone_bomb.gd,res://tests/unit/test_emp.gd,res://tests/unit/test_enemy.gd,res://tests/unit/test_game.gd,res://tests/unit/test_game_manager.gd,res://tests/unit/test_game_over.gd,res://tests/unit/test_garage.gd,res://tests/unit/test_helpers.gd,res://tests/unit/test_highway.gd,res://tests/unit/test_hud.gd,res://tests/unit/test_input_remap.gd,res://tests/unit/test_interceptor.gd"

SECOND="res://tests/unit/test_main.gd,res://tests/unit/test_mine.gd,res://tests/unit/test_object_pool.gd,res://tests/unit/test_options.gd,res://tests/unit/test_pack_manager.gd,res://tests/unit/test_pause_menu.gd,res://tests/unit/test_player_sprite.gd,res://tests/unit/test_rotor.gd,res://tests/unit/test_scav.gd,res://tests/unit/test_score_manager.gd,res://tests/unit/test_settings_manager.gd,res://tests/unit/test_spawner.gd,res://tests/unit/test_sprites.gd,res://tests/unit/test_transition_layer.gd,res://tests/unit/test_weather_system.gd"

run_batch "1/2 (20 files)" "$FIRST"
run_batch "2/2 (15 files)" "$SECOND"

echo ""
echo "==========================================="
echo "  ALL TESTS PASSED (35 files, 2 batches)  "
echo "==========================================="
