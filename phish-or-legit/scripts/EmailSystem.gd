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

const REWARD_BY_DIFFICULTY: Dictionary = {
	1: 15,
	2: 25,
	3: 40,
	4: 55,
}

const REWARD_DEFAULT_DIFFICULTY: int = 1

const SPAM_KEYWORDS: Array[String] = [
	"account suspended",
	"verify your identity",
	"suspicious activity",
	"click immediately",
	"act now",
	"expires in",
	"immediate action is required",
	"your account will be suspended",
	"delayed payments for the entire department",
	"confidential audit process",
]

const SPAM_KEYWORDS_EXTRA: Array[String] = [
	"entering your credentials",
	"click here to upload",
	"click here to view it",
	"do not discuss this request with others",
	"critical vulnerability",
	"compliance certification is overdue",
	"direct deposit update required",
]

# -----------------------------------------
# STATE
# -----------------------------------------
var emails: Array = []
var current_email: EmailData = null
var email_buttons: Dictionary = {}
var email_pool: Array = []   # full pool loaded from JSON
var level_quota: int = 5
var _last_hyperlink_analyzer_active: bool = false

# -----------------------------------------
# NODE REFS
# -----------------------------------------
@onready var email_list_container = $MainVBox/Content/EmailListSectionPanel/EmailListSectionMargin/EmailList/EmailListVBox
@onready var sender_label         = $MainVBox/Content/EmailViewerPanel/ViewerVBox/SenderBar/SenderBarMargin/SenderBarHBox/SenderInfoVBox/SenderLabel
@onready var subject_label        = $MainVBox/Content/EmailViewerPanel/ViewerVBox/SubjectBar/SubjectMargin/SubjectLabel
@onready var body_text: RichTextLabel = $MainVBox/Content/EmailViewerPanel/ViewerVBox/BodyArea/BodyMargin/BodyText
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
@onready var folder_sidebar_vbox: VBoxContainer = $MainVBox/Content/FolderSidebarPanel/FolderSidebarMargin/FolderSidebarVBox
@onready var hyperlink_countdown_label: Label = $MainVBox/BottomBar/BottomBarMargin/BottomBarHBox/AnalyzerArea/HyperlinkCountdown

@onready var hyperlink_analyzer_bar: PanelContainer = $MainVBox/Content/EmailViewerPanel/ViewerVBox/HyperlinkAnalyzerBar
@onready var hyperlink_analyzer_label: Label = $MainVBox/Content/EmailViewerPanel/ViewerVBox/HyperlinkAnalyzerBar/HyperlinkAnalyzerMargin/HyperlinkAnalyzerLabel

@onready var inventory_popup: PopupPanel = $InventoryPopup
@onready var inventory_richtext: RichTextLabel = $InventoryPopup/MarginContainer/VBox/InventoryRichText
@onready var inventory_widget: Button = $MainVBox/Content/WidgetSidebarPanel/WidgetSidebarMargin/WidgetSidebarVBox/InventoryWidget


# -----------------------------------------
# READY
# -----------------------------------------
func _ready():
	body_text.bbcode_enabled = true
	GameManager.powerups_changed.connect(_refresh_inventory_text)
	inventory_widget.pressed.connect(_on_inventory_widget_pressed)
	$InventoryPopup/MarginContainer/VBox/CloseButton.pressed.connect(_on_inventory_close_pressed)
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
	GameManager.tick_hyperlink_analyzer(_delta)
	score.text = "Correct Emails: " + str(GameManager.correct_emails) + "/" + str(level_quota)
	_update_hyperlink_analyzer_bar()
	_update_hyperlink_countdown_label()
	if inventory_popup.visible:
		_refresh_inventory_text()
	if current_email == null:
		return
	var active := GameManager.is_hyperlink_analyzer_active()
	if _last_hyperlink_analyzer_active and not active:
		_refresh_email_body_display()
	_last_hyperlink_analyzer_active = active


func _update_hyperlink_analyzer_bar():
	var active := GameManager.is_hyperlink_analyzer_active()
	hyperlink_analyzer_bar.visible = active
	if not active:
		return
	var sec := int(ceil(GameManager.get_hyperlink_time_remaining()))
	hyperlink_analyzer_label.text = "HYPERLINK ANALYZER — %ds left — non-fbi.gov links and email addresses are highlighted in RED." % sec

func _update_hyperlink_countdown_label():
	if GameManager.is_hyperlink_analyzer_active():
		var sec := int(ceil(GameManager.get_hyperlink_time_remaining()))
		var mm := sec / 60
		var ss := sec % 60
		hyperlink_countdown_label.text = "Analyzer %02d:%02d" % [mm, ss]
		hyperlink_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35, 1.0))
	else:
		hyperlink_countdown_label.text = "Analyzer --:--"
		hyperlink_countdown_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 1.0))


