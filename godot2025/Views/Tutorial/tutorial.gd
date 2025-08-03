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
@export var position_change_delay: float = 0.5

signal phase_changed(phase_type: PhaseType, moves_remaining: int)

enum PhaseType {
	ENEMY_PHASE,
	PLAYER_PHASE
}

var current_phase: PhaseType = PhaseType.ENEMY_PHASE
var is_moving: bool = false
var is_waiting_for_input: bool = false

func _ready() -> void:
	# Konfiguracja poziomu
	BeatManager.play_track(9, 4)
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")
	beatslider.start_beats(0.0)
	
	# Pozycje początkowe
	move_to_phase_positions(current_phase)
	
	# Podłączenia sygnałów
	if FightManager.has_signal("phase_changed"):
		FightManager.phase_changed.connect(_on_phase_changed)
	FightManager.fight_ended.connect(_on_fight_ended)
	
	# Rejestracja w PauseSystem
	PauseSystem.register_level(self, {
		"beatslider": beatslider,
		"beat_manager": BeatManager
	})
	
	# Obsługa zmiany sceny
	if SceneManager:
		SceneManager.scene_changing.connect(_on_scene_changing)

func _process(delta: float) -> void:
	var current_time = BeatManager._get_current_time()
	beatslider.update_time(current_time)

func _on_phase_changed(phase_type: PhaseType, moves_remaining: int) -> void:
	current_phase = phase_type
	move_to_phase_positions(phase_type)
	phase_changed.emit(phase_type, moves_remaining)

func move_to_phase_positions(phase_type: PhaseType) -> void:
	if is_moving:
		return
	is_moving = true
	
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
		var player_tween = create_tween()
		var enemy_tween = create_tween()
		
		player_tween.tween_property(player, "position", player_target, move_duration)
		enemy_tween.tween_property(enemy, "position", enemy_target, move_duration)
		
		await player_tween.finished
		await enemy_tween.finished
	else:
		player.position = player_target
		enemy.position = enemy_target
	
	is_moving = false

func _on_fight_ended(winner: String) -> void:
	print("=== FIGHT ENDED DEBUG ===")
	print("Winner: ", winner)
	print("Setting is_waiting_for_input to true")
	
	BeatManager.stop_track()
	is_waiting_for_input = true
	
	print("is_waiting_for_input is now: ", is_waiting_for_input)
	
	# Opóźnienie przed pokazaniem ekranu - daj czas na "wypuszczenie" ostatniego klawisza
	print("Waiting 0.2s before showing end screen...")
	await get_tree().create_timer(0.2).timeout
	
	print("Showing EndScreenManager...")
	EndScreenManager.show(winner)
	print("EndScreenManager.show() called, is_waiting_for_input: ", is_waiting_for_input)

func _input(event: InputEvent) -> void:
	# DEBUG - pokaż każdy input event
	if event is InputEventKey and event.pressed:
		print("=== INPUT DEBUG ===")
		print("Key pressed: ", event.as_text())
		print("is_waiting_for_input: ", is_waiting_for_input)
		if is_waiting_for_input:
			print("EndScreenManager.is_input_enabled(): ", EndScreenManager.is_input_enabled())
		print("==================")
	
	# ZAWSZE sprawdź czy czekamy na input po walce na początku
	if is_waiting_for_input:
		print("We are waiting for input after fight!")
		
		# Jeśli EndScreenManager nie pozwala jeszcze na input, zablokuj wszystko
		if not EndScreenManager.is_input_enabled():
			print("Blocking input - EndScreenManager not ready yet")
			get_viewport().set_input_as_handled()
			return
		
		# EndScreenManager pozwala na input, sprawdź czy to naciśnięty klawisz
		if event is InputEventKey and event.pressed:
			print("EndScreenManager allows input and key was pressed!")
			
			# Nie pozwól na pauzę podczas ekranu końca walki
			if event.is_action_pressed("PAUSE"):
				print("Ignoring PAUSE - waiting for input after fight")
				get_viewport().set_input_as_handled()
				return
			
			# Inne klawisze kończą walkę
			print("Key pressed - ending fight screen")
			is_waiting_for_input = false
			EndScreenManager.stop()
			print("Zamykam ekran końca walki.")
			
			# Małe opóźnienie przed zmianą sceny
			await get_tree().create_timer(0.1).timeout
			SceneManager.change_scene("main_menu")
			get_viewport().set_input_as_handled()
			return
		
		# Jeśli czekamy na input ale to nie był klawisz, zablokuj
		print("Blocking non-key input during end screen")
		get_viewport().set_input_as_handled()
		return
	
	# Normalny input gdy nie czekamy na zakończenie walki
	if event.is_action_pressed("PAUSE") and not PauseSystem.is_game_paused:
		print("Pausing game...")
		PauseSystem.pause_game()
		get_viewport().set_input_as_handled()

func _on_scene_changing(from_scene: String, to_scene: String) -> void:
	print("Zmiana sceny z ", from_scene, " na ", to_scene)
	
	# Wyczyść ekran końca walki przed zmianą sceny
	if EndScreenManager.is_end_screen_active():
		EndScreenManager.cleanup_before_scene_change()
	
	PauseSystem.cleanup_before_scene_change()

func setup_scene(data: Dictionary) -> void:
	if data.has("level_number"):
		print("Załadowano poziom: ", data.level_number)
	if data.has("previous_scene"):
		print("Poprzednia scena: ", data.previous_scene)
