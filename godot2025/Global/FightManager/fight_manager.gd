# FightManager.gd
extends Node

# Signals for fight events
signal actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float, window_id: int)
signal fight_ended(winner: String)

# Signals for receiving actions from player/enemy
signal player_action_submitted(action: FightEnums.Action, timing: FightEnums.BeatTiming, window_id: int)
signal enemy_action_submitted(action: FightEnums.Action, window_id: int)

var player_ref: Node
var enemy_ref: Node

# New: Track queued actions per window
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
	
	func _init(id: int, beat: int):
		window_id = id
		beat_count = beat

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
	# Connect to BeatManager's new overlapping window signals
	BeatManager.action_window_open.connect(_on_action_window_open)
	BeatManager.action_window_close.connect(_on_action_window_close)
	BeatManager.resolve_round.connect(_on_resolve_round)
	
	player_action_submitted.connect(_on_player_action_submitted)
	enemy_action_submitted.connect(_on_enemy_action_submitted)

func register_player(player: Player):
	player_ref = player

func register_enemy(enemy: Enemy):
	enemy_ref = enemy

func _on_action_window_open(window_id: int, beat_count: int):
	# Create a new window action tracker
	if not window_actions.has(window_id):
		window_actions[window_id] = WindowAction.new(window_id, beat_count)

func _on_action_window_close(window_id: int, beat_count: int):
	# Window is closing, fill in any missing actions with WAIT
	if window_actions.has(window_id):
		var window_action = window_actions[window_id]
		if not window_action.player_submitted:
			window_action.player_action = FightEnums.Action.WAIT
			window_action.player_timing = FightEnums.BeatTiming.NULL
		if not window_action.enemy_submitted:
			window_action.enemy_action = FightEnums.Action.WAIT

func _on_resolve_round(window_id: int, beat_count: int):
	# Resolve the specific window
	if window_actions.has(window_id) and not window_actions[window_id].resolved:
		_resolve_window(window_id)

func _on_player_action_submitted(action: FightEnums.Action, timing: FightEnums.BeatTiming, window_id: int):
	if window_actions.has(window_id) and not window_actions[window_id].resolved:
		var window_action = window_actions[window_id]
		if not window_action.player_submitted:
			window_action.player_action = action
			window_action.player_timing = timing
			window_action.player_submitted = true
			
			# Immediately resolve this window since player acted within grace period
			_resolve_window_immediately(window_id)

func _on_enemy_action_submitted(action: FightEnums.Action, window_id: int):
	if window_actions.has(window_id) and not window_actions[window_id].resolved:
		var window_action = window_actions[window_id]
		if not window_action.enemy_submitted:
			window_action.enemy_action = action
			window_action.enemy_submitted = true

# Public method for player input - automatically targets earliest available window
func submit_player_action(action: FightEnums.Action):
	var earliest_window_id = BeatManager.get_earliest_open_window()
	if earliest_window_id == -1:
		return # No open windows
	
	var timing = BeatManager.get_timing_for_window(earliest_window_id)
	if timing == FightEnums.BeatTiming.NULL:
		return # Invalid timing
	
	player_action_submitted.emit(action, timing, earliest_window_id)

# Method for enemy to submit action to a specific window (or earliest if not specified)
func submit_enemy_action(action: FightEnums.Action, target_window_id: int = -1):
	var window_id = target_window_id
	if window_id == -1:
		window_id = BeatManager.get_earliest_open_window()
	
	if window_id == -1:
		return # No open windows
	
	enemy_action_submitted.emit(action, window_id)

