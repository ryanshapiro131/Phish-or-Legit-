extends Button

@export var cost: int = 100
@export var power_up_name: String = "Encrypted Storage"

@onready var buy_sound = $"../BuySound"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if GameManager.salary < cost:
		print("Not enough money!")
		return
	GameManager.try_purchase_encrypted_storage()
	GameManager.salary -= cost
	print("Bought:", power_up_name)
	buy_sound.play()
