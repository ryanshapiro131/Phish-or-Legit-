extends Control

@onready var integrity_bar: ProgressBar = $IntegrityBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var percent_label: Label = $SystemIntegrityLabel

func _ready():
	GameManager.integrity_changed.connect(_sync_from_game_manager)
	_sync_from_game_manager()

func _sync_from_game_manager():
	integrity_bar.max_value = GameManager.max_system_integrity
	integrity_bar.value = GameManager.system_integrity
	percent_label.text = "System Integrity:"
	update_bar_color()

func lose_integrity(amount: int):
	GameManager.lose_integrity(amount)
	animation_player.play("integrity_hit")

func update_bar_color():
	var fill_style = integrity_bar.get_theme_stylebox("fill")
	if fill_style == null:
		return
	var max_v: float = float(GameManager.max_system_integrity)
	if max_v <= 0.0:
		return
	var ratio: float = float(GameManager.system_integrity) / max_v
	if ratio > 0.6:
		fill_style.bg_color = Color(0, 1, 0)
	elif ratio > 0.3:
		fill_style.bg_color = Color(1, 1, 0)
	else:
		fill_style.bg_color = Color(1, 0, 0)
