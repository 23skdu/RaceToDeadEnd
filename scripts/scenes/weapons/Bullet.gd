extends Area2D

@export_group("Bullet Properties")
@export var bullet_speed: float = Constants.BULLET_SPEED
@export var bullet_damage: int = 1
@export var bullet_homing: float = 0.0

var speed: float = Constants.BULLET_SPEED
var direction: Vector2 = Vector2.UP
var damage: int = 1
var homing_strength: float = 0.0
var is_player_bullet: bool = true
var _cached_enemies: Array = []
var _cache_timer: float = 0.0

signal hit_target(target: Node)

func _ready() -> void:
	z_index = 2
	add_to_group("bullet")
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_visible_on_screen_notifier_screen_exited)
	monitoring = true
	monitorable = true

func init(pos: Vector2, dir: Vector2, player_owned: bool = true) -> void:
	global_position = pos
	direction = dir.normalized()
	is_player_bullet = player_owned
	if not is_player_bullet:
		direction = Vector2.DOWN
		collision_mask = 1
	else:
		collision_mask = 2

const MAX_HOMING_RANGE: float = 400.0
const EARLY_OUT_DIST_SQ: float = 4000.0

func _physics_process(delta: float) -> void:
	if homing_strength > 0.0:
		_cache_timer += delta
		if _cache_timer >= Constants.ENEMY_CACHE_INTERVAL:
			_cache_timer = 0.0
			_cached_enemies = GameManager.enemy_list
		var nearest = _find_nearest(_cached_enemies)
		if nearest and is_instance_valid(nearest):
			var target_dir = (nearest.global_position - global_position).normalized()
			direction = direction.lerp(target_dir, homing_strength * delta).normalized()
	position += direction * speed * delta

func _find_nearest(enemies: Array) -> Node:
	var nearest: Node = null
	var min_dist: float = INF
	var any_in_range: bool = false
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_squared_to(e.global_position)
		if d < min_dist:
			min_dist = d
			nearest = e
		if d < MAX_HOMING_RANGE * MAX_HOMING_RANGE:
			any_in_range = true
		if d < EARLY_OUT_DIST_SQ:
			return e
	if not any_in_range:
		return null
	return nearest

func _on_body_entered(body: Node) -> void:
	hit_target.emit(body)
	if body.has_method("take_damage"):
		body.take_damage(damage)
	_die()

func _on_area_entered(area: Area2D) -> void:
	hit_target.emit(area)
	if area.has_method("take_damage"):
		area.take_damage(damage)
	_die()

func _die() -> void:
	ObjectPool.release(self)

func on_pool_get() -> void:
	pass

func on_pool_release() -> void:
	homing_strength = 0.0
	damage = 1
	scale = Vector2.ONE
	modulate = Color.WHITE
	_cached_enemies.clear()
	_cache_timer = 0.0

func _on_visible_on_screen_notifier_screen_exited() -> void:
	ObjectPool.release(self)
