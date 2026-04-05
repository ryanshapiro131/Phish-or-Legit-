extends CharacterBody2D

@export var move_speed : float = 100
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var last_dir := Vector2.DOWN

func _physics_process(_delta_):
	var dir = Vector2(
		Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left"),
		Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	)
	
	if dir != Vector2.ZERO:
		dir = dir.normalized()
		last_dir = dir
		velocity = dir * move_speed
	else:
		velocity = Vector2.ZERO
		
	move_and_slide()
	 
	update_animation(dir)
	
func update_animation(dir : Vector2) -> void:
	if dir != Vector2.ZERO:
		if abs(dir.x) > abs(dir.y):
			anim.play("walk_side")
			anim.flip_h = dir.x < 0
		elif dir.y > 0:
			anim.play("walk_down")
			anim.flip_h = false
		else:
			anim.play("walk_up")
			anim.flip_h = false
		return
	
	if abs(last_dir.x) > abs(last_dir.y):
		anim.play("idle_side")
		anim.flip_h = last_dir.x < 0
	elif last_dir.y > 0:
		anim.play("idle_down")
		anim.flip_h = false
	else:
		anim.play("idle_up")
		anim.flip_h = false
		
