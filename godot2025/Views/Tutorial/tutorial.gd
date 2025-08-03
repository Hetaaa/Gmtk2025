extends Node2D

@onready var beatslider = $BeatSlider
@onready var player = $Node2D/Player
@onready var enemy = $Node2D/Enemy
@onready var cutscene_label = $cutsceneLabel

#Player positions for different phases
@export var player_phase_position: Vector2 = Vector2(-50, 90)
@export var player_enemy_phase_position: Vector2 = Vector2(-200, 90)

#Enemy positions for different phases
@export var enemy_phase_position: Vector2 = Vector2(250, 90)
@export var enemy_player_phase_position: Vector2 = Vector2(80, 90)

# Movement settings
@export var move_duration: float = 1.0
@export var use_smooth_movement: bool = true
@export var position_change_delay: float = 0.5

# Cutscene settings
@export var cutscene_texts: Array[String] = [
	"Enemy did his first three moves",
	"Do you remember them? No? \nWell, that's too bad.",
	"He is stuck in a time loop,\n and will reapet them again",
	"You need to protect yourself \nand attack him back",
	"You are not dumb. \nYou hear the music, think fast lol",
	"W - Block High, O - Attack High\nS - Block Middle, K - Attack Middle\nX - Block Low, M - Attack Low"
]

signal phase_changed(phase_type: PhaseType, moves_remaining: int)

enum PhaseType {
	ENEMY_PHASE,
	PLAYER_PHASE
}

var current_phase: PhaseType = PhaseType.ENEMY_PHASE
var is_moving: bool = false
var is_waiting_for_input: bool = false
var cutscene_active: bool = false

func _ready() -> void:
	BeatManager.play_track(13, 0)
	FightManager.load_phase_pattern("res://audio/patterns/myarchnemesis.txt")
	beatslider.start_beats(0.0)
	
	# Hide cutscene label initially
	if cutscene_label:
		cutscene_label.text = ""
		cutscene_label.visible = false
	
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
	
	# Start cutscene after 6.6 seconds
	start_cutscene()

func start_cutscene() -> void:
	cutscene_active = true
	
	# Wait 7 seconds before starting cutscene
	await get_tree().create_timer(9).timeout
	
	# Slow down music
	BeatManager.set_music_speed(0.02)
	
	# Slow down player and enemy animations via their Sprite AnimationPlayer
	if FightManager.player_ref and FightManager.player_ref.has_node("Sprite2D"):
		var player_sprite = FightManager.player_ref.get_node("Sprite2D")
		if player_sprite is AnimatedSprite2D:
			player_sprite.speed_scale = 0.1
	
	if FightManager.enemy_ref and FightManager.enemy_ref.has_node("Sprite2D"):
		var enemy_sprite = FightManager.enemy_ref.get_node("Sprite2D")
		if enemy_sprite is AnimatedSprite2D:
			enemy_sprite.speed_scale = 0.1
	
	# Display texts with longer intervals
	for i in range(cutscene_texts.size()):
		await get_tree().create_timer(3.0).timeout
		show_cutscene_text(cutscene_texts[i])
		
		# Extra long delay for the last text (controls instruction)
		if i == cutscene_texts.size() - 1:
			await get_tree().create_timer(5.0).timeout
	
	# Wait 2 more seconds after the last text
	await get_tree().create_timer(2.0).timeout
	
	# Restore normal music speed
	BeatManager.set_music_speed(1.0)
	
	# Restore normal animation speeds
	if FightManager.player_ref and FightManager.player_ref.has_node("Sprite2D"):
		var player_sprite = FightManager.player_ref.get_node("Sprite2D")
		if player_sprite is AnimatedSprite2D:
			player_sprite.speed_scale = 1.0
	
	if FightManager.enemy_ref and FightManager.enemy_ref.has_node("Sprite2D"):
		var enemy_sprite = FightManager.enemy_ref.get_node("Sprite2D")
		if enemy_sprite is AnimatedSprite2D:
			enemy_sprite.speed_scale = 1.0
	
	# Hide cutscene text
	hide_cutscene_text()
	cutscene_active = false

func show_cutscene_text(text: String) -> void:
	if cutscene_label:
		cutscene_label.text = text
		cutscene_label.visible = true
		
		# Optional: Add fade-in effect
		cutscene_label.modulate = Color(1, 1, 1, 0)
		var tween = create_tween()
		tween.tween_property(cutscene_label, "modulate", Color(1, 1, 1, 1), 0.3)

func hide_cutscene_text() -> void:
	if cutscene_label:
		# Optional: Add fade-out effect
		var tween = create_tween()
		tween.tween_property(cutscene_label, "modulate", Color(1, 1, 1, 0), 0.3)
		await tween.finished
		cutscene_label.visible = false
		cutscene_label.text = ""

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
	BeatManager.stop_track()
	EndScreenManager.show(winner)
	is_waiting_for_input = true
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# Don't handle input during cutscene
	if cutscene_active:
		return
	
	# Obsługuj input tylko gdy czekamy na zakończenie walki
	if is_waiting_for_input and event is InputEventKey and event.pressed:
		# Nie pozwól na pauzę podczas ekranu końca walki
		if event.is_action_pressed("PAUSE"):
			print("Ignoring PAUSE - waiting for input after fight")
			get_viewport().set_input_as_handled()
			return
		
		# Inne klawisze kończą walkę
		is_waiting_for_input = false
		EndScreenManager.stop()
		set_process_input(false)
		print("Zamykam ekran końca walki.")
		
		# Małe opóźnienie przed zmianą sceny
		await get_tree().create_timer(0.1).timeout
		SceneManager.change_scene("main_menu")
		get_viewport().set_input_as_handled()
		return
	
	# Pauza tylko gdy nie czekamy na input po walce
	if not is_waiting_for_input and event.is_action_pressed("PAUSE") and not PauseSystem.is_game_paused:
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
