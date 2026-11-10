extends CharacterBody2D

# Variables
@export var speed: float = 400.0
@export var acceleration: float = 1600.0
@export var friction: float = 1000.0

@export var jump_velocity: float = -400.0
@export var wallslide_gravity: float = 150.0
@export var maxjumps: int = 1
var jumps: int = maxjumps

@export var walljump_pushback: float = 400.0
var is_wall_sliding: bool = true
var wallside: String = "none"

# Effects
var sparkPrefab = preload("res://Assets/Particles/spark.tscn")

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()

func _physics_process(delta: float) -> void:
	# Appply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Reset jumps on contact with floor
	if is_on_floor():
		jumps = maxjumps

	# Jump
	if Input.is_action_just_pressed("jump") and jumps > 0:
		jumps -= 1
		velocity.y = jump_velocity
		
	# Movement
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)

	# Handle wallsliding
	if is_on_wall() and not is_on_floor():
		# Right wall
		if Input.is_action_pressed("move_right"):
			for i in range(get_slide_collision_count()):
				var collision := get_slide_collision(i)
				var normal := collision.get_normal()
				if normal.x < 0:
					
					if Input.is_action_just_pressed("jump"):
						velocity.y = jump_velocity
						velocity.x = -walljump_pushback
					is_wall_sliding = true
					wallside = "right"
				else:
					is_wall_sliding = false
					wallside = "none"
		# Left Wall
		elif Input.is_action_pressed("move_left"):
			for i in range(get_slide_collision_count()):
				var collision := get_slide_collision(i)
				var normal := collision.get_normal()
				if normal.x > 0:
					if Input.is_action_just_pressed("jump"):
						velocity.y = jump_velocity
						velocity.x = walljump_pushback
					is_wall_sliding = true
					wallside = "left"
				else:
					is_wall_sliding = false
					wallside = "none"
		else:
			is_wall_sliding = false
			wallside = "none"
	else:
		is_wall_sliding = false
		wallside = "none"
	
	if is_wall_sliding:
		velocity.y += (wallslide_gravity * delta)
		velocity.y = min(velocity.y, wallslide_gravity)

	move_and_slide()

func spawnSparks():
	var sparkInstance = sparkPrefab.instantiate()
	get_parent().add_child(sparkInstance)
	sparkInstance.emitting = true
	sparkInstance.global_position = self.global_position
