extends Button

@export var cost: int = 50
@export var power_up_name: String = "Grant"

func _ready() -> void:
	pressed.connect(_on_pressed)

func _on_pressed() -> void:
	if GameManager.salary >= cost:
		GameManager.salary -= cost
		print("Bought:", power_up_name)
		# Add your power-up activation logic here
	else:
		print("Not enough money!")
