extends Area2D

@onready var label = $Label
@onready var ring_sound = $RingSound
@onready var phone_call_ui = $"../PhoneCallUI"

var player_near = false


func _ready():
	label.visible = false
	phone_call_ui.visible = false
	
	if ring_sound:
		ring_sound.play()


func _process(delta):
	if player_near and Input.is_action_just_pressed("interact"):
		answer_phone()


func answer_phone():
	label.visible = false
	
	if ring_sound:
		ring_sound.stop()
	
	phone_call_ui.visible = true


func _on_body_entered(body):
	if body.name == "Player":
		player_near = true
		label.visible = true


func _on_body_exited(body):
	if body.name == "Player":
		player_near = false
		label.visible = false
