extends Node
 
var system_integrity: int = 100
var salary: int = 0
var office_intro_shown: bool = false
var desktop_intro_shown: bool = false
var email_intro_shown: bool = false
var shop_intro_shown: bool = false


@onready var bg_music = $BGMusic

func _ready():
	bg_music.play()
	
func lose_integrity(amount: int):
	system_integrity = max(system_integrity - amount, 0)
	print("Integrity:", system_integrity)
	# LOW WARNING
	if system_integrity <= 20 and system_integrity > 0:
		Assistant.show_message("Warning: System Integrity is critically low. Be very careful with incoming emails.")
	# GAME OVER
	if system_integrity <= 0:
		game_over()
 
func add_salary(amount: int):
	salary += amount
	print("Salary:", salary)
 
func game_over():
	print("NETWORK COMPROMISED")
	Assistant.show_messages([
		"System Integrity has reached zero.",
		"You failed to protect the network.",
		"You have been terminated from your position."
	])

	# Optional delay before switching scene
	await get_tree().create_timer(3.0).timeout
	# get_tree().change_scene_to_file("res://scenes/game_over.tscn")