func _on_inventory_widget_pressed():
	_refresh_inventory_text()
	await get_tree().process_frame
	var gr := folder_sidebar_vbox.get_global_rect()
	var r := Rect2i(int(gr.position.x), int(gr.position.y), int(gr.size.x), int(gr.size.y))
	inventory_popup.popup(r)


func _on_inventory_close_pressed():
	inventory_popup.hide()


func _join_inventory_lines(lines: PackedStringArray) -> String:
	var out := ""
	for i in range(lines.size()):
		if i > 0:
			out += "\n"
		out += lines[i]
	return out


func _refresh_inventory_text():
	var lines: PackedStringArray = []
	if GameManager.has_spam_filter_upgrade:
		lines.append("[b]Spam Filter[/b] — keyword highlights")
	if GameManager.grant_tier > 0:
		lines.append("[b]Grant[/b] — active; streak bonus +$5, +$10, +$15, then +$20 max until you miss one")
	if GameManager.encrypted_storage_tier > 0:
		lines.append("[b]Encrypted Storage[/b] ×%d — +%d max integrity each" % [GameManager.encrypted_storage_tier, 30])
	if GameManager.has_encrypted_backup_upgrade:
		if GameManager.encrypted_backup_charges > 0:
			lines.append("[b]Encrypted Backup[/b] — one restore available if integrity hits 0")
		else:
			lines.append("[b]Encrypted Backup[/b] — already used this run")
	if GameManager.ai_firewall_charges > 0:
		lines.append("[b]AI Firewall[/b] — %d charge(s)" % GameManager.ai_firewall_charges)
	if lines.is_empty():
		lines.append("[i]No persistent upgrades yet — buy from the shop on the desktop.[/i]")
	lines.append("[i]────────[/i]")
	if GameManager.is_hyperlink_analyzer_active():
		lines.append("[b]Hyperlink Analyzer[/b] — active %ds left; counts down only while in email view; flags non-fbi.gov links and email domains in red" % int(ceil(GameManager.get_hyperlink_time_remaining())))
	else:
		lines.append("[color=#aaaaaa]Hyperlink Analyzer — inactive (90s timed buff from shop; timer runs only on email screen)[/color]")
	inventory_richtext.text = _join_inventory_lines(lines)


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
		email.difficulty = e["difficulty"]
		email.icon 		 = e.get("icon", "Adam_16x16.png")
		email.reward = REWARD_BY_DIFFICULTY.get(email.difficulty, REWARD_BY_DIFFICULTY[REWARD_DEFAULT_DIFFICULTY])
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

	var max_i: int = max(GameManager.max_system_integrity, 1)
	var ratio: float = float(GameManager.system_integrity) / float(max_i)
	var phishing_chance: float
	if ratio > 0.6:
		phishing_chance = PHISHING_RATIO_HIGH
	elif ratio > 0.3:
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
	_last_hyperlink_analyzer_active = GameManager.is_hyperlink_analyzer_active()
	sender_label.text = "From: " + email.sender
	_refresh_sender_display()
	subject_label.text = "Subject: " + email.subject
	body_text.text = _build_email_body_bbcode(email.body)
	sender_icon.texture = load("res://assets/icons/" + email.icon)

	if not GameManager.office_intro_shown:
		GameManager.office_intro_shown = true
		await get_tree().create_timer(3.0).timeout
		textbox.queue_messages([
			"Your job is to filter out phishing emails from hackers trying to steal our data.",
			"Check the sender carefully — if it's not from @fbi.gov, be suspicious.",
			"Give some emails a try and I'll check back with you soon."
		])


func _escape_bbcode_text(s: String) -> String:
	return s.replace("[", "[lb]").replace("]", "[rb]")


func _regex_escape_literals(s: String) -> String:
	var to_escape := [".", "^", "$", "*", "+", "?", "(", ")", "[", "]", "{", "}", "|", "\\"]
	var out := ""
	for i in range(s.length()):
		var c := s.substr(i, 1)
		if c in to_escape:
			out += "\\" + c
		else:
			out += c
	return out


func _apply_spam_keyword_highlights(text: String) -> String:
	var phrases: Array = SPAM_KEYWORDS.duplicate()
	var result := text
	for phrase in phrases:
		var r := RegEx.new()
		r.compile("(?i)" + _regex_escape_literals(str(phrase)))
		result = r.sub(result, "[color=#ff8800]$0[/color]", true)
	return result

func _sender_domain(sender: String) -> String:
	var s := sender.strip_edges().to_lower()
	var at := s.rfind("@")
	if at < 0:
		return ""
	return s.substr(at + 1)

func _is_suspicious_sender_domain(sender: String) -> bool:
	var domain := _sender_domain(sender)
	if domain == "":
		return false
	return not _is_trusted_fbi_host(domain)

func _refresh_sender_display():
	if current_email == null:
		return
	var suspicious := GameManager.is_hyperlink_analyzer_active() and _is_suspicious_sender_domain(current_email.sender)
	if suspicious:
		sender_label.text = "From: " + current_email.sender + "   [SUSPICIOUS DOMAIN]"
		sender_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 1.0))
	else:
		sender_label.text = "From: " + current_email.sender
		sender_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))


