class_name Fighter extends CharacterBody2D

func _ready():
	BeatManager.action_window_start.connect(_on_action_window_start)
	BeatManager.action_window_end.connect(_on_action_window_end)
	
func _on_action_window_start():
	modulate = Color.WHITE * 1.1

func _on_action_window_end():
	# Visual indicator that input window closed
	modulate = Color.WHITE * 0.9
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)
