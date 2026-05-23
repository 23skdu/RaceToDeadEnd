class_name TestHelper
extends Node

## Ensures audio buses exist for GUT tests (project.godot buses may not load fully)
static func ensure_audio_buses() -> void:
	var expected_buses = ["Master", "Music", "SFX"]
	for i in expected_buses.size():
		var bus_name = expected_buses[i]
		if AudioServer.get_bus_count() <= i or AudioServer.get_bus_name(i) != bus_name:
			if AudioServer.get_bus_count() <= i:
				AudioServer.add_bus()
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_volume_db(i, 0.0)
			AudioServer.set_bus_mute(i, false)

## Instantiates a scene from .tscn path, ensuring @onready variables work
static func instantiate_scene(scene_path: String) -> Node:
	if ResourceLoader.exists(scene_path):
		var scene = load(scene_path)
		return scene.instantiate()
	return null

## Creates a mock Interceptor player for tests that need a player reference
static func create_mock_player() -> Node2D:
	var player = Node2D.new()
	player.set("current_lane", 1)
	player.set("take_damage", func(amount = 1): pass)
	return player

## Sets up a minimal GameManager for tests (don't use when autoload is available)
static func create_game_manager() -> Node:
	var gm = load("res://scripts/autoload/GameManager.gd").new()
	return gm
