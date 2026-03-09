extends Node

var system_integrity: int = 100
var salary: int = 0


func take_damage(amount: int):
	system_integrity -= amount
	print("Integrity:", system_integrity)

	if system_integrity <= 0:
		game_over()


func add_salary(amount: int):
	salary += amount
	print("Salary:", salary)


func game_over():
	print("NETWORK COMPROMISED")
