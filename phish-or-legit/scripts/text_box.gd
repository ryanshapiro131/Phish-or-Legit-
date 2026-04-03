extends CanvasLayer

@onready var textbox_container = $TextboxContainer
var textbox_visible: bool = false
@onready var start = $TextboxContainer/MarginContainer/HBoxContainer/Start
@onready var label = $TextboxContainer/MarginContainer/HBoxContainer/Label
@onready var end = $TextboxContainer/MarginContainer/HBoxContainer/End

const CHAR_READ_RATE = 0.03

var message_queue: Array = []
var is_typing: bool = false
var skip_typing: bool = false

func _ready():
	hide_textbox()
	#queue_messages(["The quick brown fox jumps over the lazy dog.", "This is the second message.", "And a third!"])

func _input(event):
	if event.is_action_pressed("text_interact") and textbox_container.visible:
		if is_typing:
			skip_typing = true  # Skip to end of current message
		else:
			_show_next_message()

func hide_textbox():
	start.text = ""
	end.text = ""
	label.text = ""
	textbox_visible = false
	textbox_container.hide()

func show_textbox():
	if textbox_visible:
		return
	textbox_visible = true
	start.text = "*"
	textbox_container.show()
	while textbox_visible:
		end.text = "[ENTER]"
		await get_tree().create_timer(0.5).timeout
		end.text = "            "
		await get_tree().create_timer(0.3).timeout
func queue_messages(messages: Array):
	for message in messages:
		message_queue.append(message)
	if not textbox_visible and not is_typing:
		_show_next_message()
		
func add_text(next_text):  # Keep this so existing calls still work
	queue_messages([next_text])

func _show_next_message():
	if message_queue.is_empty():
		hide_textbox()
		return

	var next_text = message_queue.pop_front()
	show_textbox()
	label.text = ""
	is_typing = true
	skip_typing = false
	end.text = ""

	for i in next_text.length():
		if skip_typing:
			label.text = next_text
			break
		label.text += next_text[i]
		await get_tree().create_timer(CHAR_READ_RATE).timeout

	is_typing = false
	skip_typing = false
	end.text = "Press ENTER"
