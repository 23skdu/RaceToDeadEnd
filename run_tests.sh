#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GODOT="${GODOT:-godot}"

run_batch() {
    local label="$1"
    local tests="$2"
    echo "=== BATCH $label ==="
    if ! "$GODOT" --headless -s "$SCRIPT_DIR/addons/gut/gut_cmdln.gd" \
        -gtest="$tests" -gexit -glog=3; then
        echo "FAILED: $label"
        return 1
    fi
}

FIRST="res://scripts/test/unit/test_audio_manager.gd,res://scripts/test/unit/test_bullet.gd,res://scripts/test/unit/test_constants.gd,res://scripts/test/unit/test_drone.gd,res://scripts/test/unit/test_drone_bomb.gd,res://scripts/test/unit/test_emp.gd,res://scripts/test/unit/test_enemy.gd,res://scripts/test/unit/test_game.gd,res://scripts/test/unit/test_game_manager.gd,res://scripts/test/unit/test_game_over.gd,res://scripts/test/unit/test_garage.gd,res://scripts/test/unit/test_highway.gd,res://scripts/test/unit/test_hud.gd,res://scripts/test/unit/test_interceptor.gd,res://scripts/test/unit/test_main.gd,res://scripts/test/unit/test_mine.gd,res://scripts/test/unit/test_object_pool.gd,res://scripts/test/unit/test_options.gd"

SECOND="res://scripts/test/unit/test_pack_manager.gd,res://scripts/test/unit/test_player_sprite.gd,res://scripts/test/unit/test_rotor.gd,res://scripts/test/unit/test_scav.gd,res://scripts/test/unit/test_score_manager.gd,res://scripts/test/unit/test_spawner.gd,res://scripts/test/unit/test_sprites.gd,res://scripts/test/unit/test_weather_system.gd"

run_batch "1/2 (1-18)" "$FIRST"
run_batch "2/2 (19-26)" "$SECOND"

echo ""
echo "=========================================="
echo "  ALL TESTS PASSED (26 files, 2 batches)  "
echo "=========================================="
