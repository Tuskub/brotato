extends Panel
class_name StartMenu

signal on_continue_selected
signal on_new_game_selected

func _on_continue_button_pressed() -> void:
	SoundManager.play_sound(SoundManager.Sound.UI)
	hide()
	on_continue_selected.emit()


func _on_new_game_button_pressed() -> void:
	SoundManager.play_sound(SoundManager.Sound.UI)
	hide()
	on_new_game_selected.emit()
