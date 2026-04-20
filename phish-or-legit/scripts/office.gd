extends Node2D

@onready var desk_area: Area2D = $DeskInteraction
@onready var interact_label: Label = $DeskInteraction/InteractLabel
@onready var player: CharacterBody2D = $player  # Fixed: matches node name in scene tree
@onready var canvas_layer = $player/Camera2D/CanvasLayer


var player_near_desk: bool = false


func _ready() -> void:
	desk_area.body_entered.connect(_on_desk_body_entered)
	desk_area.body_exited.connect(_on_desk_body_exited)
	if not GameManager.tutorial_shown:
		await get_tree().create_timer(3.0).timeout
		canvas_layer.queue_messages(["Welcome to your first day on the job as an FBI Security Analyst.", "Please head over to your desk to get started."])
		
func _process(_delta: float) -> void:
	if player_near_desk and Input.is_action_just_pressed("interact"):
		get_tree().change_scene_to_file("res://scenes/desktop.tscn")
		


func _on_desk_body_entered(body: Node2D) -> void:
	print("Body entered desk area: ", body.name)  # Debug — check Output tab
	if body == player:
		player_near_desk = true
		interact_label.visible = true


func _on_desk_body_exited(body: Node2D) -> void:
	if body == player:
		player_near_desk = false
		interact_label.visible = false
