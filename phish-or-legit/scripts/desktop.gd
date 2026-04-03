extends Control

@onready var textbox = $Textbox

# Called when the node enters the scene tree for the first time.
func _ready():
	if not GameManager.office_intro_shown:
		GameManager.office_intro_shown = true
		await get_tree().create_timer(3.0).timeout
		textbox.queue_messages(["This is your Workstation", "Here you can access your emails, buy items, and take notes on whatever issues may come up.", "Start by clicking on the email icon on the Desktop, and I'll show you around from there."])
