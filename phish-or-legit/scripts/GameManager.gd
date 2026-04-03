extends Node
 
var system_integrity: int = 100
var salary: int = 0
var office_intro_shown: bool = false

@onready var bg_music = $BGMusic

func _ready():
	bg_music.play()
	
func lose_integrity(amount: int):
	system_integrity = max(system_integrity - amount, 0)
	print("Integrity:", system_integrity)
	if system_integrity <= 0:
		game_over()
 
func add_salary(amount: int):
	salary += amount
	print("Salary:", salary)
 
func game_over():
	print("NETWORK COMPROMISED")
	# get_tree().change_scene_to_file("res://scenes/game_over.tscn")
 
