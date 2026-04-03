extends Control

func _ready():
	if not GameManager.desktop_intro_shown:
		GameManager.desktop_intro_shown = true
		await get_tree().process_frame
		Assistant.show_messages([
			"This is your workstation.",
			"Here you can access your emails, buy items, and take notes on whatever issues may come up.",
			"Start by clicking on the email icon on the Desktop, and I'll show you around from there."
		])
