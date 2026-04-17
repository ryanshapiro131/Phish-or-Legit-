extends Node

var system_integrity: int = 100
var salary: int = 0
var office_intro_shown: bool = false
var office_intro_wrong_choice: bool = false
var low_integrity_warning_shown: bool = false

var current_level: int = 1
var correct_emails: int = 0
var incorrect_emails: int = 0
var current_quota: int = 5

var notepad_text: String = ""  # Persists across scenes

@onready var bg_music: AudioStreamPlayer2D = $BGMusic

func _ready():
	bg_music.play()

func lose_integrity(amount: int):
	system_integrity = max(system_integrity - amount, 0)
	print("Integrity:", system_integrity)
	if system_integrity <= 0:
		game_over()

func add_salary(amount: int):
	salary += amount

func advance_level():
	current_level += 1
	correct_emails = 0
	incorrect_emails = 0

func reset():
	system_integrity = 100
	salary = 0
	current_level = 1
	correct_emails = 0
	incorrect_emails = 0
	office_intro_shown = false
	office_intro_wrong_choice = false
	notepad_text = ""
	low_integrity_warning_shown = false

func game_over():
	print("NETWORK COMPROMISED")
	# get_tree().change_scene_to_file("res://scenes/game_over.tscn")
