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

@export_category("Movement (Quickslam)")
@export var slam_velocity: float = 1200
var is_quickslamming: bool = false

@export_category("Movement (Dashing)")
@export var dash_velocity: float = 800.0
@export var dash_upwards_velocity: float = -100.0
@export var maxdashes: int = 3
var dashes: int = maxdashes
var dashtimer: float = 0.0
var dashchargetime: float = 0.75

var last_dir: String = "right"

# Audio
@export_category("Audio")
@export var jumpSound: AudioStreamPlayer2D
@export var dashSound: AudioStreamPlayer2D
@export var slideSound: AudioStreamPlayer2D
@export var landSound: AudioStreamPlayer2D
@export var slamSound: AudioStreamPlayer2D
@export var hurtSound: AudioStreamPlayer2D
@export var healSound: AudioStreamPlayer2D

# Effects
@export_category("Effects")
@export var sparkPrefab: PackedScene
@export var bloodPrefab: PackedScene
@export var slamPrefab: PackedScene

# Nodes
@export_category("Nodes")
@export var Camera: Camera2D
@export var Sprite: Sprite2D

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

var was_on_floor: bool = false

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Set up UI
		DashBar.max_value = dashchargetime
		HealthBar.max_value = maxhealth
		slideSound.play()
		slideSound.stream_paused = true

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		# Exit
		if Input.is_action_just_pressed("exit"):
			get_tree().quit()
		
		# Reset
		if Input.is_action_just_pressed("restart"):
			spawnBlood()
			queue_free()
		
		# Stats
		var currenthealth = round((health/maxhealth) * 100)
		var lerpedhealth = move_toward(HealthBar.value, currenthealth, 0.75)
		var roundedhealth = round(lerpedhealth)
		
		DashCounter.text = "DASHES: " + str(dashes)
		DashBar.value = dashtimer
		HealthCounter.text = "HEALTH: " + str(int(roundedhealth)) + "%"
		HealthBar.value = roundedhealth

		# Damage Effects
		if Sprite.modulate != Color.WHITE:
			Sprite.modulate = Sprite.modulate.lerp(Color.WHITE, 0.1)

		# Low Health Effects
		if health <= (maxhealth / 100):
			HurtLayer.color.a = move_toward(HurtLayer.color.a, 0.65, 0.01)
			Camera.constShake(0.025)
		elif health <= (maxhealth / 10):
			HurtLayer.color.a = move_toward(HurtLayer.color.a, 0.4, 0.01)
			Camera.constShake(0.025)
		elif health < (maxhealth / 4):
			HurtLayer.color.a = move_toward(HurtLayer.color.a, 0.25, 0.01)
			Camera.constShake(0.015)
		elif health < (maxhealth / 2):
			HurtLayer.color.a = move_toward(HurtLayer.color.a, 0.1, 0.01)
			Camera.constShake(0.01)
		else:
			HurtLayer.color.a = move_toward(HurtLayer.color.a, 0, 0.01)
			
		# Health
		if health > maxhealth:
			health = maxhealth
		if health <= 0:
			get_tree().reload_current_scene()

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
			jumpSound.play()
			
		if Input.is_action_just_pressed("quickslam") and not is_on_floor() and not is_quickslamming:
			if velocity.y < 0:
				velocity.y = slam_velocity
			else:
				velocity.y += slam_velocity
			is_quickslamming = true
		
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
			dashSound.play()
			
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
							jumpSound.play()
							is_quickslamming = false
						is_wall_sliding = true
						wallside = "right"
						if wallslide_time > wallslide_spark_time:
							spawnSparks(true)
							slideSound.stream_paused = false
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
							jumpSound.play()
							is_quickslamming = false
						is_wall_sliding = true
						wallside = "left"
						if wallslide_time > wallslide_spark_time:
							spawnSparks(false)
							slideSound.stream_paused = false
					else:
						is_wall_sliding = false
			else:
				is_wall_sliding = false
		else:
			is_wall_sliding = false
		
		if is_quickslamming:
			velocity.x = 0
		
		if is_wall_sliding:
			if not is_quickslamming:
				velocity.y += (wallslide_gravity * delta)
				velocity.y = min(velocity.y, wallslide_gravity)
				if velocity.y > 0:
					wallslide_time += 1 * delta
		else:
			wallside = "none"
			wallslide_time = 0
			slideSound.stream_paused = true
	
		move_and_slide()
		
		# Landing
		if not was_on_floor and is_on_floor():
			if is_quickslamming:
				slamSound.play()
				is_quickslamming = false
				spawnSlamParticles()
			else:
				landSound.play()
			
		was_on_floor = is_on_floor()

func takeDamage(amount: float):
	health -= amount
	cameraShake(amount / 50)
	Sprite.modulate = Color.RED
	hurtSound.play()

func heal(amount: float):
	health += amount
	Sprite.modulate = Color.GREEN
	healSound.play()

func cameraShake(amount: float):
	Camera.add_trauma(amount)

func spawnSparks(left: bool):
	if sparkPrefab:
		var effectInstance = sparkPrefab.instantiate()
		if left == true:
			effectInstance.global_position = self.global_position - Vector2(-30, 30)
		if left == false:
			effectInstance.global_position = self.global_position - Vector2(30, 30)
		get_parent().add_child(effectInstance)
		effectInstance.emitting = true
		
func spawnBlood():
	if bloodPrefab:
		var effectInstance = bloodPrefab.instantiate()
		effectInstance.global_position = self.global_position
		get_parent().add_child(effectInstance)
		effectInstance.emitting = true

func spawnSlamParticles():
	if slamPrefab:
		var effectInstance = slamPrefab.instantiate()
		effectInstance.global_position = self.global_position - Vector2(0, -56)
		get_parent().add_child(effectInstance)
		effectInstance.emitting = true
