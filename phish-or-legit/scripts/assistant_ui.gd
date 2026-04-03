extends CanvasLayer

@onready var assistant_root = $AssistantRoot
@onready var dialogue_box = $AssistantRoot/DialogueBox
@onready var dialogue_text = $AssistantRoot/DialogueBox/DialogueText
@onready var assistant_character = $AssistantRoot/AssistantCharacter

const TYPE_SPEED := 0.02
const MESSAGE_DURATION := 4.0

var message_queue: Array[String] = []
var is_showing: bool = false
var skip_typing: bool = false

func _ready():
	hide_dialogue()

func _input(event):
	if event.is_action_pressed("text_interact") and dialogue_box.visible:
		skip_typing = true

func show_message(text: String):
	message_queue.append(text)
	if not is_showing:
		_show_next_message()

func show_messages(messages: Array[String]):
	for msg in messages:
		message_queue.append(msg)
	if not is_showing:
		_show_next_message()

func _show_next_message():
	if message_queue.is_empty():
		is_showing = false
		hide_dialogue()
		return

	is_showing = true
	var text = message_queue.pop_front()

	dialogue_box.visible = true
	dialogue_text.text = ""
	skip_typing = false

	for i in text.length():
		if skip_typing:
			dialogue_text.text = text
			break
		dialogue_text.text += text[i]
		await get_tree().create_timer(TYPE_SPEED).timeout

	skip_typing = false
	await get_tree().create_timer(MESSAGE_DURATION).timeout
	_show_next_message()

func hide_dialogue():
	dialogue_box.visible = false

func explain_mistake(reason: String):
	match reason:
		"bad_link":
			show_message("That email was phishing because the URL didn’t match the sender.")
		"urgent_language":
			show_message("That message used urgency to pressure you. That is a common phishing tactic.")
		"unknown_sender":
			show_message("The sender looked unfamiliar or suspicious. Always verify before trusting it.")
		"spoofed_domain":
			show_message("The domain looked official at first, but it was actually a fake variation.")
		"attachment_risk":
			show_message("Unexpected attachments can contain malware. Be careful before opening them.")
		_:
			show_message("Something about that email was suspicious. Slow down and inspect the details.")
