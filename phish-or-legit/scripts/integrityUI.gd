extends Control

@onready var integrity_bar = $IntegrityBar
@onready var animation_player = $AnimationPlayer
@onready var percent_label: Label = $SystemIntegrityLabel

var integrity = 100


func _ready():
	integrity_bar.value = integrity
	#percent_label.text = str(integrity) + "%"
	update_bar_color()


func lose_integrity(amount := 10):
	integrity = max(integrity - amount, 0)

	integrity_bar.value = integrity
	#percent_label.text = str(integrity) + "%"

	update_bar_color()
	animation_player.play("integrity_hit")


func update_bar_color():
	var fill_style = integrity_bar.get_theme_stylebox("fill")

	if integrity > 60:
		fill_style.bg_color = Color(0, 1, 0) # green
	elif integrity > 30:
		fill_style.bg_color = Color(1, 1, 0) # yellow
	else:
		fill_style.bg_color = Color(1, 0, 0) # red
