extends Control

@onready var resume: Button = $MarginContainer/VBoxContainer/Resume
@onready var back_to_menu: Button = $"MarginContainer/VBoxContainer/Back To Menu"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	hide()

	#resume.pressed.connect(_on_resume_pressed)
	#back_to_menu.pressed.connect(_on_back_to_menu_pressed)


func show_pause_menu() -> void:
	get_tree().paused = true
	show()

func hide_pause_menu() -> void:
	get_tree().paused = false
	hide()
# Called every frame. 'delta' is the elapsed time since the previous frame.

func _process(delta: float) -> void:
	pass

func _on_resume_pressed() -> void:
	hide_pause_menu()

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://Views/MainMenu/MainMenu.tscn")
