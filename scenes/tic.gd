extends Node2D

@onready var label: Label = $Label

const chart = {
	0: "",
	1: "X",
	2: "O"
}
@export var cell_num = 0
signal pressed_action(cell_num: int)

func set_player(player: int) -> void:
	label.text = chart[player]

func _on_button_pressed() -> void:
	pressed_action.emit(cell_num)
