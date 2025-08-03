# PauseMenu.gd - Uproszczony
extends Control

@onready var resume: Button = $MarginContainer/VBoxContainer/Resume
@onready var back_to_menu: Button = $"MarginContainer/VBoxContainer/Back To Menu"
@onready var hslider : HSlider = $MarginContainer/VBoxContainer/HSlider
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	_on_h_slider_drag_ended(true)
	# Połącz sygnały przycisków
	if resume:
		resume.pressed.connect(_on_resume_pressed)
	if back_to_menu:
		back_to_menu.pressed.connect(_on_back_to_menu_pressed)

# Obsługa ESC w PauseMenu - zamyka menu
func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("PAUSE"):
		print("ESC w PauseMenu - zamykam menu")
		get_viewport().set_input_as_handled()
		PauseSystem.resume_game()

func _on_resume_pressed() -> void:
	print("Resume button pressed")
	PauseSystem.resume_game()

func _on_back_to_menu_pressed() -> void:
	print("Back to menu button pressed")
	
	# PauseSystem zajmie się czyszczeniem
	PauseSystem.cleanup_before_scene_change()
	
	# Krótka pauza żeby wszystko się zatrzymało
	await get_tree().process_frame
	
	SceneManager.change_scene("main_menu")


func _on_h_slider_drag_ended(value_changed: bool) -> void:
	if value_changed:
		var volume_slider_value = hslider.value
		print(volume_slider_value)
		var volume_db = 0.0
		if volume_slider_value >0.0:
			volume_db = lerp(-20.0, 0.0, volume_slider_value / 100.0)
		else:
			volume_db = -200.0
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), volume_db)
