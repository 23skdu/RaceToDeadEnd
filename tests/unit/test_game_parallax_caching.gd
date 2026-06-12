extends GutTest

func before_each():
	# Clear the static cache before each test
	var game_script = load("res://scripts/scenes/Game.gd")
	game_script._parallax_texture_cache.clear()

func test_parallax_texture_cache_is_populated_on_ready():
	var game_script = load("res://scripts/scenes/Game.gd")
	assert_true(game_script._parallax_texture_cache.is_empty(), "Cache should be empty initially")
	
	var game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game)
	
	assert_eq(game_script._parallax_texture_cache.size(), 4, "Cache should be populated with 4 textures after ready")
	for tex in game_script._parallax_texture_cache:
		assert_is(tex, Texture2D, "Cache elements should be Texture2D")

func test_parallax_texture_cache_reused_on_subsequent_instances():
	var game_script = load("res://scripts/scenes/Game.gd")
	
	var game1 = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game1)
	
	var cached_textures = game_script._parallax_texture_cache.duplicate()
	assert_eq(cached_textures.size(), 4, "Should have 4 cached textures")
	
	var game2 = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(game2)
	
	assert_eq(game_script._parallax_texture_cache.size(), 4, "Cache size should not grow")
	for i in range(4):
		assert_eq(game_script._parallax_texture_cache[i], cached_textures[i], "Textures should be identical cached instances")
