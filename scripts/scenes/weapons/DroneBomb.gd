extends Area2D

var age: float = 0.0
var exploded: bool = false
var hit_by_bullet: bool = false
var warning_visual: Polygon2D
var explosion_visual: Polygon2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1 | 3 # player layer + player bullets
	area_entered.connect(_on_area_entered)
	
	# Collision shape
	var col = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = Constants.BLAST_RADIUS
	col.shape = circle
	add_child(col)
	
	# Spawn warning circle diamond look
	warning_visual = Polygon2D.new()
	var pts = []
	var segments = 16
	for i in segments:
		var angle = i * TAU / segments
		pts.append(Vector2(cos(angle) * Constants.BLAST_RADIUS, sin(angle) * Constants.BLAST_RADIUS * 0.5))
	warning_visual.polygon = PackedVector2Array(pts)
	warning_visual.color = Color(1.0, 0.1, 0.1, 0.25)
	add_child(warning_visual)

	# Pre-allocate reusable explosion visual circle
	explosion_visual = Polygon2D.new()
	explosion_visual.polygon = PackedVector2Array(pts)
	explosion_visual.color = Color(1.0, 0.8, 0.2, 0.8)
	explosion_visual.visible = false
	add_child(explosion_visual)

func _process(delta: float) -> void:
	age += delta
	
	if not exploded:
		# Blinking effect increases in speed as detonation approaches
		var speed_factor = 1.0 + (age / Constants.DETONATION_TIME) * 8.0
		var blink = int(age * speed_factor * 10.0) % 2 == 0
		warning_visual.visible = blink
		
		if age >= Constants.DETONATION_TIME:
			_detonate()
	else:
		# Exploding fading visual
		var t = (age - Constants.DETONATION_TIME) / 0.3
		if t >= 1.0:
			ObjectPool.release(self)
		else:
			explosion_visual.scale = Vector2.ONE * (1.0 + t * 0.5)
			explosion_visual.color = Color(1.0, 0.7, 0.1, 1.0 - t)

func on_pool_acquire() -> void:
	age = 0.0
	exploded = false
	hit_by_bullet = false
	if explosion_visual and is_instance_valid(explosion_visual):
		explosion_visual.visible = false
		explosion_visual.scale = Vector2.ONE
		explosion_visual.color = Color(1.0, 0.8, 0.2, 0.8)
	if warning_visual and is_instance_valid(warning_visual):
		warning_visual.visible = true

func _on_area_entered(area: Area2D) -> void:
	if not exploded and area.is_in_group("bullet"):
		hit_by_bullet = true
		_detonate()

func _detonate() -> void:
	exploded = true
	warning_visual.visible = false
	CameraShake.shake(0.8, 0.4, 10.0)
	CameraShake.rumble(1.0, 0.5)
	
	# Show reusable explosion visual circle
	if not explosion_visual or not is_instance_valid(explosion_visual):
		explosion_visual = Polygon2D.new()
		var pts = []
		var segments = 16
		for i in segments:
			var angle = i * TAU / segments
			pts.append(Vector2(cos(angle) * Constants.BLAST_RADIUS, sin(angle) * Constants.BLAST_RADIUS * 0.5))
		explosion_visual.polygon = PackedVector2Array(pts)
		add_child(explosion_visual)
	explosion_visual.scale = Vector2.ONE
	explosion_visual.color = Color(1.0, 0.8, 0.2, 0.8)
	explosion_visual.visible = true
	
	# Check collision with player
	for body in get_overlapping_bodies():
		if body.has_method("take_damage") and body.is_in_group("player"):
			body.take_damage(2)
