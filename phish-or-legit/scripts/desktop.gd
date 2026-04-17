extends Control

@onready var textbox = $Textbox
@onready var notepad = $Notepad
@onready var notepad_button = $TaskBar/NotepadButton

# Called when the node enters the scene tree for the first time.
var is_open: bool = false


func _ready():
	notepad.notepad_panel.hide()
	if not GameManager.office_intro_shown:
		textbox.queue_messages([
		"This is your workstation.",
		"From here, you can review emails, buy upgrades, and keep notes on suspicious activity.",
		"Start by opening the email app, and I’ll guide you through your first review."
	])


 
