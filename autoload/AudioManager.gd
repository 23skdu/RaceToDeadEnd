extends Node

enum Bus { MASTER = 0, MUSIC = 1, SFX = 2 }

var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
const SFX_PLAYER_COUNT: int = 8

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.name = "MusicPlayer"
	add_child(music_player)
	for i in SFX_PLAYER_COUNT:
		var p = AudioStreamPlayer.new()
		p.bus = "SFX"
		p.name = "SFXPlayer" + str(i)
		add_child(p)
		sfx_players.append(p)

func play_music(stream: AudioStream, loop: bool = true) -> void:
	music_player.stream = stream
	music_player.autoplay = loop
	if loop:
		music_player.finished.connect(music_player.play, CONNECT_ONE_SHOT)
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_sfx(stream: AudioStream, position: Vector2 = Vector2.ZERO) -> void:
	for p in sfx_players:
		if not p.playing:
			p.stream = stream
			p.global_position = position
			p.play()
			return
	sfx_players[0].stream = stream
	sfx_players[0].global_position = position
	sfx_players[0].play()

func set_bus_volume(bus: Bus, volume_db: float) -> void:
	AudioServer.set_bus_volume_db(bus, volume_db)
