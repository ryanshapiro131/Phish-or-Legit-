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
var email_pool: Array = []
var level_quota: int = 5
var is_open: bool = false

var triggered_emails: Dictionary = {
	"on_start": [],
	"on_first_correct": [],
	"on_first_wrong": [],
	"on_quota_half": []
}
var triggers_fired: Dictionary = {
	"on_first_correct": false,
	"on_first_wrong": false,
	"on_quota_half": false
}

# -----------------------------------------
# NODE REFS — updated for emailV2.tscn
# -----------------------------------------
@onready var email_list_container = $MainWindow/MainVBox/Content/ContentHBox/EmailListSectionPanel/EmailListSectionMargin/EmailList/EmailListVBox
@onready var sender_label = $MainWindow/MainVBox/Content/ContentHBox/EmailViewerPanel/MarginContainer/ViewerVBox/MarginContainer/VBoxContainer/SenderBar/SenderBarMargin/SenderBarHBox/SenderInfoVBox/SenderLabel
@onready var subject_label = $MainWindow/MainVBox/Content/ContentHBox/EmailViewerPanel/MarginContainer/ViewerVBox/MarginContainer/VBoxContainer/SubjectBar/SubjectMargin/SubjectLabel
@onready var body_text = $MainWindow/MainVBox/Content/ContentHBox/EmailViewerPanel/MarginContainer/ViewerVBox/MarginContainer/VBoxContainer/BodyArea/BodyMargin/BodyText
@onready var accept_button = $MainWindow/MainVBox/Content/ContentHBox/EmailViewerPanel/MarginContainer/ViewerVBox/ActionBar/ActionBarMargin/ActionBarHBox/AcceptButton
@onready var deny_button = $MainWindow/MainVBox/Content/ContentHBox/EmailViewerPanel/MarginContainer/ViewerVBox/ActionBar/ActionBarMargin/ActionBarHBox/DenyButton
@onready var ignore_button = $MainWindow/MainVBox/Content/ContentHBox/EmailViewerPanel/MarginContainer/ViewerVBox/ActionBar/ActionBarMargin/ActionBarHBox/IgnoreButton
@onready var integrity_ui = $MainWindow/MainVBox/BottomBar/BottomBarMargin/BottomBarHBox/IntegrityPanel/IntegrityMargin/IntegHBox/IntegrityUI
@onready var sender_icon = $MainWindow/MainVBox/Content/ContentHBox/EmailViewerPanel/MarginContainer/ViewerVBox/MarginContainer/VBoxContainer/SenderBar/SenderBarMargin/SenderBarHBox/ViewerSenderIconArea/ViewerSenderIcon
@onready var score                = $MainWindow/MainVBox/Content/ContentHBox/FolderSidebarPanel/FolderSidebarMargin/FolderSidebarVBox/Score
@onready var money_label          = $MainWindow/MainVBox/BottomBar/BottomBarMargin/BottomBarHBox/MoneyPanel/MoneyMargin/MoneyHBox/MoneyLabel
@onready var day_label: Label = $MainWindow/MainVBox/BottomBar/BottomBarMargin/BottomBarHBox/TimePanel/TimeMargin/TimeHBox/TimeVBox/DayLabel
@onready var spawn_timer: Timer   = $SpawnTimer
@onready var hit_sound            = $HitSound
@onready var correct_sound        = $CorrectSound
@onready var textbox              = $Textbox
@onready var notepad: CanvasLayer = $Notepad
@onready var inventory_widget: BaseButton = $MainWindow/MainVBox/Content/ContentHBox/WidgetSidebarPanel/WidgetSidebarMargin/WidgetSidebarVBox/InventoryWidget
@onready var folder_sidebar_vbox: VBoxContainer = $MainWindow/MainVBox/Content/ContentHBox/FolderSidebarPanel/FolderSidebarMargin/FolderSidebarVBox
@onready var inventory_popup: PopupPanel = $InventoryPopup
@onready var inventory_upgrades_richtext: RichTextLabel = $InventoryPopup/MarginContainer/VBox/UpgradesInventoryRichText
@onready var inventory_powerups_richtext: RichTextLabel = $InventoryPopup/MarginContainer/VBox/PowerUpsInventoryRichText
@onready var time_label: Label = $MainWindow/MainVBox/BottomBar/BottomBarMargin/BottomBarHBox/TimePanel/TimeMargin/TimeHBox/TimeVBox/TimeLabel


