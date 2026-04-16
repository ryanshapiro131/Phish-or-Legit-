extends Button

@export var cost: int = 100
@export var power_up_name: String = "Spam Filter"

@onready var buy_sound = $"../BuySound"

func _ready() -> void:
	pressed.connect(_on_pressed)
	GameManager.powerups_changed.connect(_refresh_state)
	_refresh_state()


func _refresh_state() -> void:
	var purchased: bool = GameManager.has_spam_filter_upgrade
	disabled = purchased
	text = "Purchased" if purchased else "Buy"
	modulate = Color(0.6, 0.6, 0.6, 1.0) if purchased else Color(1, 1, 1, 1)

func _on_pressed() -> void:
	if GameManager.has_spam_filter_upgrade:
		_refresh_state()
		return
	if GameManager.salary < cost:
		print("Not enough money!")
		return
	if not GameManager.try_purchase_spam_filter():
		_refresh_state()
		return
	GameManager.salary -= cost
	print("Bought:", power_up_name)
	buy_sound.play()
	_refresh_state()