# Internal function to resolve a specific window immediately when player acts
func _resolve_window_immediately(window_id: int):
	if not window_actions.has(window_id):
		return
	
	var window_action = window_actions[window_id]
	if window_action.resolved:
		return
	
	window_action.resolved = true
	
	# If enemy hasn't acted yet, default to WAIT
	if window_action.enemy_action == FightEnums.Action.NULL:
		window_action.enemy_action = FightEnums.Action.WAIT
	
	var result = determine_winner(window_action.player_action, window_action.enemy_action)
	var timing_bonus = get_timing_bonus(window_action.player_timing)
	
	actions_revealed.emit(window_action.player_action, window_action.enemy_action, result, timing_bonus, window_id)
	
	# Apply damage based on result
	match result:
		FightEnums.FightResult.ENEMY_HIT:
			if enemy_ref and enemy_ref.has_method("take_damage"):
				var damage = 1 + int(timing_bonus > 0.8)
				enemy_ref.take_damage(damage)
				print("Enemy takes ", damage, " damage (Window ", window_id, " - Immediate)")

		FightEnums.FightResult.PLAYER_HIT:
			if player_ref and player_ref.has_method("take_damage"):
				player_ref.take_damage(1)
				print("Player takes 1 damage (Window ", window_id, " - Immediate)")

		FightEnums.FightResult.BOTH_HIT:
			if enemy_ref and enemy_ref.has_method("take_damage"):
				var player_damage = 1 + int(timing_bonus > 0.8)
				enemy_ref.take_damage(player_damage)
			if player_ref and player_ref.has_method("stay_damage"):
				player_ref.take_damage(1)
			print("Both hit (Window ", window_id, " - Immediate)")

		FightEnums.FightResult.NONE_HIT:
			print("No hits (Window ", window_id, " - Immediate)")
	
	# Check for fight end
	if player_ref and player_ref.current_health <= 0:
		fight_ended.emit("Enemy")
	elif enemy_ref and enemy_ref.current_health <= 0:
		fight_ended.emit("Player")
	
	# Notify BeatManager to cancel this window's natural resolution
	_cancel_window_natural_resolution(window_id)
	
	# Clean up resolved window after a short delay
	get_tree().create_timer(0.1).timeout.connect(func(): _cleanup_window(window_id))

# Cancel the natural resolution of a window (since it was resolved immediately)
func _cancel_window_natural_resolution(window_id: int):
	# Mark the window as resolved in BeatManager so it doesn't trigger natural resolution
	BeatManager.mark_window_resolved(window_id)
	if not window_actions.has(window_id):
		return
	
	var window_action = window_actions[window_id]
	if window_action.resolved:
		return
	
# Internal function to resolve a specific window (natural resolution when window closes)
func _resolve_window(window_id: int):
	if not window_actions.has(window_id):
		return
	
	var window_action = window_actions[window_id]
	if window_action.resolved:
		return # Already resolved (likely immediately by player input)
	
	window_action.resolved = true
	
	# Ensure both actions are set (default to WAIT if not)
	if window_action.player_action == FightEnums.Action.NULL:
		window_action.player_action = FightEnums.Action.WAIT
	if window_action.enemy_action == FightEnums.Action.NULL:
		window_action.enemy_action = FightEnums.Action.WAIT
	
	var result = determine_winner(window_action.player_action, window_action.enemy_action)
	var timing_bonus = get_timing_bonus(window_action.player_timing)
	
	actions_revealed.emit(window_action.player_action, window_action.enemy_action, result, timing_bonus, window_id)
	
	# Apply damage based on result
	match result:
		FightEnums.FightResult.ENEMY_HIT:
			if enemy_ref and enemy_ref.has_method("take_damage"):
				var damage = 1 + int(timing_bonus > 0.8)
				enemy_ref.take_damage(damage)
				print("Enemy takes ", damage, " damage (Window ", window_id, " - Natural)")

		FightEnums.FightResult.PLAYER_HIT:
			if player_ref and player_ref.has_method("take_damage"):
				player_ref.take_damage(1)
				print("Player takes 1 damage (Window ", window_id, " - Natural)")

		FightEnums.FightResult.BOTH_HIT:
			if enemy_ref and enemy_ref.has_method("take_damage"):
				var player_damage = 1 + int(timing_bonus > 0.8)
				enemy_ref.take_damage(player_damage)
			if player_ref and player_ref.has_method("take_damage"):
				player_ref.take_damage(1)
			print("Both hit (Window ", window_id, " - Natural)")

		FightEnums.FightResult.NONE_HIT:
			print("No hits (Window ", window_id, " - Natural)")
	
	# Check for fight end
	if player_ref and player_ref.current_health <= 0:
		fight_ended.emit("Enemy")
	elif enemy_ref and enemy_ref.current_health <= 0:
		fight_ended.emit("Player")
	
	# Clean up resolved window after a short delay to allow for any final processing
	get_tree().create_timer(0.1).timeout.connect(func(): _cleanup_window(window_id))

