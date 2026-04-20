extends Button

@export var cost: int = 100
@export var power_up_name: String = "Spam Filter"

@onready var buy_sound = $"../BuySound"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if GameManager.salary >= cost:
		GameManager.salary -= cost
		print("Bought:", power_up_name)
		buy_sound.play()
		# Add your power-up activation logic here
	else:
		print("Not enough money!")
