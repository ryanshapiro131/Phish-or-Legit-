extends Control

func _ready():
	%Play.pressed.connect(play)
	%Quit.pressed.connect(quitGame)

func play():
	get_tree().change_scene_to_file("res://scenes/office.tscn")
	
func quitGame():
	get_tree().quit()
