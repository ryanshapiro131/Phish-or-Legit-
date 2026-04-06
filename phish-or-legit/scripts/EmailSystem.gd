extends Control

# -----------------------------------------
# CONSTANTS
# -----------------------------------------
const MAX_INBOX = 8
const EMAIL_SPAWN_INTERVAL = 15.0
const IGNORE_RETURN_DELAY = 60.0
const PHISHING_RATIO_HIGH   = 0.3
const PHISHING_RATIO_MEDIUM = 0.5
const PHISHING_RATIO_LOW    = 0.7

# -----------------------------------------
# STATE
# -----------------------------------------
var emails: Array = []
var current_email: EmailData = null
var email_buttons: Dictionary = {}
var email_pool: Array = []   # full pool loaded from JSON
var level_quota: int = 5

# -----------------------------------------
# NODE REFS
# -----------------------------------------
@onready var email_list_container = $MainVBox/Content/EmailListSectionPanel/EmailListSectionMargin/EmailList/EmailListVBox
@onready var sender_label         = $MainVBox/Content/EmailViewerPanel/ViewerVBox/SenderBar/SenderBarMargin/SenderBarHBox/SenderInfoVBox/SenderLabel
@onready var subject_label        = $MainVBox/Content/EmailViewerPanel/ViewerVBox/SubjectBar/SubjectMargin/SubjectLabel
@onready var body_text            = $MainVBox/Content/EmailViewerPanel/ViewerVBox/BodyArea/BodyMargin/BodyText
@onready var accept_button        = $MainVBox/Content/EmailViewerPanel/ViewerVBox/ActionBar/ActionBarMargin/ActionBarHBox/AcceptButton
@onready var deny_button          = $MainVBox/Content/EmailViewerPanel/ViewerVBox/ActionBar/ActionBarMargin/ActionBarHBox/DenyButton
@onready var ignore_button        = $MainVBox/Content/EmailViewerPanel/ViewerVBox/ActionBar/ActionBarMargin/ActionBarHBox/IgnoreButton
@onready var integrity_ui: Control = $MainVBox/BottomBar/BottomBarMargin/BottomBarHBox/IntegrityPanel/IntegrityMargin/IntegrityUI
@onready var spawn_timer: Timer    = $SpawnTimer
@onready var hit_sound             = $HitSound
@onready var textbox               = $Textbox
@onready var correct_sound = $CorrectSound

@onready var sender_icon = $MainVBox/Content/EmailViewerPanel/ViewerVBox/SenderBar/SenderBarMargin/SenderBarHBox/ViewerSenderIconArea/ViewerSenderIcon
@onready var score = $MainVBox/Content/FolderSidebarPanel/FolderSidebarMargin/FolderSidebarVBox/Score


# -----------------------------------------
# READY
# -----------------------------------------
func _ready():
	connect_buttons()
	_load_level(GameManager.current_level)
	_seed_initial_emails()
	populate_email_list()

	spawn_timer.wait_time = EMAIL_SPAWN_INTERVAL
	spawn_timer.timeout.connect(_on_spawn_timer)
	spawn_timer.start()

	if not GameManager.office_intro_shown:
		await get_tree().create_timer(2.0).timeout
		textbox.queue_messages([
			"This is your email inbox. This is where you will be doing most of your work.",
			"Click on one of your emails to read it, then decide to Accept, Deny, or Ignore it."
		])
		
	if GameManager.current_level == 2:
		await get_tree().create_timer(2.0).timeout
		textbox.queue_messages([
			"Great job on your first day! Unfortunately, the hackers have gotten a little better since you've left.",
			"Some of them have figured out how to send directly from an @fbi.gov address.",
			"Basically, if anyone is urgently asking you for something serious, and it seems suspicious, its best to deny it.",
			"Also, be on the lookout for Trevor Woodyard, he is genuinely needing information for payroll, so let that one through."
		])


func _process(_delta):
	score.text = "Correct Emails: " + str(GameManager.correct_emails) + "/" + str(level_quota)


# -----------------------------------------
# LOAD LEVEL FROM JSON
# -----------------------------------------
func _load_level(level: int):
	var path = "res://levels/level" + str(level) + ".json"
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not load level file: " + path)
		return

	var json = JSON.new()
	var result = json.parse(file.get_as_text())
	file.close()

	if result != OK:
		push_error("Failed to parse JSON for level " + str(level))
		return

	var data = json.get_data()
	level_quota = data["quota"]
	GameManager.current_quota = level_quota
	email_pool = []

	for e in data["emails"]:
		var email = EmailData.new()
		email.sender     = e["sender"]
		email.subject    = e["subject"]
		email.body       = e["body"]
		email.is_phishing = e["is_phishing"]
		email.damage     = e["damage"]
		email.reward     = e["reward"]
		email.difficulty = e["difficulty"]
		email.icon 		 = e.get("icon", "Adam_16x16.png")
		email_pool.append(email)


