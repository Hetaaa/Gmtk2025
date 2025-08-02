class_name Enemy extends Fighter

@export var max_health: int = 3
@export var move_pattern: Array[FightEnums.Action] = [
	FightEnums.Action.ATTACK_HIGH,
	FightEnums.Action.ATTACK_HIGH,
	FightEnums.Action.BLOCK_HIGH,
]

var current_health: int
var move_index: int = 0
var last_submitted_window: int = -1  # Track which window we last submitted to
var hit_sound: AudioStreamPlayer

func _ready():
	current_health = max_health
	# Register enemy with FightManager
	FightManager.register_enemy(self)
	
	hit_sound= AudioStreamPlayer.new()
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
	
	# Prevent multiple submissions to the same window
	if target_window_id == last_submitted_window:
		print("DEBUG: Enemy already submitted to window ", target_window_id, " - skipping")
		return
	
	var action = get_current_action()
	print("DEBUG: Enemy submitting action: ", action, " (index ", move_index, ") for window: ", target_window_id)
	
	# Track that we submitted to this window
	last_submitted_window = target_window_id
	
	# Use FightManager's method instead of direct signal emission
	FightManager.submit_enemy_action(action, target_window_id)

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	#Sound effect
	hit_sound.play()
	
	# Visual damage effect
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	health_changed.emit()

# Method to change enemy's pattern mid-fight (optional)
func set_new_pattern(new_pattern: Array[FightEnums.Action]):
	move_pattern = new_pattern
	move_index = 0

# Reset for new phase
func reset_for_new_phase():
	last_submitted_window = -1
	# Don't reset move_index here - let FightManager control when to advance

# --- Signal Callbacks ---

func _on_action_window_open(window_id: int, beat_count: int) -> void:
	# Only act during enemy phase
	if FightManager.is_enemy_phase():
		submit_enemy_action(window_id)

func _on_action_window_close(window_id: int, beat_count: int):
	# No visual changes here - phase color takes precedence
	pass

func _on_phase_changed(phase_type: FightManager.PhaseType, moves_remaining: int):
	if phase_type == FightManager.PhaseType.ENEMY_PHASE:
		print("Enemy: My turn! ", moves_remaining, " moves to make")
		modulate = Color.GREEN * 1.2  # Visual indicator it's enemy phase
		reset_for_new_phase()
	else:
		print("Enemy: Player's turn to respond")
		modulate = Color.WHITE  # Return to normal color
