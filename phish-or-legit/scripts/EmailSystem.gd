extends Control

# -----------------------------------------
# CONSTANTS
# -----------------------------------------
const MAX_INBOX = 8
const EMAIL_SPAWN_INTERVAL = 30.0
const IGNORE_RETURN_DELAY = 60.0

# Phishing ratio by integrity bracket
# integrity > 60: 30% phishing, > 30: 50%, <= 30: 70%
const PHISHING_RATIO_HIGH   = 0.3
const PHISHING_RATIO_MEDIUM = 0.5
const PHISHING_RATIO_LOW    = 0.7

# -----------------------------------------
# STATE
# -----------------------------------------
var emails: Array = []
var ignored_emails: Array = []
var current_email: EmailData = null
var email_buttons: Dictionary = {}

# -----------------------------------------
# NODE REFS
# -----------------------------------------
@onready var email_list_container = $emailListPanel/emailList
@onready var sender_label         = $emailViewerPanel/ViewerVBox/SenderLabel
@onready var subject_label        = $emailViewerPanel/ViewerVBox/SubjectLabel
@onready var body_text            = $emailViewerPanel/ViewerVBox/RichTextLabel
@onready var accept_button        = $emailViewerPanel/ViewerVBox/HBoxContainer/AcceptButton
@onready var deny_button          = $emailViewerPanel/ViewerVBox/HBoxContainer/DenyButton
@onready var ignore_button        = $emailViewerPanel/ViewerVBox/HBoxContainer/IgnoreButton
@onready var integrity_ui = $IntegrityUI
@onready var spawn_timer: Timer   = $SpawnTimer
@onready var hit_sound = $HitSound


# -----------------------------------------
# READY
# -----------------------------------------
func _ready():
	connect_buttons()
	_seed_initial_emails()
	populate_email_list()

	spawn_timer.wait_time = EMAIL_SPAWN_INTERVAL
	spawn_timer.timeout.connect(_on_spawn_timer)
	spawn_timer.start()

	if not GameManager.email_intro_shown:
		GameManager.email_intro_shown = true
		await get_tree().process_frame
		Assistant.show_messages([
			"This is your inbox.",
			"Click an email on the left to inspect it.",
			"Press Accept if you believe the email is legitimate and safe.",
			"Press Deny if you believe the email is phishing or suspicious.",
			"You can also Ignore an email if you want to come back to it later."
		])


# -----------------------------------------
# EMAIL POOL
# All emails are defined here with difficulty
# 1 = obvious hint, 2 = subtle, 3 = very subtle
# -----------------------------------------
func _get_email_pool() -> Array:
	var pool: Array = []

	# --- LEGIT ---
	var l1 = EmailData.new()
	l1.sender = "boss@fbi.com"
	l1.subject = "Team Meeting"
	l1.body = "Reminder: we have our weekly 3PM team meeting today in conference room B. Please bring your status update."
	l1.is_phishing = false; l1.damage = 0; l1.reward = 15; l1.difficulty = 1
	pool.append(l1)

	var l2 = EmailData.new()
	l2.sender = "hr@fbi.gov"
	l2.subject = "Updated Holiday Schedule"
	l2.body = "Please find the updated holiday schedule for Q2 attached. No action required."
	l2.is_phishing = false; l2.damage = 0; l2.reward = 15; l2.difficulty = 1
	pool.append(l2)

	var l3 = EmailData.new()
	l3.sender = "it@fbi.gov"
	l3.subject = "Scheduled Maintenance Tonight"
	l3.body = "Systems will be down from 11PM to 1AM for routine maintenance. No action required."
	l3.is_phishing = false; l3.damage = 0; l3.reward = 15; l3.difficulty = 1
	pool.append(l3)

	var l4 = EmailData.new()
	l4.sender = "newsletter@techdigest.com"
	l4.subject = "Your Weekly Tech Digest"
	l4.body = "This week in tech: AI developments, new hardware releases, and cybersecurity updates."
	l4.is_phishing = false; l4.damage = 0; l4.reward = 10; l4.difficulty = 1
	pool.append(l4)

	var l5 = EmailData.new()
	l5.sender = "payroll@fbi.gov"
	l5.subject = "Your Pay Stub is Ready"
	l5.body = "Your latest pay stub is available in the employee portal at portal.fbi.gov. Log in to view it."
	l5.is_phishing = false; l5.damage = 0; l5.reward = 10; l5.difficulty = 2
	pool.append(l5)

	# --- PHISHING (difficulty 1 - obvious) ---
	var p1 = EmailData.new()
	p1.sender = "admin-secure@fb1.com"
	p1.subject = "Account Suspended"
	p1.body = "Your account has been SUSPENDED. Click immediately to restore access or lose your data forever!!!"
	p1.is_phishing = true; p1.damage = 25; p1.reward = 0; p1.difficulty = 1
	pool.append(p1)

	var p2 = EmailData.new()
	p2.sender = "support@paypai.com"
	p2.subject = "Unusual Activity Detected"
	p2.body = "We have locked your account due to suspicious login. Verify your identity IMMEDIATELY or lose access permanently."
	p2.is_phishing = true; p2.damage = 25; p2.reward = 0; p2.difficulty = 1
	pool.append(p2)

	var p3 = EmailData.new()
	p3.sender = "noreply@amaz0n-support.com"
	p3.subject = "Your Order Has Been Cancelled"
	p3.body = "Your recent order was flagged for fraud. Click here NOW to confirm your payment details and avoid account closure."
	p3.is_phishing = true; p3.damage = 20; p3.reward = 0; p3.difficulty = 1
	pool.append(p3)

	# --- PHISHING (difficulty 2 - subtle) ---
	var p4 = EmailData.new()
	p4.sender = "security@micros0ft-alert.com"
	p4.subject = "Your Password Expires Today"
	p4.body = "Your Microsoft account password expires today. Please reset it using the link below to maintain access."
	p4.is_phishing = true; p4.damage = 20; p4.reward = 0; p4.difficulty = 2
	pool.append(p4)

	var p5 = EmailData.new()
	p5.sender = "it-helpdesk@fbi-support.net"
	p5.subject = "Action Required: VPN Certificate Renewal"
	p5.body = "Your VPN certificate is expiring. Please download and install the attached renewal file before Friday."
	p5.is_phishing = true; p5.damage = 20; p5.reward = 0; p5.difficulty = 2
	pool.append(p5)

	# --- PHISHING (difficulty 3 - very subtle) ---
	var p6 = EmailData.new()
	p6.sender = "hr@fbi.gov.hr-portal.com"
	p6.subject = "Open Enrollment Reminder"
	p6.body = "This is your reminder to complete benefits open enrollment by end of week. Log in at the HR portal link below."
	p6.is_phishing = true; p6.damage = 30; p6.reward = 0; p6.difficulty = 3
	pool.append(p6)

	var p7 = EmailData.new()
	p7.sender = "payroll@fbi.gov.payroll-update.com"
	p7.subject = "Direct Deposit Update Required"
	p7.body = "Please verify your direct deposit information for the upcoming pay period. No changes will result in a delayed payment."
	p7.is_phishing = true; p7.damage = 30; p7.reward = 0; p7.difficulty = 3
	pool.append(p7)

	return pool