# -----------------------------------------
# READY
# -----------------------------------------
func _ready():
	body_text.bbcode_enabled = true
	connect_buttons()
	_load_level(GameManager.current_level)
	_seed_initial_emails()
	populate_email_list()
	GameManager.powerups_changed.connect(_refresh_inventory_text)
	inventory_widget.pressed.connect(_on_inventory_widget_pressed)
	$InventoryPopup/MarginContainer/VBox/CloseButton.pressed.connect(_on_inventory_close_pressed)
	_refresh_inventory_text()

	spawn_timer.wait_time = EMAIL_SPAWN_INTERVAL
	spawn_timer.timeout.connect(_on_spawn_timer)
	spawn_timer.start()

	day_label.text = "Day " + str(GameManager.current_level)
	_update_money_label()

	if not GameManager.tutorial_shown:
		await get_tree().create_timer(2.0).timeout
		textbox.queue_messages([
			"This is your email inbox. This is where you will be doing most of your work.",
			"Click on one of your emails, and look through its contents for anything suspicious.",
			"If it all looks good, you can hit the green accept button.",
			"If there's anything suspicious, you should hit the red deny button.",
			"And if you are unsure, you can hit the orange ignore button to come back to it later.",
			"Give some emails a try and I'll check back with you soon."
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
	GameManager.tick_hyperlink_analyzer(_delta)
	score.text = "Correct Emails: " + str(GameManager.correct_emails) + "/" + str(level_quota)
	_update_hyperlink_countdown_label()
	if inventory_popup.visible:
		_refresh_inventory_text()


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

	for key in triggers_fired:
		triggers_fired[key] = false
	for key in triggered_emails:
		triggered_emails[key] = []

	for e in data["emails"]:
		var email = EmailData.new()
		email.sender      = e["sender"]
		email.subject     = e["subject"]
		email.body        = e["body"]
		email.is_phishing = e["is_phishing"]
		email.damage      = e["damage"]
		email.reward      = e["reward"]
		email.difficulty  = e["difficulty"]
		email.icon        = e.get("icon", "Adam_16x16.png")
		email.trigger     = e.get("trigger", "none")

		if email.trigger == "none":
			email_pool.append(email)
		else:
			triggered_emails[email.trigger].append(email)

	for email in triggered_emails["on_start"]:
		emails.append(email)


func _fire_trigger(trigger: String):
	if triggers_fired.get(trigger, true):
		return
	triggers_fired[trigger] = true
	for email in triggered_emails[trigger]:
		emails.append(email)
		_add_email_button(email)


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
	body_text.text = _apply_spam_highlights(email.body)
	sender_icon.texture = load("res://assets/icons/" + email.icon)


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
		if GameManager.current_level == 1 and not GameManager.feedback_false_negative_shown:
			GameManager.feedback_false_negative_shown = true
			await get_tree().create_timer(1.0).timeout
			textbox.queue_messages([
				"That email was from a hacker!",
				"A dead giveaway is the sender address — look for anything that isn't @fbi.gov.",
				"Misspelled domains like 'fb1.com' or 'fbi.com' instead of 'fbi.gov' are a red flag."
			])
	else:
		GameManager.correct_emails += 1
		correct_sound.play()
		GameManager.add_salary_for_correct_answer(current_email.reward)
		_update_money_label()
		_fire_trigger("on_first_correct")
		_check_quota()
		if GameManager.current_level == 1 and not GameManager.feedback_true_negative_shown:
			GameManager.feedback_true_negative_shown = true
			await get_tree().create_timer(0.5).timeout
			textbox.queue_messages([
				"Nice work! That one was legitimate.",
				"Emails from @fbi.gov addresses with no urgent requests or suspicious links are usually safe to accept."
			])

	remove_current_email()


func on_deny_pressed():
	if current_email == null:
		return

	if not current_email.is_phishing:
		_handle_wrong_answer(8)
		if GameManager.current_level == 1 and not GameManager.feedback_false_positive_shown:
			GameManager.feedback_false_positive_shown = true
			await get_tree().create_timer(1.0).timeout
			textbox.queue_messages([
				"That email was actually legitimate!",
				"Denying real emails causes disruption and loses us valuable time.",
				"If the sender is from @fbi.gov and there are no suspicious requests, it is probably safe to accept."
			])
	else:
		correct_sound.play()
		GameManager.correct_emails += 1
		GameManager.add_salary_for_correct_answer(current_email.reward)
		_update_money_label()
		_fire_trigger("on_first_correct")
		_check_quota()
		if GameManager.current_level == 1 and not GameManager.feedback_true_positive_shown:
			GameManager.feedback_true_positive_shown = true
			await get_tree().create_timer(0.5).timeout
			textbox.queue_messages([
				"Great catch! That was a phishing attempt.",
				"Always be suspicious of emails asking you to click links, download files, or verify credentials.",
				"The more of these you catch, the safer our systems stay."
			])

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
	if GameManager.consume_ai_firewall():
		print("AI Firewall blocked damage!")
	else:
		integrity_ui.lose_integrity(damage)
	GameManager.disable_grant()
	_fire_trigger("on_first_wrong")
	hit_sound.play()


# -----------------------------------------
# CHECK QUOTA
# -----------------------------------------
func _check_quota():
	if GameManager.correct_emails >= level_quota / 2 and not triggers_fired["on_quota_half"]:
		_fire_trigger("on_quota_half")
	if GameManager.correct_emails >= level_quota:
		spawn_timer.stop()
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/results.tscn")


# -----------------------------------------
# HELPERS
# -----------------------------------------
func _update_money_label():
	money_label.text = "Salary: $" + str(GameManager.salary)

func _update_hyperlink_countdown_label() -> void:
	if GameManager.is_hyperlink_analyzer_active():
		var sec := int(ceil(GameManager.get_hyperlink_time_remaining()))
		var mm := sec / 60
		var ss := sec % 60
		time_label.text = "Analyzer %02d:%02d" % [mm, ss]
	else:
		time_label.text = "3:00 PM"

func _on_inventory_widget_pressed() -> void:
	_refresh_inventory_text()
	await get_tree().process_frame
	var gr := folder_sidebar_vbox.get_global_rect()
	var r := Rect2i(int(gr.position.x), int(gr.position.y), int(gr.size.x), int(gr.size.y))
	inventory_popup.popup(r)

func _on_inventory_close_pressed() -> void:
	inventory_popup.hide()

func _join_inventory_lines(lines: PackedStringArray) -> String:
	var out := ""
	for i in range(lines.size()):
		if i > 0:
			out += "\n"
		out += lines[i]
	return out

func _refresh_inventory_text() -> void:
	var upgrade_lines: PackedStringArray = []
	if GameManager.has_spam_filter_upgrade:
		upgrade_lines.append("[b]Spam Filter[/b] — keyword highlights")
	if GameManager.has_encrypted_backup_upgrade:
		if GameManager.encrypted_backup_charges > 0:
			upgrade_lines.append("[b]Encrypted Backup[/b] — one restore available if integrity hits 0")
		else:
			upgrade_lines.append("[b]Encrypted Backup[/b] — already used this run")
	if upgrade_lines.is_empty():
		upgrade_lines.append("[i]No upgrades yet — buy from the shop on the desktop.[/i]")

	var powerup_lines: PackedStringArray = []
	if GameManager.grant_tier > 0:
		powerup_lines.append("[b]Grant[/b] — active; streak bonus +$5, +$10, +$15, then +$20 max until you miss one")
	if GameManager.encrypted_storage_tier > 0:
		powerup_lines.append("[b]Encrypted Storage[/b] ×%d — Regain 30 health" % GameManager.encrypted_storage_tier)
	if GameManager.ai_firewall_charges > 0:
		powerup_lines.append("[b]AI Firewall[/b] — %d charge(s)" % GameManager.ai_firewall_charges)
	if GameManager.is_hyperlink_analyzer_active():
		powerup_lines.append("[b]Hyperlink Analyzer[/b] — active %ds left; counts down only while in email view" % int(ceil(GameManager.get_hyperlink_time_remaining())))
	else:
		powerup_lines.append("[color=#aaaaaa]Hyperlink Analyzer — inactive (90s timed buff from shop; timer runs only on email screen)[/color]")
	if powerup_lines.is_empty():
		powerup_lines.append("[i]No power-ups active.[/i]")

	inventory_upgrades_richtext.text = _join_inventory_lines(upgrade_lines)
	inventory_powerups_richtext.text = _join_inventory_lines(powerup_lines)

func _apply_spam_highlights(text: String) -> String:
	if not GameManager.has_spam_filter_upgrade:
		return text
	var out := text
	var keywords := ["urgent", "account suspended", "verify", "password", "click here", "immediately"]
	for key in keywords:
		var pattern: String = "(?i)\\b" + String(key).replace(" ", "\\s+") + "\\b"
		var regex := RegEx.new()
		if regex.compile(pattern) == OK:
			out = regex.sub(out, "[color=#ffd24d]$0[/color]", true)
	return out

func remove_current_email():
	sender_label.text = ""
	subject_label.text = ""
	body_text.text = ""
	if current_email in email_buttons:
		email_buttons[current_email].queue_free()
		email_buttons.erase(current_email)
	emails.erase(current_email)
	current_email = null


func _on_notepad_button_pressed() -> void:
	is_open = !is_open
	if is_open:
		notepad.notepad_panel.show()
		notepad.text_edit.grab_focus()
	else:
		notepad.notepad_panel.hide()


func _on_text_changed():
	# Save to GameManager every time the player types
	GameManager.notepad_text = notepad.text_edit.text
