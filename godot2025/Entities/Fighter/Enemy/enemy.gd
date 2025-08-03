class_name Enemy extends Fighter

@export var max_health: int = 3

@export var move_pattern: Array[FightEnums.Action] = [
	FightEnums.Action.BLOCK_HIGH,
	FightEnums.Action.BLOCK_HIGH,
	FightEnums.Action.ATTACK_HIGH,
	FightEnums.Action.ATTACK_MIDDLE,
	FightEnums.Action.ATTACK_LOW,
	FightEnums.Action.ATTACK_HIGH,
	FightEnums.Action.ATTACK_MIDDLE,
	FightEnums.Action.ATTACK_LOW,
	FightEnums.Action.BLOCK_HIGH,
	FightEnums.Action.BLOCK_HIGH,
]

@onready var Sprite = $Sprite2D
@onready var button_display_container = $ButtonDisplayContainer
@onready var button_icon = $ButtonDisplayContainer/ButtonIcon

var submitted_windows_this_phase: Array[int] = []
var phase_move_count: int = 0

var current_health: int
var move_index: int = 0
var last_submitted_window: int = -1  # Track which window we last submitted to
var hit_sound: AudioStreamPlayer

# Dictionary mapujący akcje na nazwy plików PNG
var action_to_button_texture = {
	FightEnums.Action.BLOCK_HIGH: "W.png",
	FightEnums.Action.BLOCK_MIDDLE: "S.png", 
	FightEnums.Action.BLOCK_LOW: "X.png",
	FightEnums.Action.ATTACK_HIGH: "O.png",
	FightEnums.Action.ATTACK_MIDDLE: "K.png",
	FightEnums.Action.ATTACK_LOW: "M.png"
}

var shader_material : ShaderMaterial

func _ready():
	current_health = max_health
	# Register enemy with FightManager
	FightManager.register_enemy(self)
	Sprite.play("WAIT")
	shader_material = Sprite.material
	hit_sound = AudioStreamPlayer.new()
	hit_sound.stream = load("res://audio/hit6.wav")
	add_child(hit_sound)
	
	# Connect to BeatManager signals
	BeatManager.action_window_open.connect(_on_action_window_open)
	BeatManager.action_window_close.connect(_on_action_window_close)
	
	# Connect to FightManager phase changes
	FightManager.phase_changed.connect(_on_phase_changed)
	
	# Ensure we have a valid move pattern
	if move_pattern.is_empty():
		move_pattern = [FightEnums.Action.WAIT]  # Default fallback
	
	# Ustawienie początkowej pozycji ikony przycisku
	setup_button_icon()

func setup_button_icon():
	"""Ustawienie początkowych właściwości ikony przycisku"""
	if button_icon:
		button_icon.modulate.a = 0  # Niewidoczny na początku
		button_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		button_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

func get_current_action() -> FightEnums.Action:
	"""Get the current action without advancing the index"""
	if move_pattern.is_empty():
		return FightEnums.Action.WAIT
	
	return move_pattern[move_index % move_pattern.size()]

func advance_to_next_move():
	"""Advance to the next move in the pattern"""
	move_index = (move_index + 1) % move_pattern.size()
	print("DEBUG: Enemy advanced to move index: ", move_index, " (action: ", move_pattern[move_index % move_pattern.size()], ")")

func submit_enemy_action(target_window_id: int = -1):
	# Only submit if it's enemy phase
	if not FightManager.is_enemy_phase():
		print("Enemy tried to act outside enemy phase - ignored")
		return
	
	# FIXED: Additional validation
	if target_window_id in submitted_windows_this_phase:
		print("DEBUG: Enemy already submitted to window ", target_window_id, " - skipping duplicate")
		return
	
	var action = get_current_action()
	print("DEBUG: Enemy submitting action: ", action, " (index ", move_index, ") for window: ", target_window_id)
	
	# Pokaż animację przycisku dla tej akcji
	
	
	# Track that we submitted to this window
	submitted_windows_this_phase.append(target_window_id)
	phase_move_count += 1
	
	# Use FightManager's method
	FightManager.submit_enemy_action(action, target_window_id)

	show_button_animation(action)
