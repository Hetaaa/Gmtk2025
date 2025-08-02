extends Node2D

func _ready() -> void:
	BeatManager.play_track(0)
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if get_tree().paused:
			PauseMenu.hide_pause_menu()
		else:
			PauseMenu.show_pause_menu()
