# FightManager.gd
extends Node

# Signals for fight events
signal actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float, window_id: int)
signal fight_ended(winner: String)
signal phase_changed(phase_type: PhaseType, moves_remaining: int)
signal phases_loaded()

# Signals for receiving actions from player/enemy
signal player_action_submitted(action: FightEnums.Action, timing: FightEnums.BeatTiming, window_id: int)
signal enemy_action_submitted(action: FightEnums.Action, window_id: int)

enum PhaseType {
	ENEMY_PHASE,
	PLAYER_PHASE
}

var player_ref: Node
var enemy_ref: Node

# Phase system variables
var phase_pattern: Array[int] = []
var current_phase_index: int = 0
var current_phase_type: PhaseType = PhaseType.ENEMY_PHASE
var moves_remaining_in_phase: int = 0
var current_phase_moves: Array[FightEnums.Action] = []

# Stored moves for matching
var enemy_phase_moves: Array[FightEnums.Action] = []
var player_phase_moves: Array[FightEnums.Action] = []
var current_move_index: int = 0

# Track queued actions per window
var window_actions: Dictionary = {} # window_id -> WindowAction

# WindowAction class to track actions for each window
class WindowAction:
	var window_id: int
	var beat_count: int
	var player_action: FightEnums.Action = FightEnums.Action.NULL
	var enemy_action: FightEnums.Action = FightEnums.Action.NULL
	var player_timing: FightEnums.BeatTiming = FightEnums.BeatTiming.NULL
	var player_submitted: bool = false
	var enemy_submitted: bool = false
	var resolved: bool = false
	var phase_type: PhaseType
	var move_index: int = -1
	
	func _init(id: int, beat: int, p_type: PhaseType, m_index: int = -1):
		window_id = id
		beat_count = beat
		phase_type = p_type
		move_index = m_index

const ATTACK_TO_BLOCK_MAP: Dictionary = {
	FightEnums.Action.ATTACK_HIGH: FightEnums.Action.BLOCK_HIGH,
	FightEnums.Action.ATTACK_LOW: FightEnums.Action.BLOCK_LOW,
	FightEnums.Action.ATTACK_MIDDLE: FightEnums.Action.BLOCK_MIDDLE,
}

const BLOCK_TO_ATTACK_MAP: Dictionary = {
	FightEnums.Action.BLOCK_HIGH: FightEnums.Action.ATTACK_HIGH,
	FightEnums.Action.BLOCK_LOW: FightEnums.Action.ATTACK_LOW,
	FightEnums.Action.BLOCK_MIDDLE: FightEnums.Action.ATTACK_MIDDLE,
}

const ATTACKS: Array[FightEnums.Action] = [
	FightEnums.Action.ATTACK_HIGH,
	FightEnums.Action.ATTACK_LOW,
	FightEnums.Action.ATTACK_MIDDLE,
]

const BLOCKS: Array[FightEnums.Action] = [
	FightEnums.Action.BLOCK_HIGH,
	FightEnums.Action.BLOCK_LOW,
	FightEnums.Action.BLOCK_MIDDLE,
]

func _ready():
	# Connect to BeatManager's signals
	BeatManager.action_window_open.connect(_on_action_window_open)
	BeatManager.action_window_close.connect(_on_action_window_close)
	BeatManager.resolve_round.connect(_on_resolve_round)
	
	player_action_submitted.connect(_on_player_action_submitted)
	enemy_action_submitted.connect(_on_enemy_action_submitted)

func register_player(player: Player):
	player_ref = player

func register_enemy(enemy: Enemy):
	enemy_ref = enemy

