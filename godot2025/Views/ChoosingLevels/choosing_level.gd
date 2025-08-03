extends Control


# Called when the node enters the scene tree for the first time.
func _ready():
	var containers = [$VBox1, $VBox2]
	for container in containers:
		for button in container.get_children():
			if button is Button:
				button.pressed.connect(_on_level_button_pressed.bind(button))

func _on_level_button_pressed(button: Button) -> void:
	var level_number := int(button.name.replace("LevelButton", ""))
	var level_scene_name := "level_" + str(level_number)
	
	if SceneManager.has_scene(level_scene_name):
		var level_data = {
			"level_number": level_number,
			"previous_scene": "choosing_levels"
		}
		SceneManager.change_scene(level_scene_name, level_data)
	else:
		var path := "res://Views/Level" + str(level_number) + "/Level" + str(level_number) + ".tscn"
		
		if FileAccess.file_exists(path):
			SceneManager.register_scene(level_scene_name, path)
			
			var level_data = {
				"level_number": level_number,
				"previous_scene": "choosing_levels"
			}
			SceneManager.change_scene(level_scene_name, level_data)
		else:
			print("Błąd: Nie znaleziono pliku poziomu: ", path)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
