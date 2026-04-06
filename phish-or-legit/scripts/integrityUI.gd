extends Control
 
@onready var integrity_bar: ProgressBar = $IntegrityBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var percent_label: Label = $SystemIntegrityLabel
 
func _ready():
	_sync_from_game_manager()
 
# Call this any time you need the UI to reflect the current GameManager value
func _sync_from_game_manager():
	integrity_bar.value = GameManager.system_integrity
	percent_label.text = "System Integrity:"
	update_bar_color()
 
func lose_integrity(amount: int):
	GameManager.lose_integrity(amount)
	integrity_bar.value = GameManager.system_integrity
	update_bar_color()
	animation_player.play("integrity_hit")
 
func update_bar_color():
	var fill_style = integrity_bar.get_theme_stylebox("fill")
	if GameManager.system_integrity > 60:
		fill_style.bg_color = Color(0, 1, 0)   # green
	elif GameManager.system_integrity > 30:
		fill_style.bg_color = Color(1, 1, 0)   # yellow
	else:
		fill_style.bg_color = Color(1, 0, 0)   # red
