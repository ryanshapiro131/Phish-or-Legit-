extends Control

@onready var textbox = $Textbox
@onready var notepad = $Notepad
@onready var notepad_button = $TaskBar/NotepadButton

# Called when the node enters the scene tree for the first time.
var is_open: bool = false


func _ready():
	notepad.notepad_panel.hide()
	if not GameManager.tutorial_shown:
		await get_tree().create_timer(1.0).timeout
		textbox.queue_messages(["This is your Workstation", "Here you can access your emails, buy items, and take notes on whatever issues may come up.", "Start by clicking on the email icon on the Desktop, and I'll show you around from there."])



 