func load_phase_pattern(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("Could not open phase pattern file: " + file_path)
		return false
	
	phase_pattern.clear()
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line != "":
			var number = int(line)
			if number > 0:
				phase_pattern.append(number)
	
	file.close()
	
	if phase_pattern.is_empty():
		push_error("Phase pattern file is empty or invalid")
		return false
	phases_loaded.emit()
	_initialize_first_phase()
	return true

# Alternative method to set pattern directly without file
func set_phase_pattern(pattern: Array[int]):
	phase_pattern = pattern.duplicate()
	if not phase_pattern.is_empty():
		_initialize_first_phase()

func _initialize_first_phase():
	if phase_pattern.is_empty():
		return
	
	current_phase_index = 0
	current_phase_type = PhaseType.ENEMY_PHASE
	moves_remaining_in_phase = phase_pattern[0]
	current_move_index = 0
	enemy_phase_moves.clear()
	player_phase_moves.clear()
	
	# Pre-allocate the enemy_phase_moves array to prevent indexing issues
	enemy_phase_moves.resize(moves_remaining_in_phase)
	for i in range(moves_remaining_in_phase):
		enemy_phase_moves[i] = FightEnums.Action.WAIT  # Default to WAIT
	
	phase_changed.emit(current_phase_type, moves_remaining_in_phase)
	print("Starting Enemy Phase with ", moves_remaining_in_phase, " moves")
	print("DEBUG: Initialized enemy_phase_moves array: ", enemy_phase_moves)

func _on_action_window_open(window_id: int, beat_count: int):
	if not window_actions.has(window_id):
		# Only create window action if we're expecting moves in this phase
		if moves_remaining_in_phase > 0:
			window_actions[window_id] = WindowAction.new(window_id, beat_count, current_phase_type, current_move_index)
			print("Created window ", window_id, " for ", 
				("ENEMY" if current_phase_type == PhaseType.ENEMY_PHASE else "PLAYER"), 
				" phase, move index: ", current_move_index)
	else:
		# Window was pre-created, just update the beat count
		window_actions[window_id].beat_count = beat_count
		print("Updated pre-created window ", window_id, " with beat count: ", beat_count)

func _on_action_window_close(window_id: int, beat_count: int):
	if window_actions.has(window_id):
		var window_action = window_actions[window_id]
		
		# Fill in missing actions based on phase
		if window_action.phase_type == PhaseType.ENEMY_PHASE:
			if not window_action.enemy_submitted:
				window_action.enemy_action = FightEnums.Action.WAIT
		else: # PLAYER_PHASE
			if not window_action.player_submitted:
				window_action.player_action = FightEnums.Action.WAIT
				window_action.player_timing = FightEnums.BeatTiming.NULL

func _on_resolve_round(window_id: int, beat_count: int):
	if window_actions.has(window_id) and not window_actions[window_id].resolved:
		_resolve_window(window_id)

func _on_player_action_submitted(action: FightEnums.Action, timing: FightEnums.BeatTiming, window_id: int):
	if current_phase_type != PhaseType.PLAYER_PHASE:
		print("Player action ignored - not in player phase")
		return
	
	if window_actions.has(window_id) and not window_actions[window_id].resolved:
		var window_action = window_actions[window_id]
		if not window_action.player_submitted:
			window_action.player_action = action
			window_action.player_timing = timing
			window_action.player_submitted = true
			
			# Store the player move
			if window_action.move_index >= 0 and window_action.move_index < player_phase_moves.size():
				player_phase_moves[window_action.move_index] = action
			
			_resolve_window_immediately(window_id)

func _on_enemy_action_submitted(action: FightEnums.Action, window_id: int):
	if current_phase_type != PhaseType.ENEMY_PHASE:
		print("Enemy action ignored - not in enemy phase")
		return
	
	if window_actions.has(window_id) and not window_actions[window_id].resolved:
		var window_action = window_actions[window_id]
		if not window_action.enemy_submitted:
			window_action.enemy_action = action
			window_action.enemy_submitted = true
			
			# FIXED: Properly store the enemy move with bounds checking
			if window_action.move_index >= 0 and window_action.move_index < enemy_phase_moves.size():
				enemy_phase_moves[window_action.move_index] = action
				print("DEBUG: Stored enemy move at index ", window_action.move_index, ": ", action)
				print("DEBUG: Current enemy_phase_moves array: ", enemy_phase_moves)
			else:
				print("ERROR: Invalid move_index for enemy action: ", window_action.move_index, " (array size: ", enemy_phase_moves.size(), ")")

func submit_player_action(action: FightEnums.Action):
	if current_phase_type != PhaseType.PLAYER_PHASE:
		print("Cannot submit player action - not in player phase")
		return
	
	# Find the earliest open window that belongs to the current player phase
	var player_window_id = _get_earliest_player_window()
	if player_window_id == -1:
		print("No open player phase windows available")
		return
	
	var timing = BeatManager.get_timing_for_window(player_window_id)
	if timing == FightEnums.BeatTiming.NULL:
		print("Invalid timing for player window ", player_window_id)
		return
	
	player_action_submitted.emit(action, timing, player_window_id)

# Helper method to find earliest open window for current player phase
func _get_earliest_player_window() -> int:
	var earliest_window_id = -1
	
	# Get all currently open windows from BeatManager
	var open_window_ids = BeatManager.get_open_window_ids()
	
	print("DEBUG: Looking for player windows. Open BM windows: ", open_window_ids)
	print("DEBUG: Current phase: ", current_phase_type, ", move index: ", current_move_index)
	
	for window_id in open_window_ids:
		print("DEBUG: Checking window ", window_id, " - exists in window_actions: ", window_actions.has(window_id))
		if window_actions.has(window_id):
			var window_action = window_actions[window_id]
			print("DEBUG: Window ", window_id, " phase: ", window_action.phase_type, ", resolved: ", window_action.resolved, ", submitted: ", window_action.player_submitted)
			if (window_action.phase_type == PhaseType.PLAYER_PHASE and 
				not window_action.resolved and
				not window_action.player_submitted):
				
				print("DEBUG: Found valid player window: ", window_id)
				return window_id
	
	print("DEBUG: No valid player windows found")
	return -1

func submit_enemy_action(action: FightEnums.Action, target_window_id: int = -1):
	if current_phase_type != PhaseType.ENEMY_PHASE:
		print("Cannot submit enemy action - not in enemy phase")
		return
	
	var window_id = target_window_id
	if window_id == -1:
		window_id = BeatManager.get_earliest_open_window()
	
	if window_id == -1:
		return
	
	enemy_action_submitted.emit(action, window_id)

func _resolve_window_immediately(window_id: int):
	if not window_actions.has(window_id):
		return
	
	var window_action = window_actions[window_id]
	if window_action.resolved:
		return
	
	window_action.resolved = true
	
	if window_action.phase_type == PhaseType.ENEMY_PHASE:
		# Enemy phase - just store the action, don't resolve combat yet
		print("Enemy move ", window_action.move_index, " stored: ", window_action.enemy_action)
		
		# FIXED: Advance enemy's move index after storing the action
		if enemy_ref and enemy_ref.has_method("advance_to_next_move"):
			enemy_ref.advance_to_next_move()
		
		_advance_phase_progress()
	else:
		# Player phase - resolve against corresponding enemy move
		var enemy_move = FightEnums.Action.WAIT
		
		# FIXED: Add better bounds checking and debug info
		print("DEBUG: Retrieving enemy move for player move index: ", window_action.move_index)
		print("DEBUG: enemy_phase_moves array: ", enemy_phase_moves)
		print("DEBUG: enemy_phase_moves size: ", enemy_phase_moves.size())
		
		if window_action.move_index >= 0 and window_action.move_index < enemy_phase_moves.size():
			enemy_move = enemy_phase_moves[window_action.move_index]
			print("DEBUG: Retrieved enemy move at index ", window_action.move_index, ": ", enemy_move)
		else:
			print("ERROR: Invalid move_index for player phase: ", window_action.move_index)
		
		window_action.enemy_action = enemy_move
		
		var result = determine_winner(window_action.player_action, window_action.enemy_action)
		var timing_bonus = get_timing_bonus(window_action.player_timing)
		
		actions_revealed.emit(window_action.player_action, window_action.enemy_action, result, timing_bonus, window_id)
		_apply_damage(result, timing_bonus, window_id)
		
		print("Combat resolved - Player: ", window_action.player_action, " vs Enemy: ", window_action.enemy_action)
		_advance_phase_progress()
	
	BeatManager.mark_window_resolved(window_id)
	get_tree().create_timer(0.1).timeout.connect(func(): _cleanup_window(window_id))

func _resolve_window(window_id: int):
	if not window_actions.has(window_id):
		return
	
	var window_action = window_actions[window_id]
	if window_action.resolved:
		return
	
	window_action.resolved = true
	
	# Handle missed actions based on phase
	if window_action.phase_type == PhaseType.ENEMY_PHASE:
		if window_action.enemy_action == FightEnums.Action.NULL:
			window_action.enemy_action = FightEnums.Action.WAIT
		
		# FIXED: Store the enemy move with proper bounds checking
		if window_action.move_index >= 0 and window_action.move_index < enemy_phase_moves.size():
			enemy_phase_moves[window_action.move_index] = window_action.enemy_action
			print("DEBUG: Stored enemy move (natural) at index ", window_action.move_index, ": ", window_action.enemy_action)
		else:
			print("ERROR: Invalid move_index for enemy natural resolution: ", window_action.move_index)
		
		print("Enemy move ", window_action.move_index, " stored (natural): ", window_action.enemy_action)
		
		# FIXED: Advance enemy's move index after storing the action
		if enemy_ref and enemy_ref.has_method("advance_to_next_move"):
			enemy_ref.advance_to_next_move()
		
		_advance_phase_progress()
		
	else: # PLAYER_PHASE
		if window_action.player_action == FightEnums.Action.NULL:
			window_action.player_action = FightEnums.Action.WAIT
			window_action.player_timing = FightEnums.BeatTiming.NULL
		
		# Get corresponding enemy move
		var enemy_move = FightEnums.Action.WAIT
		
		print("DEBUG: Retrieving enemy move (natural) for player move index: ", window_action.move_index)
		print("DEBUG: enemy_phase_moves array: ", enemy_phase_moves)
		
		if window_action.move_index >= 0 and window_action.move_index < enemy_phase_moves.size():
			enemy_move = enemy_phase_moves[window_action.move_index]
			print("DEBUG: Retrieved enemy move (natural) at index ", window_action.move_index, ": ", enemy_move)
		else:
			print("ERROR: Invalid move_index for player natural resolution: ", window_action.move_index)
		
		window_action.enemy_action = enemy_move
		
		var result = determine_winner(window_action.player_action, window_action.enemy_action)
		var timing_bonus = get_timing_bonus(window_action.player_timing)
		
		actions_revealed.emit(window_action.player_action, window_action.enemy_action, result, timing_bonus, window_id)
		_apply_damage(result, timing_bonus, window_id)
		
		print("Combat resolved (natural) - Player: ", window_action.player_action, " vs Enemy: ", window_action.enemy_action)
		_advance_phase_progress()
	
	get_tree().create_timer(0.1).timeout.connect(func(): _cleanup_window(window_id))

func _advance_phase_progress():
	moves_remaining_in_phase -= 1
	
	if moves_remaining_in_phase <= 0:
		_transition_to_next_phase()
	else:
		current_move_index += 1
		phase_changed.emit(current_phase_type, moves_remaining_in_phase)

func _transition_to_next_phase():
	if current_phase_type == PhaseType.ENEMY_PHASE:
		# Switch to player phase with same number of moves
		current_phase_type = PhaseType.PLAYER_PHASE
		moves_remaining_in_phase = phase_pattern[current_phase_index]
		current_move_index = 0
		player_phase_moves.clear()
		player_phase_moves.resize(moves_remaining_in_phase)
		
		print("Switching to Player Phase with ", moves_remaining_in_phase, " moves")
		print("Enemy moves to respond to: ", enemy_phase_moves)
		
		# NEW: Pre-create player phase windows that are about to open
		_pre_create_player_windows()
		
		# Small delay to ensure phase transition is complete before accepting input
		await get_tree().process_frame
		
	else:
		# Switch to next enemy phase
		current_phase_index += 1
		if current_phase_index >= phase_pattern.size():
			current_phase_index = 0  # Loop back to beginning
		
		current_phase_type = PhaseType.ENEMY_PHASE
		moves_remaining_in_phase = phase_pattern[current_phase_index]
		current_move_index = 0
		enemy_phase_moves.clear()
		
		# FIXED: Pre-allocate enemy array again for the new phase
		enemy_phase_moves.resize(moves_remaining_in_phase)
		for i in range(moves_remaining_in_phase):
			enemy_phase_moves[i] = FightEnums.Action.WAIT  # Default to WAIT
		
		print("Switching to Enemy Phase with ", moves_remaining_in_phase, " moves")
		print("DEBUG: Re-initialized enemy_phase_moves array: ", enemy_phase_moves)
		
		# Small delay to ensure phase transition is complete
		await get_tree().process_frame
	
	phase_changed.emit(current_phase_type, moves_remaining_in_phase)

# NEW: Pre-create player windows that are about to open
func _pre_create_player_windows():
	# Get the next few window IDs that BeatManager will create
	var open_window_ids = BeatManager.get_open_window_ids()
	
	print("DEBUG: Pre-creating player windows. Open BM windows: ", open_window_ids)
	print("DEBUG: Current move index: ", current_move_index)
	
	# Convert existing enemy windows to player windows, or create new ones
	for window_id in open_window_ids:
		if window_actions.has(window_id):
			var existing_window = window_actions[window_id]
			if existing_window.phase_type == PhaseType.ENEMY_PHASE and not existing_window.resolved:
				# Convert this enemy window to a player window
				existing_window.phase_type = PhaseType.PLAYER_PHASE
				existing_window.move_index = current_move_index
				print("DEBUG: Converted enemy window ", window_id, " to player window for move index: ", current_move_index)
				break
			else:
				print("DEBUG: Window ", window_id, " already exists as: phase=", existing_window.phase_type, " resolved=", existing_window.resolved)
		else:
			# Create a player phase window for this ID
			window_actions[window_id] = WindowAction.new(window_id, 0, PhaseType.PLAYER_PHASE, current_move_index)
			print("DEBUG: Pre-created player window ", window_id, " for move index: ", current_move_index)
			break

func _apply_damage(result: FightEnums.FightResult, timing_bonus: float, window_id: int):
	match result:
		FightEnums.FightResult.ENEMY_HIT:
			if enemy_ref and enemy_ref.has_method("take_damage"):
				var damage = 1 + int(timing_bonus > 0.8)
				enemy_ref.take_damage(damage)
				print("Enemy takes ", damage, " damage (Window ", window_id, ")")

		FightEnums.FightResult.PLAYER_HIT:
			if player_ref and player_ref.has_method("take_damage"):
				player_ref.take_damage(1)
				print("Player takes 1 damage (Window ", window_id, ")")

		FightEnums.FightResult.BOTH_HIT:
			if enemy_ref and enemy_ref.has_method("take_damage"):
				var player_damage = 1 + int(timing_bonus > 0.8)
				enemy_ref.take_damage(player_damage)
			if player_ref and player_ref.has_method("take_damage"):
				player_ref.take_damage(1)
			print("Both hit (Window ", window_id, ")")

		FightEnums.FightResult.NONE_HIT:
			print("No hits (Window ", window_id, ")")
	
	# Check for fight end
	if player_ref and player_ref.current_health <= 0:
		fight_ended.emit("Enemy")
	elif enemy_ref and enemy_ref.current_health <= 0:
		fight_ended.emit("Player")

func _cleanup_window(window_id: int):
	if window_actions.has(window_id):
		window_actions.erase(window_id)

func determine_winner(p_action: FightEnums.Action, e_action: FightEnums.Action) -> FightEnums.FightResult:
	print("DEBUG: Combat - Player: ", p_action, " vs Enemy: ", e_action)
	
	# Handle WAIT actions first
	if p_action == FightEnums.Action.WAIT:
		if e_action in ATTACKS:
			print("DEBUG: Player WAIT vs Enemy ATTACK -> Player hit")
			return FightEnums.FightResult.PLAYER_HIT
		else:
			print("DEBUG: Player WAIT vs Enemy non-attack -> No hits")
			return FightEnums.FightResult.NONE_HIT
	
	if e_action == FightEnums.Action.WAIT:
		if p_action in ATTACKS:
			print("DEBUG: Enemy WAIT vs Player ATTACK -> Enemy hit")
			return FightEnums.FightResult.ENEMY_HIT
		else:
			print("DEBUG: Enemy WAIT vs Player non-attack -> No hits")
			return FightEnums.FightResult.NONE_HIT

	var p_is_attack := p_action in ATTACKS
	var p_is_block := p_action in BLOCKS
	var e_is_attack := e_action in ATTACKS
	var e_is_block := e_action in BLOCKS

	print("DEBUG: Player - Attack: ", p_is_attack, " Block: ", p_is_block)
	print("DEBUG: Enemy - Attack: ", e_is_attack, " Block: ", e_is_block)

	# 1) If enemy attacks and player also attacks -> player takes damage
	if e_is_attack and p_is_attack:
		print("DEBUG: Both attack -> Player takes damage")
		return FightEnums.FightResult.PLAYER_HIT

	# 2) If enemy attacks and player blocks on wrong height -> player takes damage
	# 3) If enemy attacks and player blocks on correct height -> no one takes damage
	if e_is_attack and p_is_block:
		var correct_block = ATTACK_TO_BLOCK_MAP[e_action]
		print("DEBUG: Enemy attacks, player blocks. Enemy attack: ", e_action, " needs block: ", correct_block, " player has: ", p_action)
		if correct_block == p_action:
			print("DEBUG: Correct block -> No hits")
			return FightEnums.FightResult.NONE_HIT  # Correct block
		else:
			print("DEBUG: Wrong block -> Player hit")
			return FightEnums.FightResult.PLAYER_HIT  # Wrong block

	# 4) Same reversed - if player attacks and enemy blocks
	if p_is_attack and e_is_block:
		var correct_block = ATTACK_TO_BLOCK_MAP[p_action]
		print("DEBUG: Player attacks, enemy blocks. Player attack: ", p_action, " needs block: ", correct_block, " enemy has: ", e_action)
		if correct_block == e_action:
			print("DEBUG: Enemy blocks correctly -> No hits")
			return FightEnums.FightResult.NONE_HIT  # Enemy blocks correctly
		else:
			print("DEBUG: Enemy blocks wrong -> Enemy hit")
			return FightEnums.FightResult.ENEMY_HIT  # Enemy blocks wrong

	# If both block, nothing happens
	if p_is_block and e_is_block:
		print("DEBUG: Both block -> No hits")
		return FightEnums.FightResult.NONE_HIT

	print("DEBUG: Fallback -> No hits")
	return FightEnums.FightResult.NONE_HIT

func get_timing_bonus(timing: FightEnums.BeatTiming) -> float:
	match timing:
		FightEnums.BeatTiming.PERFECT: return 1.0
		FightEnums.BeatTiming.GOOD: return 0.7
		FightEnums.BeatTiming.NICE: return 0.4
		_: return 0.0

# Utility methods
func get_current_phase_info() -> Dictionary:
	return {
		"phase_type": current_phase_type,
		"moves_remaining": moves_remaining_in_phase,
		"current_move_index": current_move_index,
		"phase_pattern_index": current_phase_index
	}

func get_enemy_moves() -> Array[FightEnums.Action]:
	return enemy_phase_moves.duplicate()

func get_player_moves() -> Array[FightEnums.Action]:
	return player_phase_moves.duplicate()

func is_enemy_phase() -> bool:
	return current_phase_type == PhaseType.ENEMY_PHASE

func is_player_phase() -> bool:
	return current_phase_type == PhaseType.PLAYER_PHASE

# Check if we're ready to accept player input
func is_player_input_ready() -> bool:
	return current_phase_type == PhaseType.PLAYER_PHASE
