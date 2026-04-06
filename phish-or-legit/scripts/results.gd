extends Control
@onready var level = $CenterContainer/VBoxContainer/Level
@onready var correct = $CenterContainer/VBoxContainer/Correct
@onready var incorrect = $CenterContainer/VBoxContainer/Incorrect
@onready var next_level = $NextLevel


# Called when the node enters the scene tree for the first time.
func _ready():
	level.text = str("Level ", GameManager.current_level, " Complete!")
	correct.text = str("Correct Emails: ", GameManager.correct_emails)
	incorrect.text = str("Incorrect Emails: ", GameManager.incorrect_emails)
	



	
	
	


func _on_next_level_pressed():
	get_tree().change_scene_to_file("res://scenes/office.tscn")
	GameManager.advance_level()
