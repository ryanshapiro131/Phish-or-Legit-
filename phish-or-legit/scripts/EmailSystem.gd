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
# TUTORIAL STATE
# -----------------------------------------
var tutorial_mode: bool = false
var tutorial_step: String = ""
var tutorial_open_count: int = 0
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
		_start_forced_action_tutorial()
		
	if GameManager.current_level == 2:
		textbox.queue_messages([
			"Good work. Day two is more difficult.",
			"Some attackers can now spoof official-looking @fbi.gov addresses.",
			"That means you can’t trust the sender alone anymore.",
			"Pay close attention to urgency, unusual requests, and whether the message makes sense in context.",
			"One legitimate payroll request may come from Trevor Woodyard, so read carefully before deciding."
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

	if tutorial_mode:
		tutorial_open_count += 1

		if tutorial_step == "open_for_accept":
			tutorial_step = "press_accept"
			_set_action_buttons_enabled(true)
			deny_button.disabled = true
			ignore_button.disabled = true

			textbox.queue_messages([
				"You opened an email.",
				"Now press ACCEPT.",
				"ACCEPT lets the email go through the system."
			])
			return

		if tutorial_step == "open_for_deny":
			tutorial_step = "press_deny"
			_set_action_buttons_enabled(true)
			accept_button.disabled = true
			ignore_button.disabled = true

			textbox.queue_messages([
				"You opened an email.",
				"Now press DENY.",
				"DENY blocks the email to help protect the system."
			])
			return

		if tutorial_step == "open_for_ignore":
			tutorial_step = "press_ignore"
			_set_action_buttons_enabled(true)
			accept_button.disabled = true
			deny_button.disabled = true

			textbox.queue_messages([
				"You opened an email.",
				"Now press IGNORE.",
				"IGNORE means you are leaving the email for later and not deciding yet."
			])
			return


# -----------------------------------------
# CONNECT BUTTONS
# -----------------------------------------
func connect_buttons():
	accept_button.pressed.connect(on_accept_pressed)
	deny_button.pressed.connect(on_deny_pressed)
	ignore_button.pressed.connect(on_ignore_pressed)

# -----------------------------------------
# TUTORIAL HELPERS
# -----------------------------------------
func _set_action_buttons_enabled(enabled: bool):
	accept_button.disabled = not enabled
	deny_button.disabled = not enabled
	ignore_button.disabled = not enabled

func _clear_viewer():
	sender_label.text = ""
	subject_label.text = ""
	body_text.text = ""
	current_email = null

func _start_forced_action_tutorial():
	tutorial_mode = true
	tutorial_step = "open_for_accept"
	tutorial_open_count = 0
	_set_action_buttons_enabled(false)

	textbox.queue_messages([
		"This is your inbox.",
		"First, click any email to inspect it.",
		"After you open it, I will show you what ACCEPT does."
	])

func _finish_accept_tutorial():
	tutorial_step = "open_for_deny"
	_clear_viewer()
	_set_action_buttons_enabled(false)

	textbox.queue_messages([
		"Good job.",
		"ACCEPT lets a safe email go through.",
		"Use ACCEPT when an email looks legitimate and not dangerous.",
		"Now click any email again.",
		"This time I will show you what DENY does."
	])

func _finish_deny_tutorial():
	tutorial_step = "open_for_ignore"
	_clear_viewer()
	_set_action_buttons_enabled(false)

	textbox.queue_messages([
		"Good job.",
		"DENY blocks an email from going through.",
		"Use DENY when an email looks suspicious or dangerous.",
		"Now click any email again.",
		"This time I will show you what IGNORE does."
	])

func _finish_ignore_tutorial():
	tutorial_step = "done"
	_clear_viewer()
	_set_action_buttons_enabled(true)
	tutorial_mode = false
	GameManager.office_intro_shown = true

	textbox.queue_messages([
		"Good job.",
		"IGNORE means you are not deciding yet.",
		"The email stays for later while you keep thinking.",
		"Now you can play on your own. Read carefully and choose the best action."
	])
# -----------------------------------------
# DECISION LOGIC
# -----------------------------------------
func _show_correct_accept_feedback():
	textbox.queue_messages([
		"Good call. That message was legitimate.",
		"You confirmed a safe email without disrupting workflow."
	])

func _show_correct_deny_feedback():
	textbox.queue_messages([
		"Nice catch. That was a phishing attempt.",
		"Denying suspicious emails protects the system from compromise."
	])

func _show_ignore_feedback():
	textbox.queue_messages([
		"You ignored the email.",
		"That can be useful when you need more time, but unresolved messages can still become a problem if left alone."
	])

func _show_wrong_legit_denied_feedback():
	textbox.queue_messages([
		"Careful. That email was legitimate.",
		"Blocking safe messages can slow down operations and create confusion.",
		"Look again at the details before making the next decision."
	])

func _show_wrong_phish_accepted_feedback():
	textbox.queue_messages([
		"That was a phishing email.",
		"Accepting suspicious messages gives attackers a chance to damage the system.",
		"Use the sender, tone, and request itself to guide your decision next time."
	])
func _get_level_one_phishing_reason(email: EmailData) -> Array:
	var reasons: Array = []

	if "@fbi.gov" not in email.sender.to_lower():
		reasons.append("The sender was not from @fbi.gov.")

	if "urgent" in email.subject.to_lower():
		reasons.append("The subject tried to create urgency.")

	if "password" in email.subject.to_lower() or "password" in email.body.to_lower():
		reasons.append("It asked about a password, which is a common phishing trick.")

	if "click" in email.body.to_lower() or "link" in email.body.to_lower():
		reasons.append("It pushed you to click something quickly.")

	if reasons.is_empty():
		reasons.append("Something about the email was suspicious and unsafe.")

	return reasons

func _show_level_one_wrong_accept_feedback(email: EmailData):
	var reasons = _get_level_one_phishing_reason(email)

	var messages = [
		"That email should have been denied."
	]

	for reason in reasons:
		messages.append(reason)

	messages.append("In level 1, always check the sender first.")

	textbox.queue_messages(messages)

func _show_level_one_wrong_deny_feedback(email: EmailData):
	textbox.queue_messages([
		"That email should have been accepted.",
		"The sender was from @fbi.gov.",
		"In level 1, emails from official FBI addresses are usually safe."
	])
	
func on_accept_pressed():
	if current_email == null:
		return

	if tutorial_mode:
		if tutorial_step != "press_accept":
			textbox.queue_messages([
				"Not yet.",
				"Follow the tutorial and press the button I asked for."
			])
			return

		_finish_accept_tutorial()
		return

	if current_email.is_phishing:
		_handle_wrong_answer(current_email.damage)

		if GameManager.current_level == 1:
			_show_level_one_wrong_accept_feedback(current_email)
		else:
			textbox.queue_messages([
				"That email should have been denied.",
				"It contained warning signs of phishing.",
				"Look carefully at the sender, the request, and the tone next time."
			])
	else:
		GameManager.correct_emails += 1
		correct_sound.play()
		print("Correct!")
		GameManager.add_salary(current_email.reward)
		_show_correct_accept_feedback()
		_check_quota()

	remove_current_email()


func on_deny_pressed():
	if current_email == null:
		return

	if tutorial_mode:
		if tutorial_step != "press_deny":
			textbox.queue_messages([
				"Not yet.",
				"Follow the tutorial and press the button I asked for."
			])
			return

		_finish_deny_tutorial()
		return

	if not current_email.is_phishing:
		_handle_wrong_answer(8)

		if GameManager.current_level == 1:
			_show_level_one_wrong_deny_feedback(current_email)
		else:
			textbox.queue_messages([
				"That email was legitimate.",
				"You denied a safe email.",
				"Be careful not to block messages that are actually okay."
			])

	remove_current_email()

func on_ignore_pressed():
	if current_email == null:
		return

	if tutorial_mode:
		if tutorial_step != "press_ignore":
			textbox.queue_messages([
				"Not yet.",
				"Follow the tutorial and press the button I asked for."
			])
			return

		_finish_ignore_tutorial()
		return

	_show_ignore_feedback()
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
	if GameManager.system_integrity <= 20 and not GameManager.low_integrity_warning_shown:
		GameManager.low_integrity_warning_shown = true
		textbox.queue_messages([
			"Warning: system integrity is critically low.",
			"One or two more mistakes could compromise the network completely.",
			"Slow down and inspect each email carefully."
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
