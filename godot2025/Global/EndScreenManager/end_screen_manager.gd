extends Node

var end_screen: Sprite2D = null
var pulse_tween: Tween = null
var input_enabled: bool = false

func show(winner: String) -> void:
	# Usuń poprzedni, jeśli istnieje
	if end_screen:
		end_screen.queue_free()
	
	# Zresetuj stan inputu
	input_enabled = false
	
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
	
	# WAŻNE: Opóźnienie przed włączeniem inputu
	# Czeka na zakończenie fade-in + dodatkowe opóźnienie
	fade_tween.tween_callback(Callable(self, "_enable_input_after_delay"))

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

func _enable_input_after_delay() -> void:
	# Dodatkowe opóźnienie po fade-in (1.0 sekunda dla pewności)
	await get_tree().create_timer(1.0).timeout
	input_enabled = true
	print("EndScreen: Input NOW enabled - you can press any key to continue")

func stop() -> void:
	input_enabled = false
	
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

# Funkcja do sprawdzenia czy input jest włączony
func is_input_enabled() -> bool:
	return input_enabled and is_end_screen_active()
