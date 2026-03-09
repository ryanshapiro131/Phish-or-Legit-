extends Control

var emails: Array = []
var current_email: EmailData

@onready var email_list_container = $emailListPanel/emailList
@onready var sender_label = $emailViewerPanel/ViewerVBox/SenderLabel
@onready var subject_label = $emailViewerPanel/ViewerVBox/SubjectLabel
@onready var body_text = $emailViewerPanel/ViewerVBox/RichTextLabel

@onready var accept_button = $emailViewerPanel/ViewerVBox/HBoxContainer/AcceptButton
@onready var deny_button = $emailViewerPanel/ViewerVBox/HBoxContainer/DenyButton
@onready var ignore_button = $emailViewerPanel/ViewerVBox/HBoxContainer/IgnoreButton
@onready var integrity_ui: Control = $IntegrityUI



func _ready():
	generate_test_emails()
	populate_email_list()
	connect_buttons()
		


# -----------------------------------------
# EMAIL GENERATION
# -----------------------------------------


func generate_test_emails():
	var legit = EmailData.new()
	legit.sender = "boss@fbi.com"
	legit.subject = "Team Meeting"
	legit.body = "Reminder about the 3PM meeting."
	legit.is_phishing = false
	legit.damage = 10
	legit.reward = 15
	

	var phish = EmailData.new()
	phish.sender = "admin-secure@fb1.com"
	phish.subject = "Account Suspended"
	phish.body = "Click immediately to restore access."
	phish.is_phishing = true
	phish.damage = 25
	phish.reward = 10

	emails.append(legit)
	emails.append(phish)


# -----------------------------------------
# POPULATE LEFT INBOX PANEL
# -----------------------------------------

func populate_email_list():
	for email in emails:
		var button = Button.new()
		button.text = email.subject
		button.pressed.connect(func(): open_email(email))
		email_list_container.add_child(button)


# -----------------------------------------
# OPEN EMAIL
# -----------------------------------------

func open_email(email: EmailData):
	current_email = email
	sender_label.text = "From: " + email.sender
	subject_label.text = "Subject: " + email.subject
	body_text.text = email.body


# -----------------------------------------
# CONNECT BUTTONS
# -----------------------------------------

func connect_buttons():
	accept_button.pressed.connect(on_accept_pressed)
	deny_button.pressed.connect(on_deny_pressed)
	ignore_button.pressed.connect(on_ignore_pressed)


# -----------------------------------------
# DECISION LOGIC
# -----------------------------------------

func on_accept_pressed():
	if current_email == null:
		return

	if current_email.is_phishing:
		integrity_ui.lose_integrity(current_email.damage)
		print("Data Breach!")
	else:
		#GameManagerInstance.add_salary(current_email.reward)
		print("Correct decision!")

	remove_current_email()

func on_deny_pressed():
	if current_email == null:
		return

	if current_email.is_phishing:
		##GameManagerInstance.add_salary(current_email.reward)
		print("Threat prevented!")
	else:
		integrity_ui.lose_integrity(8)
		print("False positive!")

	remove_current_email()


func on_ignore_pressed():
	print("Email ignored.")


func remove_current_email():
	sender_label.text = ""
	subject_label.text = ""
	body_text.text = ""
	emails.erase(current_email)
	current_email = null
	