func show_button_animation(action: FightEnums.Action):
	"""Pokazuje animację przycisku nad głową enemy"""
	if not button_icon or not action_to_button_texture.has(action):
		return
	
	# Załaduj odpowiednią teksturę
	var texture_path = "res://Textures/UI/KeyboardButtons/" + action_to_button_texture[action]  # Zmień ścieżkę na właściwą
	var texture = load(texture_path)
	
	if texture:
		button_icon.texture = texture
		
		# Pozycja startowa (nad głową, trochę wyżej niż sprite)
		var start_pos = Vector2(0, -80)  # Dostosuj wartość -80 w zależności od rozmiaru sprite'a
		var end_pos = Vector2(0, -120)   # Końcowa pozycja (jeszcze wyżej)
		
		button_icon.position = start_pos
		
		# Animacja pojawiania się, ruchu w górę i znikania
		var tween = create_tween()
		tween.set_parallel(true)  # Pozwala na równoległe animacje
		
		# Animacja opacity: 0 -> 1 -> 0
		tween.tween_method(_set_button_alpha, 0.0, 1.0, 0.3)
		tween.tween_method(_set_button_alpha, 1.0, 0.0, 0.3).set_delay(0.6)
		
		# Animacja pozycji: ruch w górę
		tween.tween_property(button_icon, "position", end_pos, 0.9)
		
		# Opcjonalnie: lekkie skalowanie dla efektu
		tween.tween_property(button_icon, "scale", Vector2(1.2, 1.2), 0.15)
		tween.tween_property(button_icon, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.15)

func _set_button_alpha(alpha: float):
	"""Helper function do ustawiania alpha ikony przycisku"""
	if button_icon:
		button_icon.modulate.a = alpha

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	# Sound effect
	hit_sound.play()
	
	# Visual damage effect
	#modulate = Color.RED
	#var tween = create_tween()
	#tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
	health_changed.emit()
	shader_material.set_shader_parameter("active", true)
	await get_tree().create_timer(0.1, false).timeout
	shader_material.set_shader_parameter("active", false)
# Method to change enemy's pattern mid-fight (optional)
func set_new_pattern(new_pattern: Array[FightEnums.Action]):
	move_pattern = new_pattern
	move_index = 0

# Reset for new phase
func reset_for_new_phase():
	submitted_windows_this_phase.clear()
	phase_move_count = 0

# --- Signal Callbacks ---

func _on_action_window_open(window_id: int, beat_count: int) -> void:
	# Only act during enemy phase
	if not FightManager.is_enemy_phase():
		return
	
	# FIXED: Check if we've already submitted to this window
	if window_id in submitted_windows_this_phase:
		print("DEBUG: Enemy already submitted to window ", window_id, " this phase - skipping")
		return
	
	# FIXED: Check if we've made all required moves for this phase
	var phase_info = FightManager.get_current_phase_info()
	var total_moves_for_phase = phase_info.moves_remaining + phase_move_count
	
	if phase_move_count >= total_moves_for_phase:
		print("DEBUG: Enemy has made all required moves for this phase - skipping window ", window_id)
		return
	
	# FIXED: Add small delay to ensure window is fully initialized
	await get_tree().process_frame
	
	submit_enemy_action(window_id)

func _on_action_window_close(window_id: int, beat_count: int):
	# No visual changes here - phase color takes precedence
	pass

func change_animation(anim: StringName):
	Sprite.play(anim)

func _on_phase_changed(phase_type: FightManager.PhaseType, moves_remaining: int):
	if phase_type == FightManager.PhaseType.ENEMY_PHASE:
		print("Enemy: My turn! ", moves_remaining, " moves to make")
		reset_for_new_phase()
	else:
		print("Enemy: Player's turn to respond")

func _on_sprite_2d_animation_finished() -> void:
	Sprite.play("WAIT")
