extends Node

var end_screen: Sprite2D = null
var pulse_tween: Tween = null

func show(winner: String) -> void:
	# Usuń poprzedni, jeśli istnieje
	if end_screen:
		end_screen.queue_free()
	
	# Stwórz nowego Sprite2D
	end_screen = Sprite2D.new()
	end_screen.name = "EndScreenSprite"
	
	if winner == "Player":
		end_screen.texture = load("res://Entities/UI/FightEnd/WIN_SCREEN.png")
	else:
		end_screen.texture = load("res://Entities/UI/FightEnd/Death_Screen.png")
		
	end_screen.scale = Vector2(0.4, 0.4)
	end_screen.centered = true
	end_screen.global_position = get_viewport().get_camera_2d().get_screen_center_position()
	end_screen.z_index = 999
	end_screen.z_as_relative = false
	
	# Ustaw przezroczystość początkową (0 = niewidoczny)
	end_screen.modulate.a = 0.0
	
	# Dodaj go do głównego widoku
	get_tree().get_root().add_child(end_screen)
	
	# Fade-in
	var fade_tween = end_screen.create_tween()
	fade_tween.tween_property(end_screen, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)
	
	# Rozpocznij pulsowanie po zakończeniu fade-in
	fade_tween.tween_callback(Callable(self, "_start_pulsing"))
	
	get_tree().get_root().set_process_input(true)

func _start_pulsing() -> void:
	if not end_screen or not is_instance_valid(end_screen):
		return
		
	var base_scale = end_screen.scale
	var pulse_up = base_scale * 1.1
	var pulse_down = base_scale
	
	pulse_tween = end_screen.create_tween()
	pulse_tween.set_loops()
	pulse_tween.tween_property(end_screen, "scale", pulse_up, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(end_screen, "scale", pulse_down, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func stop() -> void:
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()
		pulse_tween = null
	
	if end_screen and is_instance_valid(end_screen):
		end_screen.queue_free()
		end_screen = null

# Nowa funkcja do wywołania przed zmianą sceny
func cleanup_before_scene_change() -> void:
	stop()

# Funkcja do sprawdzenia czy ekran jest aktywny
func is_end_screen_active() -> bool:
	return end_screen != null and is_instance_valid(end_screen)
