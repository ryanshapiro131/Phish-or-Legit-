extends Node

const BASE_MAX_INTEGRITY: int = 100
const ENCRYPTED_STORAGE_BONUS: int = 30
const BACKUP_RESTORE_PERCENT_OF_MAX: float = 0.5
const HYPERLINK_ANALYZER_DURATION_SEC: float = 90.0
const GRANT_BONUS_PER_STEP: int = 5
const GRANT_BONUS_MAX_STEP: int = 4

signal integrity_changed
signal powerups_changed

var system_integrity: int = 100
var max_system_integrity: int = BASE_MAX_INTEGRITY

var salary: int = 0
var office_intro_shown: bool = false
var office_intro_wrong_choice: bool = false

var current_level: int = 1
var correct_emails: int = 0
var incorrect_emails: int = 0
var current_quota: int = 5

var notepad_text: String = ""

# Upgrades are one-time purchases; power-ups can be rebought.
var has_spam_filter_upgrade: bool = false
var grant_tier: int = 0
var encrypted_storage_tier: int = 0
var hyperlink_analyzer_time_left_sec: float = 0.0
var ai_firewall_charges: int = 0
var encrypted_backup_charges: int = 0
var has_encrypted_backup_upgrade: bool = false
var correct_streak: int = 0

@onready var bg_music: AudioStreamPlayer2D = $BGMusic

func _ready():
	bg_music.play()

func is_hyperlink_analyzer_active() -> bool:
	return hyperlink_analyzer_time_left_sec > 0.0

func get_hyperlink_time_remaining() -> float:
	return max(0.0, hyperlink_analyzer_time_left_sec)

func activate_hyperlink_analyzer(duration_sec: float) -> void:
	hyperlink_analyzer_time_left_sec += duration_sec
	powerups_changed.emit()

func tick_hyperlink_analyzer(delta: float) -> void:
	if hyperlink_analyzer_time_left_sec <= 0.0:
		return
	hyperlink_analyzer_time_left_sec = max(0.0, hyperlink_analyzer_time_left_sec - delta)
	if hyperlink_analyzer_time_left_sec == 0.0:
		powerups_changed.emit()

func consume_ai_firewall() -> bool:
	if ai_firewall_charges <= 0:
		return false
	ai_firewall_charges -= 1
	powerups_changed.emit()
	return true

func reset_grant_streak() -> void:
	if grant_tier > 0:
		correct_streak = 0


func disable_grant() -> void:
	if grant_tier > 0:
		grant_tier = 0
		correct_streak = 0
		powerups_changed.emit()

func add_salary_for_correct_answer(base_reward: int) -> void:
	if grant_tier > 0:
		correct_streak += 1
		var streak_step: int = mini(correct_streak, GRANT_BONUS_MAX_STEP)
		var streak_bonus: int = streak_step * GRANT_BONUS_PER_STEP
		salary += base_reward + streak_bonus
	else:
		salary += base_reward

func lose_integrity(amount: int):
	system_integrity = max(system_integrity - amount, 0)
	print("Integrity:", system_integrity)
	integrity_changed.emit()
	if system_integrity <= 0:
		if encrypted_backup_charges > 0:
			encrypted_backup_charges -= 1
			system_integrity = int(max_system_integrity * BACKUP_RESTORE_PERCENT_OF_MAX)
			print("Restored from encrypted backup!")
			integrity_changed.emit()
			powerups_changed.emit()
			return
		game_over()

func add_salary(amount: int):
	salary += amount

func advance_level():
	current_level += 1
	correct_emails = 0
	incorrect_emails = 0

func reset():
	system_integrity = 100
	max_system_integrity = BASE_MAX_INTEGRITY
	salary = 0
	current_level = 1
	correct_emails = 0
	incorrect_emails = 0
	office_intro_shown = false
	office_intro_wrong_choice = false
	notepad_text = ""
	_reset_powerups()
	integrity_changed.emit()

func _reset_powerups():
	has_spam_filter_upgrade = false
	grant_tier = 0
	encrypted_storage_tier = 0
	hyperlink_analyzer_time_left_sec = 0.0
	ai_firewall_charges = 0
	encrypted_backup_charges = 0
	has_encrypted_backup_upgrade = false
	correct_streak = 0

func game_over():
	print("NETWORK COMPROMISED")
	# get_tree().change_scene_to_file("res://scenes/game_over.tscn")

# --- Shop: always succeeds (caller checks salary) ---
func try_purchase_spam_filter() -> bool:
	if has_spam_filter_upgrade:
		return false
	has_spam_filter_upgrade = true
	powerups_changed.emit()
	return true

func try_purchase_hyperlink_analyzer() -> bool:
	activate_hyperlink_analyzer(HYPERLINK_ANALYZER_DURATION_SEC)
	powerups_changed.emit()
	return true

func try_purchase_grant() -> bool:
	if grant_tier > 0:
		return false
	grant_tier = 1
	correct_streak = 0
	powerups_changed.emit()
	return true

func try_purchase_encrypted_storage() -> bool:
	encrypted_storage_tier += 1
	max_system_integrity += ENCRYPTED_STORAGE_BONUS
	system_integrity = min(system_integrity + ENCRYPTED_STORAGE_BONUS, max_system_integrity)
	integrity_changed.emit()
	powerups_changed.emit()
	return true

func try_purchase_encrypted_backup() -> bool:
	if has_encrypted_backup_upgrade:
		return false
	has_encrypted_backup_upgrade = true
	encrypted_backup_charges += 1
	powerups_changed.emit()
	return true

func try_purchase_ai_firewall() -> bool:
	ai_firewall_charges += 1
	powerups_changed.emit()
	return true