func _cleanup_window(window_id: int):
	if window_actions.has(window_id):
		window_actions.erase(window_id)

func determine_winner(p_action: FightEnums.Action, e_action: FightEnums.Action) -> FightEnums.FightResult:
	# 1. Both attack at the same height -> BOTH_HIT
	if p_action in ATTACKS and e_action in ATTACKS:
		if p_action == e_action:
			return FightEnums.FightResult.BOTH_HIT

	# 2. Handle WAIT actions
	if p_action == FightEnums.Action.WAIT:
		if e_action in ATTACKS:
			return FightEnums.FightResult.PLAYER_HIT
		else:
			return FightEnums.FightResult.NONE_HIT
	
	if e_action == FightEnums.Action.WAIT:
		if p_action in ATTACKS:
			return FightEnums.FightResult.ENEMY_HIT
		else:
			return FightEnums.FightResult.NONE_HIT

	# 3. Handle Attack vs. Block scenarios
	var p_is_attack := p_action in ATTACKS
	var p_is_block := p_action in BLOCKS
	var e_is_attack := e_action in ATTACKS
	var e_is_block := e_action in BLOCKS

	if p_is_attack and e_is_block:
		if ATTACK_TO_BLOCK_MAP[p_action] == e_action:
			return FightEnums.FightResult.NONE_HIT
		else:
			return FightEnums.FightResult.ENEMY_HIT

	if p_is_block and e_is_attack:
		if BLOCK_TO_ATTACK_MAP[p_action] == e_action:
			return FightEnums.FightResult.NONE_HIT
		else:
			return FightEnums.FightResult.PLAYER_HIT

	# 4. Both blocking or other non-hitting combinations
	return FightEnums.FightResult.NONE_HIT

func get_timing_bonus(timing: FightEnums.BeatTiming) -> float:
	match timing:
		FightEnums.BeatTiming.PERFECT: return 1.0
		FightEnums.BeatTiming.GOOD: return 0.7
		FightEnums.BeatTiming.NICE: return 0.4
		_: return 0.0

# Utility methods for debugging and monitoring
func get_active_windows() -> Array[int]:
	var active_ids: Array[int] = []
	for window_id in window_actions.keys():
		if not window_actions[window_id].resolved:
			active_ids.append(window_id)
	return active_ids

func get_window_info(window_id: int) -> Dictionary:
	if not window_actions.has(window_id):
		return {}
	
	var window_action = window_actions[window_id]
	return {
		"window_id": window_action.window_id,
		"beat_count": window_action.beat_count,
		"player_action": window_action.player_action,
		"enemy_action": window_action.enemy_action,
		"player_timing": window_action.player_timing,
		"player_submitted": window_action.player_submitted,
		"enemy_submitted": window_action.enemy_submitted,
		"resolved": window_action.resolved
	}

# Legacy method for backward compatibility
func get_current_actions() -> Dictionary:
	var earliest_id = BeatManager.get_earliest_open_window()
	if earliest_id == -1 or not window_actions.has(earliest_id):
		return {"player": FightEnums.Action.NULL, "enemy": FightEnums.Action.NULL}
	
	var window_action = window_actions[earliest_id]
	return {
		"player": window_action.player_action,
		"enemy": window_action.enemy_action
	}
