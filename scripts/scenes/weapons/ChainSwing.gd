extends Area2D

var swing_duration: float = 0.6
var age: float = 0.0
var swung: bool = false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	body_entered.connect(_on_body_entered)

	var line = Line2D.new()
	line.name = "ChainLine"
	line.width = 4.0
	line.default_color = Color(1.0, 0.6, 0.1, 1.0)
	line.points = PackedVector2Array([Vector2.ZERO, Vector2(64, 0)])
	add_child(line)

	var tip = ColorRect.new()
	tip.name = "ChainTip"
	tip.size = Vector2(10, 10)
	tip.color = Color(1.0, 0.8, 0.2, 1.0)
	tip.position = Vector2(60, -5)
	add_child(tip)

	var col = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(14, 14)
	col.shape = rect
	col.position = Vector2(64, 0)
	add_child(col)

	# Small glow circle at the tip
	var glow = ColorRect.new()
	glow.name = "ChainGlow"
	glow.size = Vector2(18, 18)
	glow.color = Color(1.0, 0.4, 0.0, 0.4)
	glow.position = Vector2(55, -9)
	add_child(glow)

func swing() -> void:
	if swung:
		return
	swung = true
	var tween = create_tween()
	tween.tween_property(self, "rotation", deg_to_rad(130.0), swing_duration).from(deg_to_rad(-60.0))
	tween.tween_callback(_finish)

func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage") and body.is_in_group("player"):
		body.take_damage(1)

func _finish() -> void:
	ObjectPool.release(self)

func on_pool_acquire() -> void:
	age = 0.0
	swung = false
	rotation = 0.0

func on_pool_release() -> void:
	pass
