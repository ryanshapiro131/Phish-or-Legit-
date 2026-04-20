extends Button
@onready var exit_button = $"."


func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/desktop.tscn")
