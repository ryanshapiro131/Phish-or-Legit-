extends Control

@onready var caller_label = $Panel/CallerLabel
@onready var dialogue_label = $Panel/DialogueLabel

@onready var option1 = $Panel/ButtonContainer/OptionButton1
@onready var option2 = $Panel/ButtonContainer/OptionButton2
@onready var option3 = $Panel/ButtonContainer/OptionButton3

@onready var integrity_ui = get_tree().get_first_node_in_group("IntegrityUI")


func _ready():

	var caller_name = "IT Support"
	var dialogue = "Hello, this is IT support. We need your password to verify your account."

	caller_label.text = "Caller: " + caller_name
	dialogue_label.text = dialogue

	option1.text = "Give password"
	option2.text = "Refuse request"
	option3.text = "Ask for verification"

	option1.pressed.connect(on_wrong_answer)
	option2.pressed.connect(on_correct_answer)
	option3.pressed.connect(on_wrong_answer)


func on_wrong_answer():
	if integrity_ui:
		integrity_ui.lose_integrity(15)

	print("You've been scammed!")


func on_correct_answer():
	print("Phone scam successfully avoided!")
