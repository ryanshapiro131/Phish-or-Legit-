extends TextureButton

@onready var shop_widget = $"."


func _on_pressed():
	get_tree().change_scene_to_file("res://scenes/shop.tscn")
