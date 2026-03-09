extends TextureButton



@onready var email_button: TextureButton = $"."



func _on_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/email.tscn")
	
	
