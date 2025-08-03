# Level1.gd - Uproszczony
extends Node2D

@onready var beatslider = $BeatSlider

func _ready() -> void:
	# Podstawowa konfiguracja levelu
	BeatManager.play_track(9, 4)
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")
	beatslider.start_beats(0.0)
	
	# Zarejestruj level w PauseSystem
	PauseSystem.register_level(self, {
		"beatslider": beatslider,
		"beat_manager": BeatManager
	})
	
	# Połącz się z sygnałem zmiany sceny
	if SceneManager:
		SceneManager.scene_changing.connect(_on_scene_changing)

func _on_scene_changing(from_scene: String, to_scene: String):
	print("Zmiana sceny z ", from_scene, " na ", to_scene)
	# PauseSystem zajmie się czyszczeniem
	PauseSystem.cleanup_before_scene_change()

func _unhandled_input(event: InputEvent) -> void:
	# Obsługa pauzy - jedna linia!
	if event.is_action_pressed("PAUSE") and not PauseSystem.is_game_paused:
		PauseSystem.pause_game()

# Opcjonalna funkcja do obsługi danych przekazanych z SceneManager
func setup_scene(data: Dictionary):
	if data.has("level_number"):
		print("Załadowano poziom: ", data.level_number)
	if data.has("previous_scene"):
		print("Poprzednia scena: ", data.previous_scene)
