@tool
extends CharacterBody2D

# Variables
@export_category("Health")
@export var maxhealth: float = 100.0
var health: float = maxhealth

@export_category("Movement (Speed)")
@export var speed: float = 400.0
@export var acceleration: float = 1600.0
@export var friction: float = 1000.0

@export_category("Movement (Jumping)")
@export var jump_velocity: float = -400.0
@export var wallslide_gravity: float = 150.0
@export var maxjumps: int = 1
var jumps: int = maxjumps

@export var walljump_pushback: float = 400.0
var is_wall_sliding: bool = true
var wallside: String = "none"
var wallslide_time: float = 0.0;
var wallslide_spark_time: float = 0.25;

@export_category("Movement (Dashing)")
@export var dash_velocity: float = 800.0
@export var dash_upwards_velocity: float = -100.0
@export var maxdashes: int = 3
var dashes: int = maxdashes
var dashtimer: float = 0.0
var dashchargetime: float = 0.75

var last_dir: String = "right"

# Effects
@export_category("Effects")
@export var sparkPrefab: Resource

# Nodes
@export_category("Nodes")
@export var Camera: Camera2D

# UI
@export_category("UI")
@export var PlayerUI: CanvasLayer
@export var PlayerStats: Control
@export var DamageLayer: ColorRect
@export var HurtLayer: ColorRect

# Stat Labels
@export_category("Stat Labels")
@export var DashCounter: Label
@export var DashBar: ProgressBar
@export var HealthCounter: Label
@export var HealthBar: ProgressBar

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Set up UI
		DashBar.max_value = dashchargetime
		HealthBar.max_value = maxhealth

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		# Testing
		if Input.is_action_just_pressed("button"):
			takeDamage(10)
		
		# Exit
		if Input.is_action_just_pressed("exit"):
			get_tree().quit()
		
		# Stats
		var currenthealth = round((health/maxhealth) * 100)
		var roundedhealth = move_toward(HealthBar.value, currenthealth, 1)
		
		DashCounter.text = "DASHES: " + str(dashes)
		DashBar.value = dashtimer
		HealthCounter.text = "HEALTH: " + str(roundedhealth) + "%"
		HealthBar.value = roundedhealth
		
		# Damage Effects
		if DamageLayer.color.a > 0:
			DamageLayer.color.a = move_toward(DamageLayer.color.a, 0, 0.01)
		if DamageLayer.color.a > 1:
			DamageLayer.color.a = 1
			
		# Low Health Effects
		if health < (maxhealth / 2):
			HurtLayer.color.a = 0.2
			Camera.constShake(0.01)
		
		if health <= (maxhealth / 4):
			HurtLayer.color.a = 0.3
			Camera.constShake(0.015)
			
		if health <= (maxhealth / 10):
			HurtLayer.color.a = 0.5
			Camera.constShake(0.025)

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		# Appply gravity
		if not is_on_floor():
			velocity += get_gravity() * delta
	
		# Reset jumps on contact with floor
		if is_on_floor():
			jumps = maxjumps
	
		# Jump
		if Input.is_action_just_pressed("jump") and jumps > 0 and is_on_floor():
			jumps -= 1
			velocity.y = jump_velocity
		
		# Movement Tracking
		if Input.is_action_pressed("move_right"):
			last_dir = "right"
		
		if Input.is_action_pressed("move_left"):
			last_dir = "left"
		
		if dashes < maxdashes:
			dashtimer += 1 * delta
			if dashtimer > dashchargetime:
				dashtimer = 0
				dashes += 1
		
		# Dashing
		if Input.is_action_just_pressed("dash") and dashes > 0:
			dashes -= 1
			if last_dir == "right":
				velocity.x = dash_velocity
			else:
				velocity.x = -dash_velocity
			velocity.y = dash_upwards_velocity
			
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
						if wallslide_time > wallslide_spark_time:
							spawnSparks(true)
					else:
						is_wall_sliding = false
						wallside = "none"
						wallslide_time = 0
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
						if wallslide_time > wallslide_spark_time:
							spawnSparks(false)
					else:
						is_wall_sliding = false
			else:
				is_wall_sliding = false
		else:
			is_wall_sliding = false
		
		if is_wall_sliding:
			velocity.y += (wallslide_gravity * delta)
			velocity.y = min(velocity.y, wallslide_gravity)
			if velocity.y > 0:
				wallslide_time += 1 * delta
		else:
			wallside = "none"
			wallslide_time = 0
	
		move_and_slide()

func spawnSparks(left: bool):
	var effectInstance = sparkPrefab.instantiate()
	get_parent().add_child(effectInstance)
	effectInstance.emitting = true
	if left == true:
		effectInstance.global_position = self.global_position - Vector2(-30, 30)
	if left == false:
		effectInstance.global_position = self.global_position - Vector2(30, 30)

func takeDamage(amount: float):
	health -= amount
	cameraShake(amount / 50)
	DamageLayer.color.a += amount / 50

func cameraShake(amount: float):
	Camera.add_trauma(amount)
