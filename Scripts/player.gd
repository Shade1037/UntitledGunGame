extends CharacterBody2D

# Variables
const SPEED = 400.0
const JUMP_VELOCITY = -400.0

var maxjumps = 2
var jumps = maxjumps


func _physics_process(delta: float) -> void:
	# Appply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") && jumps > 1:
		velocity.y = JUMP_VELOCITY
		jumps -= 1

	# Reset jumps on contact with floor
	if is_on_floor():
		jumps = maxjumps

	# Movement
	var direction := Input.get_axis("move_left", "move_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = 0

	move_and_slide()
