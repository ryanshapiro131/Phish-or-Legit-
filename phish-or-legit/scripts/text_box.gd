extends CanvasLayer

@onready var textbox_container = $TextboxContainer
@onready var start = $TextboxContainer/MarginContainer/HBoxContainer/Start
@onready var label = $TextboxContainer/MarginContainer/HBoxContainer/Label
@onready var end = $TextboxContainer/MarginContainer/HBoxContainer/End

const CHAR_READ_RATE = 0.03

var message_queue: Array = []
var is_typing: bool = false
var skip_typing: bool = false

#TTS toggle/settings
var tts_enabled: bool = true
var tts_voice := "com.apple.voice.enhanced.en-US.Samantha"
var tts_volume := 100
var tts_pitch := 0.85
var tts_rate := 0.92

func _ready():
	print(DisplayServer.tts_get_voices())
	hide_textbox()

func _input(event):
	if event.is_action_pressed("text_interact") and textbox_container.visible:
		if is_typing:
			skip_typing = true
		else:
			_show_next_message()

func hide_textbox():
	start.text = ""
	end.text = ""
	label.text = ""
	textbox_container.hide()

	# NEW: stop speaking when textbox closes
	if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		DisplayServer.tts_stop()

func show_textbox():
	start.text = "*"
	textbox_container.show()
	while textbox_container.visible:
		end.text = "V"
		await get_tree().create_timer(1.0).timeout
		end.text = ""
		await get_tree().create_timer(0.4).timeout

func queue_messages(messages: Array):
	message_queue = messages
	_show_next_message()

func add_text(next_text):
	queue_messages([next_text])

# NEW: helper function for TTS
func speak_message(message: String):
	if not tts_enabled:
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return

	DisplayServer.tts_stop()

	# If you want to see available voices, uncomment this:
	# print(DisplayServer.tts_get_voices_for_language("en"))

	DisplayServer.tts_speak(message, tts_voice, tts_volume, tts_pitch, tts_rate, 0, true)

func _show_next_message():
	if message_queue.is_empty():
		hide_textbox()
		return

	var next_text = message_queue.pop_front()
	show_textbox()
	label.text = ""
	is_typing = true
	skip_typing = false

	# NEW: speak the message
	speak_message(next_text)

	for i in next_text.length():
		if skip_typing:
			label.text = next_text
			break
		label.text += next_text[i]
		await get_tree().create_timer(CHAR_READ_RATE).timeout

	is_typing = false
	skip_typing = false
