# Level1.gd - Uproszczony
extends Node2D

@onready var beatslider = $BeatSlider
@onready var player = $Node2D/Player
@onready var enemy = $Node2D/Enemy

# Player positions for different phases
@export var player_phase_position: Vector2 = Vector2(200, 300)
@export var player_enemy_phase_position: Vector2 = Vector2(100, 400)

# Enemy positions for different phases  
@export var enemy_phase_position: Vector2 = Vector2(600, 300)
@export var enemy_player_phase_position: Vector2 = Vector2(700, 400)

# Movement settings
@export var move_duration: float = 1.0
@export var use_smooth_movement: bool = true
@export var position_change_delay: float = 0.5  # New delay before position change

signal phase_changed(phase_type: PhaseType, moves_remaining: int)

enum PhaseType {
	ENEMY_PHASE,
	PLAYER_PHASE
}

var current_phase: PhaseType = PhaseType.PLAYER_PHASE
var is_moving: bool = false

func _ready() -> void:
	# Podstawowa konfiguracja levelu
	BeatManager.play_track(9, 4)
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")
	beatslider.start_beats(0.0)
	
	# Connect to phase changes if FightManager has this signal
	if FightManager.has_signal("phase_changed"):
		FightManager.phase_changed.connect(_on_phase_changed)
	
	# Set initial positions
	move_to_phase_positions(current_phase)

func _on_phase_changed(phase_type: PhaseType, moves_remaining: int) -> void:
	current_phase = phase_type
	move_to_phase_positions(phase_type)
	phase_changed.emit(phase_type, moves_remaining)

func move_to_phase_positions(phase_type: PhaseType) -> void:
	if is_moving:
		return
	
	is_moving = true
	
	# Add delay before position change
	if position_change_delay > 0:
		await get_tree().create_timer(position_change_delay).timeout
	
	var player_target: Vector2
	var enemy_target: Vector2
	
	match phase_type:
		PhaseType.PLAYER_PHASE:
			player_target = player_phase_position
			enemy_target = enemy_player_phase_position
		PhaseType.ENEMY_PHASE:
			player_target = player_enemy_phase_position
			enemy_target = enemy_phase_position
	
	if use_smooth_movement:
		# Smooth movement using tweens
		var player_tween = create_tween()
		var enemy_tween = create_tween()
		
		player_tween.tween_property(player, "position", player_target, move_duration)
		enemy_tween.tween_property(enemy, "position", enemy_target, move_duration)
		
		# Wait for both tweens to finish
		await player_tween.finished
		await enemy_tween.finished
	else:
		# Instant movement
		player.position = player_target
		enemy.position = enemy_target
	
	is_moving = false

# Manual phase switching for testing
func switch_to_player_phase() -> void:
	_on_phase_changed(PhaseType.PLAYER_PHASE, 0)

func switch_to_enemy_phase() -> void:
	_on_phase_changed(PhaseType.ENEMY_PHASE, 0)

# Call this function when you want to change phases manually
func change_phase(new_phase: PhaseType, moves_remaining: int = 0) -> void:
	_on_phase_changed(new_phase, moves_remaining)

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
