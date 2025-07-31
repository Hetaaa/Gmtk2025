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

	var path := "res://zobaczymy" + str(level_number) + ".tscn"
	# get_tree().change_scene_to_file(path)
	print("Choosing level:", level_number)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
