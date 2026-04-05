extends CanvasLayer

@onready var textbox = $TextBox

func show_message(text: String):
	textbox.queue_messages([text])

func show_messages(messages: Array[String]):
	textbox.queue_messages(messages)

func explain_mistake(reason: String):
	match reason:
		"bad_link":
			show_message("The URL didn’t match the sender. That’s a common phishing trick.")
		"urgent_language":
			show_message("Urgent language is used to pressure you into mistakes.")
		"unknown_sender":
			show_message("You don’t recognize the sender. Always verify first.")
		"spoofed_domain":
			show_message("The domain looked official, but it was actually a fake variation.")
		"attachment_risk":
			show_message("Unexpected attachments can contain malware. Be careful before opening them.")
		_:
			show_message("Something about that email was suspicious. Slow down and inspect the details.")