# -----------------------------------------
# SEED INBOX ON START
# -----------------------------------------
func _seed_initial_emails():
	var pool_copy = email_pool.duplicate()
	pool_copy.shuffle()
	var to_add = min(5, pool_copy.size())
	for i in to_add:
		emails.append(pool_copy[i])


# -----------------------------------------
# SPAWN NEW EMAIL ON TIMER
# -----------------------------------------
func _on_spawn_timer():
	if emails.size() >= MAX_INBOX:
		return

	var integrity = GameManager.system_integrity
	var phishing_chance: float
	if integrity > 60:
		phishing_chance = PHISHING_RATIO_HIGH
	elif integrity > 30:
		phishing_chance = PHISHING_RATIO_MEDIUM
	else:
		phishing_chance = PHISHING_RATIO_LOW

	var roll = randf()
	var candidates: Array
	if roll < phishing_chance:
		candidates = email_pool.filter(func(e): return e.is_phishing)
	else:
		candidates = email_pool.filter(func(e): return not e.is_phishing)

	if candidates.is_empty():
		return

	candidates.shuffle()
	var new_email = candidates[0]

	var existing_subjects = emails.map(func(e): return e.subject)
	if new_email.subject in existing_subjects:
		return

	emails.append(new_email)
	_add_email_button(new_email)


# -----------------------------------------
# POPULATE LEFT INBOX PANEL
# -----------------------------------------
func populate_email_list():
	for email in emails:
		_add_email_button(email)

func _add_email_button(email: EmailData):
	var button = Button.new()
	button.text = email.subject
	button.pressed.connect(func(): open_email(email))
	email_list_container.add_child(button)
	email_buttons[email] = button


# -----------------------------------------
# OPEN EMAIL
# -----------------------------------------
func open_email(email: EmailData):
	current_email = email
	sender_label.text = "From: " + email.sender
	subject_label.text = "Subject: " + email.subject
	body_text.text = email.body
	sender_icon.texture = load("res://assets/icons/" + email.icon)

	if not GameManager.office_intro_shown:
		GameManager.office_intro_shown = true
		await get_tree().create_timer(3.0).timeout
		textbox.queue_messages([
			"Your job is to filter out phishing emails from hackers trying to steal our data.",
			"Check the sender carefully — if it's not from @fbi.gov, be suspicious.",
			"Give some emails a try and I'll check back with you soon."
		])


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
		_handle_wrong_answer(current_email.damage)
	else:
		GameManager.correct_emails += 1
		correct_sound.play()
		print("Correct!")
		GameManager.add_salary(current_email.reward)
		_check_quota()

	remove_current_email()


func on_deny_pressed():
	if current_email == null:
		return

	if not current_email.is_phishing:
		_handle_wrong_answer(8)
	else:
		correct_sound.play()
		GameManager.correct_emails += 1
		print("Threat prevented!")
		GameManager.add_salary(current_email.reward)
		_check_quota()

	remove_current_email()


func on_ignore_pressed():
	if current_email == null:
		return
	sender_label.text = ""
	subject_label.text = ""
	body_text.text = ""
	current_email = null


# -----------------------------------------
# WRONG ANSWER
# -----------------------------------------
func _handle_wrong_answer(damage: int):
	GameManager.incorrect_emails += 1
	integrity_ui.lose_integrity(damage)
	hit_sound.play()
	$MainVBox/BottomBar/BottomBarMargin/BottomBarHBox/IntegrityPanel/IntegrityMargin/IntegrityUI/AnimationPlayer.play("integrity_hit")

	if not GameManager.office_intro_wrong_choice:
		GameManager.office_intro_wrong_choice = true
		await get_tree().create_timer(1.0).timeout
		textbox.queue_messages([
			"Woah!! You just let a hacker into our system!",
			"We handled it this time, but a few more and our systems could go down.",
			"And if that happens... YOU'RE FIRED!!",
			"Anyways, keep at it. You'll get the hang of it!"
		])


# -----------------------------------------
# CHECK QUOTA
# -----------------------------------------
func _check_quota():
	if GameManager.correct_emails >= level_quota:
		spawn_timer.stop()
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/results.tscn")


# -----------------------------------------
# REMOVE EMAIL
# -----------------------------------------
func remove_current_email():
	sender_label.text = ""
	subject_label.text = ""
	body_text.text = ""
	if current_email in email_buttons:
		email_buttons[current_email].queue_free()
		email_buttons.erase(current_email)
	emails.erase(current_email)
	current_email = null
