extends Node

# Scene Manager - Global singleton for handling scene transitions
# Add this to AutoLoad in Project Settings

signal scene_changing(from_scene: String, to_scene: String)
signal scene_changed(scene_name: String)

# Scene registry - maps scene names to their file paths
var scenes: Dictionary = {
	"main_menu": "res://Views/MainMenu/MainMenu.tscn",
	"calibration": "res://Views/TimingOffsetSetter/TimingCalibrator.tscn",
	"choosing_levels": "res://Views/ChoosingLevels/ChoosingLevel.tscn",
	"options": "res://Views/Options/Options.tscn",
	"level_1": "res://Views/Tutorial/level1.tscn",
	"level_2": "res://Views/Level1/level2.tscn",
	"level_3": "res://Views/Level3/Level3.tscn",
	# Dodaj więcej poziomów według potrzeb
	"game_over": "res://scenes/GameOver.tscn"
}

# Current scene reference
var current_scene: Node = null
var current_scene_name: String = ""
var previous_scene_name: String = ""

# Loading state
var is_loading: bool = false

# Optional: Transition effects
var fade_duration: float = 0.5
var use_fade_transition: bool = true

func _ready():
	# Get the current scene on startup
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	current_scene_name = _get_scene_name_from_path(current_scene.scene_file_path)

# Register a new scene at runtime
func register_scene(scene_name: String, scene_path: String):
	scenes[scene_name] = scene_path
	print("Scene registered: ", scene_name, " -> ", scene_path)

# Change to a scene by name
func change_scene(scene_name: String, data: Dictionary = {}):
	if is_loading:
		print("Scene change already in progress, ignoring request")
		return
	
	if not scenes.has(scene_name):
		print("Error: Scene '", scene_name, "' not found in registry")
		return
	
	
	_change_scene_to_file(scenes[scene_name], scene_name, data)

# Change to a scene by direct file path
func change_scene_to_file(scene_path: String, data: Dictionary = {}):
	if is_loading:
		print("Scene change already in progress, ignoring request")
		return
	
	var scene_name = _get_scene_name_from_path(scene_path)
	_change_scene_to_file(scene_path, scene_name, data)

# Internal scene changing logic
func _change_scene_to_file(scene_path: String, scene_name: String, data: Dictionary):
	is_loading = true
	previous_scene_name = current_scene_name
	
	# Emit signal before changing
	scene_changing.emit(current_scene_name, scene_name)
	
	if use_fade_transition:
		await _fade_out()
	
	# Free the current scene
	if current_scene:
		current_scene.queue_free()
		# Wait for the scene to be freed
		await current_scene.tree_exited
	
	# Load the new scene
	var new_scene_resource = load(scene_path)
	if new_scene_resource == null:
		print("Error: Could not load scene at path: ", scene_path)
		is_loading = false
		return
	
	# Instance the new scene
	current_scene = new_scene_resource.instantiate()
	current_scene_name = scene_name
	
	# Add it to the scene tree
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# Pass data to the new scene if it has a setup method
	if current_scene.has_method("setup_scene"):
		current_scene.setup_scene(data)
	
	if use_fade_transition:
		await _fade_in()
	
	is_loading = false
	
	# Emit signal after changing
	scene_changed.emit(scene_name)
	print("Scene changed to: ", scene_name)

# Reload the current scene
func reload_current_scene():
	if current_scene_name.is_empty():
		print("Error: No current scene to reload")
		return
	
	change_scene(current_scene_name)

# Go back to the previous scene
func go_to_previous_scene(data: Dictionary = {}):
	if previous_scene_name.is_empty():
		print("Error: No previous scene to return to")
		return
	
	change_scene(previous_scene_name, data)

# Get the current scene name
func get_current_scene_name() -> String:
	return current_scene_name

# Get the previous scene name
func get_previous_scene_name() -> String:
	return previous_scene_name

# Check if a scene exists in the registry
func has_scene(scene_name: String) -> bool:
	return scenes.has(scene_name)

# Get all registered scene names
func get_scene_names() -> Array:
	return scenes.keys()

# Utility function to extract scene name from file path
func _get_scene_name_from_path(path: String) -> String:
	if path.is_empty():
		return ""
	return path.get_file().get_basename().to_lower()

# Simple fade transition effects (optional)
func _fade_out():
	if not use_fade_transition:
		return
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 0.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(fade_rect)
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 1.0, fade_duration)
	await tween.finished
	
	fade_rect.queue_free()

func _fade_in():
	if not use_fade_transition:
		return
	
	var fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.color.a = 1.0
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_tree().root.add_child(fade_rect)
	
	var tween = create_tween()
	tween.tween_property(fade_rect, "color:a", 0.0, fade_duration)
	await tween.finished
	
	fade_rect.queue_free()

# Debug function to print current state
func debug_print():
	print("=== Scene Manager Debug ===")
	print("Current Scene: ", current_scene_name)
	print("Previous Scene: ", previous_scene_name)
	print("Is Loading: ", is_loading)
	print("Registered Scenes: ", scenes.keys())
	print("=========================")
