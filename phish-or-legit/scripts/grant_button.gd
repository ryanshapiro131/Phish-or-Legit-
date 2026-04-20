extends Button

@export var cost: int = 50
@export var power_up_name: String = "Grant"

@onready var buy_sound = $"../BuySound"

func _ready() -> void:
	pressed.connect(_on_pressed)
	GameManager.powerups_changed.connect(_sync_button_state)
	_sync_button_state()

func _sync_button_state() -> void:
	var grant_active: bool = GameManager.grant_tier > 0
	disabled = grant_active
	text = "Purchased" if grant_active else "Buy"
	modulate = Color(0.6, 0.6, 0.6, 1.0) if grant_active else Color(1, 1, 1, 1)

func _on_pressed() -> void:
	if GameManager.salary < cost:
		print("Not enough money!")
		return
	if not GameManager.try_purchase_grant():
		print("Grant already active!")
		return
	GameManager.salary -= cost
	print("Bought:", power_up_name)
	buy_sound.play()
	_sync_button_state()
