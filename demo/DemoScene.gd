extends CanvasLayer

signal demo_finished

@export var duration: float = 4.0
@export var boss_type: String = "boss"

var _timer: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioManager.play_demo_music(boss_type)

func _process(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		demo_finished.emit()
		queue_free()