func _host_from_url(url: String) -> String:
	var u := url.to_lower().strip_edges()
	u = u.replace("https://", "").replace("http://", "")
	var slash := u.find("/")
	if slash >= 0:
		u = u.substr(0, slash)
	var at := u.find("@")
	if at >= 0:
		u = u.substr(at + 1)
	var colon := u.find(":")
	if colon >= 0:
		u = u.substr(0, colon)
	if u.begins_with("www."):
		u = u.substr(4)
	return u


func _is_trusted_fbi_host(host: String) -> bool:
	var h := host.to_lower()
	if h.begins_with("www."):
		h = h.substr(4)
	return h == "fbi.gov" or h.ends_with(".fbi.gov")


func _wrap_suspicious_link(url: String) -> String:
	return "[b][color=#ff2222][url=" + url + "]" + url + "[/url][/color][/b]"

func _wrap_suspicious_email(email_addr: String) -> String:
	return "[b][color=#ff4444]" + email_addr + "[/color][/b]"


func _highlight_http_urls(text: String) -> String:
	var r := RegEx.new()
	r.compile("https?://[^\\s\\)\\]\\>]+")
	var matches := r.search_all(text)
	if matches.is_empty():
		return text
	var out := text
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var url := m.get_string()
		var host := _host_from_url(url)
		if _is_trusted_fbi_host(host):
			continue
		var start := m.get_start()
		var end := m.get_end()
		out = out.substr(0, start) + _wrap_suspicious_link(url) + out.substr(end, out.length() - end)
	return out


func _highlight_www_urls(text: String) -> String:
	var r := RegEx.new()
	r.compile("(?i)www\\.[^\\s\\)\\]\\>]+")
	var matches := r.search_all(text)
	if matches.is_empty():
		return text
	var out := text
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var url := m.get_string()
		var host := _host_from_url(url)
		if _is_trusted_fbi_host(host):
			continue
		var start := m.get_start()
		var end := m.get_end()
		out = out.substr(0, start) + _wrap_suspicious_link(url) + out.substr(end, out.length() - end)
	return out


func _apply_hyperlink_highlights(text: String) -> String:
	var out := _highlight_http_urls(text)
	out = _highlight_www_urls(out)
	out = _highlight_email_addresses(out)
	return out

func _email_domain(email_addr: String) -> String:
	var s := email_addr.to_lower().strip_edges()
	var at := s.rfind("@")
	if at < 0:
		return ""
	return s.substr(at + 1)

func _highlight_email_addresses(text: String) -> String:
	var r := RegEx.new()
	r.compile("(?i)[a-z0-9._%+\\-]+@[a-z0-9.\\-]+\\.[a-z]{2,}")
	var matches := r.search_all(text)
	if matches.is_empty():
		return text
	var out := text
	for i in range(matches.size() - 1, -1, -1):
		var m: RegExMatch = matches[i]
		var addr := m.get_string()
		var domain := _email_domain(addr)
		if domain == "" or _is_trusted_fbi_host(domain):
			continue
		var start := m.get_start()
		var end := m.get_end()
		out = out.substr(0, start) + _wrap_suspicious_email(addr) + out.substr(end, out.length() - end)
	return out


func _raw_has_urls(raw: String) -> bool:
	var r := raw.to_lower()
	return r.find("http://") >= 0 or r.find("https://") >= 0 or r.find("www.") >= 0 or r.find("@") >= 0


func _build_email_body_bbcode(raw: String) -> String:
	var t := _escape_bbcode_text(raw)
	if GameManager.has_spam_filter_upgrade:
		t = _apply_spam_keyword_highlights(t)
	if GameManager.is_hyperlink_analyzer_active():
		var before := t
		t = _apply_hyperlink_highlights(t)
		if before == t and not _raw_has_urls(raw):
			t = "[color=#999999][i]Hyperlink Analyzer: no links or email addresses in this message — nothing to scan.[/i][/color]\n\n" + t
	return t

func _refresh_email_body_display():
	if current_email == null:
		return
	_refresh_sender_display()
	body_text.text = _build_email_body_bbcode(current_email.body)


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
		GameManager.add_salary_for_correct_answer(current_email.reward)
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
		GameManager.add_salary_for_correct_answer(current_email.reward)
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
	GameManager.disable_grant()
	if GameManager.consume_ai_firewall():
		_show_first_wrong_tutorial_if_needed()
		return
	integrity_ui.lose_integrity(damage)
	hit_sound.play()
	$MainVBox/BottomBar/BottomBarMargin/BottomBarHBox/IntegrityPanel/IntegrityMargin/IntegrityUI/AnimationPlayer.play("integrity_hit")
	_show_first_wrong_tutorial_if_needed()


func _show_first_wrong_tutorial_if_needed():
	if GameManager.office_intro_wrong_choice:
		return
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
