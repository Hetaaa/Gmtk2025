extends Node

# Signals for fight events
signal actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float)
signal fight_ended(winner: String)

# Signals for receiving actions from player/enemy (these remain internal to FightManager for listening)
signal player_action_submitted(action: FightEnums.Action, timing: FightEnums.BeatTiming)
signal enemy_action_submitted(action: FightEnums.Action)

var player_ref: Node # Keep references for health management
var enemy_ref: Node  # Keep references for health management

var player_action_queued: FightEnums.Action = FightEnums.Action.NULL
var enemy_action_queued: FightEnums.Action = FightEnums.Action.NULL
var player_timing_queued: FightEnums.BeatTiming = FightEnums.BeatTiming.NULL

# Flag to control if actions can be submitted
var accepting_submissions: bool = false

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

# Helper arrays to easily check action types
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
	BeatManager.action_window_start.connect(_on_action_window_start)
	BeatManager.action_window_end.connect(_on_action_window_end)
	BeatManager.execute_actions.connect(_on_execute_actions)
	
	player_action_submitted.connect(_on_player_action_submitted)
	enemy_action_submitted.connect(_on_enemy_action_submitted)

func register_player(player: Player):
	player_ref = player

func register_enemy(enemy: Enemy):
	enemy_ref = enemy

# --- Signal Callbacks from BeatManager ---
func _on_action_window_start():
	accepting_submissions = true
	# Reset queued actions at the start of a new window
	reset_round_queued_actions()

func _on_action_window_end():
	accepting_submissions = false
	# If no action was submitted, default to WAIT
	if player_action_queued == FightEnums.Action.NULL:
		player_action_queued = FightEnums.Action.WAIT
	if enemy_action_queued == FightEnums.Action.NULL:
		enemy_action_queued = FightEnums.Action.WAIT

func _on_execute_actions():
	resolve_fight_round()

# --- Callbacks for Action Submission Signals ---
func _on_player_action_submitted(action: FightEnums.Action, timing: FightEnums.BeatTiming):
	if accepting_submissions:
		player_action_queued = action
		player_timing_queued = timing
	else:
		print("Player action submitted outside input window!")

func _on_enemy_action_submitted(action: FightEnums.Action):
	if accepting_submissions:
		enemy_action_queued = action
	else:
		print("Enemy action submitted outside input window!")

func resolve_fight_round():
	var result = determine_winner(player_action_queued, enemy_action_queued)
	var timing_bonus = get_timing_bonus(player_timing_queued)
	
	actions_revealed.emit(player_action_queued, enemy_action_queued, result, timing_bonus)
	
	# Apply damage based on result
	match result:
		FightEnums.FightResult.ENEMY_HIT: # This means player's attack hit the enemy
			if enemy_ref and enemy_ref.has_method("take_damage"):
				var damage = 1 + int(timing_bonus > 0.8)  # Perfect timing = extra damage
				enemy_ref.take_damage(damage)
		
		FightEnums.FightResult.PLAYER_HIT: # This means enemy's attack hit the player
			if player_ref and player_ref.has_method("take_damage"):
				player_ref.take_damage(1) # Assuming enemy damage is always 1 for simplicity

		FightEnums.FightResult.BOTH_HIT: # Both hit each other
			if enemy_ref and enemy_ref.has_method("take_damage"):
				var player_damage = 1 + int(timing_bonus > 0.8)
				enemy_ref.take_damage(player_damage)
			if player_ref and player_ref.has_method("take_damage"):
				player_ref.take_damage(1) # Assuming enemy damage is always 1

		FightEnums.FightResult.NONE_HIT: # No one hit (e.g., successful block, or both waited/blocked)
			pass
	
	# Check for fight end
	if player_ref and player_ref.current_health <= 0:
		fight_ended.emit("Enemy") # Enemy wins if player health <= 0
	elif enemy_ref and enemy_ref.current_health <= 0:
		fight_ended.emit("Player") # Player wins if enemy health <= 0

func determine_winner(p_action: FightEnums.Action, e_action: FightEnums.Action) -> FightEnums.FightResult:
	# 1. Both attack at the same height -> BOTH_HIT
	if p_action in ATTACKS and e_action in ATTACKS:
		if ATTACK_TO_BLOCK_MAP.get(p_action) == BLOCK_TO_ATTACK_MAP.get(e_action): # Checks if they're the "same height" attack
			return FightEnums.FightResult.BOTH_HIT

	# 2. Handle WAIT actions
	if p_action == FightEnums.Action.WAIT:
		if e_action in ATTACKS:
			return FightEnums.FightResult.PLAYER_HIT # Player waits, enemy attacks -> Player hit
		else:
			return FightEnums.FightResult.NONE_HIT # Player waits, enemy blocks/waits -> No one hit
	
	if e_action == FightEnums.Action.WAIT:
		if p_action in ATTACKS:
			return FightEnums.FightResult.ENEMY_HIT # Enemy waits, player attacks -> Enemy hit
		else:
			return FightEnums.FightResult.NONE_HIT # Enemy waits, player blocks/waits -> No one hit

	# 3. Handle Attack vs. Block/Other Attack Scenarios
	var p_is_attack := p_action in ATTACKS
	var p_is_block := p_action in BLOCKS
	var e_is_attack := e_action in ATTACKS
	var e_is_block := e_action in BLOCKS

	if p_is_attack and e_is_block:
		# Player attacks, Enemy blocks
		if ATTACK_TO_BLOCK_MAP[p_action] == e_action:
			return FightEnums.FightResult.NONE_HIT # Correct block
		else:
			return FightEnums.FightResult.ENEMY_HIT # Wrong block

	if p_is_block and e_is_attack:
		# Player blocks, Enemy attacks
		if BLOCK_TO_ATTACK_MAP[p_action] == e_action:
			return FightEnums.FightResult.NONE_HIT # Correct block
		else:
			return FightEnums.FightResult.PLAYER_HIT # Wrong block

	# 4. If nothing above, it's likely both blocking, or some other non-hitting combo
	# This acts as a fallback for cases like both blocking or other unhandled scenarios resulting in no hit.
	return FightEnums.FightResult.NONE_HIT

func get_timing_bonus(timing: FightEnums.BeatTiming) -> float:
	match timing:
		FightEnums.BeatTiming.PERFECT: return 1.0
		FightEnums.BeatTiming.GOOD: return 0.7
		FightEnums.BeatTiming.NICE: return 0.4
		_: return 0.0

func reset_round_queued_actions():
	player_action_queued = FightEnums.Action.NULL
	enemy_action_queued = FightEnums.Action.NULL
	player_timing_queued = FightEnums.BeatTiming.NULL

func get_current_actions() -> Dictionary:
	return {
		"player": player_action_queued,
		"enemy": enemy_action_queued
	}
