extends CanvasLayer

@onready var notepad_panel: Panel = $NotepadPanel
@onready var text_edit: TextEdit = $NotepadPanel/TextEdit

var is_open: bool = false


func _ready():
	# Load any saved notes from GameManager
	text_edit.text = GameManager.notepad_text
	notepad_panel.hide()
	text_edit.text_changed.connect(_on_text_changed)


func _on_notepad_button_pressed():
	is_open = !is_open
	if is_open:
		notepad_panel.show()
		text_edit.grab_focus()
	else:
		notepad_panel.hide()


func _on_text_changed():
	# Save to GameManager every time the player types
	GameManager.notepad_text = text_edit.text
