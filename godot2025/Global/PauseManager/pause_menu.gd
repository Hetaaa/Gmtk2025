# PauseMenu.gd - Uproszczony
extends Control

@onready var resume: Button = $MarginContainer/VBoxContainer/Resume
@onready var back_to_menu: Button = $"MarginContainer/VBoxContainer/Back To Menu"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()
	
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