# -----------------------------------------
# SEED INBOX ON START
# -----------------------------------------
func _seed_initial_emails():
	var pool = _get_email_pool()
	var to_add = min(5, pool.size())
	pool.shuffle()
	for i in to_add:
		emails.append(pool[i])


# -----------------------------------------
# SPAWN NEW EMAIL ON TIMER
# Adjusts phishing ratio based on integrity
# -----------------------------------------
func _on_spawn_timer():
	if emails.size() >= MAX_INBOX:
		return

	var pool = _get_email_pool()
	var integrity = GameManager.system_integrity
	var phishing_chance: float
	if integrity > 60:
		phishing_chance = PHISHING_RATIO_HIGH
	elif integrity > 30:
		phishing_chance = PHISHING_RATIO_MEDIUM
	else:
		phishing_chance = PHISHING_RATIO_LOW

	# Filter pool by type based on chance roll
	var roll = randf()
	var candidates: Array
	if roll < phishing_chance:
		candidates = pool.filter(func(e): return e.is_phishing)
	else:
		candidates = pool.filter(func(e): return not e.is_phishing)

	if candidates.is_empty():
		return

	candidates.shuffle()
	var new_email = candidates[0]

	# Avoid exact duplicates already in inbox
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
func show_email_feedback(was_correct: bool):
	if current_email == null:
		return

	if was_correct:
		if current_email.is_phishing:
			if "immediately" in current_email.body.to_lower() or "suspended" in current_email.body.to_lower():
				Assistant.show_message("Correct. This was phishing because it used urgent language to pressure you.")
			elif ".com" in current_email.sender or ".net" in current_email.sender:
				Assistant.show_message("Correct. This sender address was suspicious and did not match a trusted FBI domain.")
			else:
				Assistant.show_message("Correct. You identified a phishing email.")
		else:
			Assistant.show_message("Correct. This email was legitimate and safe to accept.")
	else:
		if current_email.is_phishing:
			if "immediately" in current_email.body.to_lower() or "suspended" in current_email.body.to_lower():
				Assistant.show_message("Incorrect. This was phishing because it used urgent language to make you panic.")
			elif ".com" in current_email.sender or ".net" in current_email.sender:
				Assistant.show_message("Incorrect. This sender address was suspicious and should not have been trusted.")
			else:
				Assistant.show_message("Incorrect. That email showed signs of phishing.")
		else:
			Assistant.show_message("Incorrect. This email was actually legitimate, so it should not have been denied.")
func on_accept_pressed():
	if current_email == null:
		return

	if current_email.is_phishing:
		integrity_ui.lose_integrity(current_email.damage)
		hit_sound.play()
		show_email_feedback(false)
	else:
		show_email_feedback(true)

	remove_current_email()


func on_deny_pressed():
	if current_email == null:
		return

	if not current_email.is_phishing:
		integrity_ui.lose_integrity(8)
		hit_sound.play()
		show_email_feedback(false)
	else:
		show_email_feedback(true)

	remove_current_email()

func on_ignore_pressed():
	if current_email == null:
		return
	var ignored = current_email
	# Clear viewer but don't remove from inbox yet
	sender_label.text = ""
	subject_label.text = ""
	body_text.text = ""
	current_email = null
	# Return email after delay
	await get_tree().create_timer(IGNORE_RETURN_DELAY).timeout
	print("Ignored email returned: ", ignored.subject)


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
