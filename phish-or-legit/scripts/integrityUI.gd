extends Control
 
@onready var integrity_bar: TextureProgressBar = $TextureProgressBar
@onready var animation_player: AnimationPlayer = $AnimationPlayer
 
const GREEN_PROGRESS = preload("uid://be45i7efcbeba")
const YELLOW_PROGRESS = preload("uid://carq4c45vi5")
const RED_PROGRESS = preload("uid://bn1sht7ywn5ra")


func _ready():
	GameManager.integrity_changed.connect(_sync_from_game_manager)
	_sync_from_game_manager()
 
# Call this any time you need the UI to reflect the current GameManager value
func _sync_from_game_manager():
	integrity_bar.value = GameManager.system_integrity
	update_bar_color()
 
func lose_integrity(amount: int):
	GameManager.lose_integrity(amount)
	integrity_bar.value = GameManager.system_integrity
	update_bar_color()
	animation_player.play("integrity_hit")
 
func update_bar_color():
	if GameManager.system_integrity > 60:
		integrity_bar.texture_progress = GREEN_PROGRESS   # green
	elif GameManager.system_integrity > 30:
		integrity_bar.texture_progress = YELLOW_PROGRESS   # yellow
	else:
		integrity_bar.texture_progress = RED_PROGRESS   # red
