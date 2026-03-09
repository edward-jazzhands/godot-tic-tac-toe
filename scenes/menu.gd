extends Node2D


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_options_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/options.tscn")
	
func _on_quit_pressed() -> void:
	get_tree().quit()
