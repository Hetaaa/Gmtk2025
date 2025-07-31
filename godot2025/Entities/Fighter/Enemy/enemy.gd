class_name Enemy extends Fighter

@export var max_health: int = 3
@export var move_pattern: Array[FightEnums.Action] = [
	FightEnums.Action.ATTACK_HIGH,
	FightEnums.Action.BLOCK_MIDDLE,
	FightEnums.Action.ATTACK_LOW,
	FightEnums.Action.WAIT,
	FightEnums.Action.ATTACK_MIDDLE,
	FightEnums.Action.BLOCK_HIGH
]

var current_health: int
var move_index: int = 0
@onready var action_display: Label = $PlaceholderLabel

func _ready():
	current_health = max_health
	# Register enemy with FightManager
	FightManager.register_enemy(self)
	
	# Connect to BeatManager signals
	BeatManager.action_window_start.connect(_on_action_window_start)
	BeatManager.action_window_end.connect(_on_action_window_end)
	
	# Connect to FightManager's actions revealed signal
	FightManager.actions_revealed.connect(_on_actions_revealed)
	FightManager.fight_ended.connect(_on_fight_ended)
	
	
	# Ensure we have a valid move pattern
	if move_pattern.is_empty():
		move_pattern = [FightEnums.Action.WAIT]  # Default fallback

func get_next_action() -> FightEnums.Action:
	if move_pattern.is_empty():
		return FightEnums.Action.WAIT
	
	var action = move_pattern[move_index]
	move_index = (move_index + 1) % move_pattern.size()  # Loop back to start
	return action

func submit_enemy_action():
	var action = get_next_action()
	
	# Submit action to FightManager
	FightManager.enemy_action_submitted.emit(action)
	
	# Show what enemy is planning to do
	show_planned_action(action)

func show_planned_action(action: FightEnums.Action):
	var action_name = str(action).replace("FightEnums.Action.", "")
	var emoji = get_action_emoji(action)
	
	action_display.text = "Enemy: " + emoji + " " + action_name.capitalize()
	action_display.modulate = Color.ORANGE

func get_action_emoji(action: FightEnums.Action) -> String:
	match action:
		FightEnums.Action.ATTACK_HIGH: return "⚔️↗"  # Attack high
		FightEnums.Action.ATTACK_MIDDLE: return "⚔️→"  # Attack middle
		FightEnums.Action.ATTACK_LOW: return "⚔️↘"   # Attack low
		FightEnums.Action.BLOCK_HIGH: return "🛡️↗"   # Block high
		FightEnums.Action.BLOCK_MIDDLE: return "🛡️→"  # Block middle
		FightEnums.Action.BLOCK_LOW: return "🛡️↘"    # Block low
		FightEnums.Action.WAIT: return "⏳"
		_: return "❓"

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	# Visual damage effect
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	

# Add some randomness to make enemy less predictable (optional)
func randomize_pattern():
	move_pattern.shuffle()
	move_index = 0

# Method to change enemy's pattern mid-fight (optional)
func set_new_pattern(new_pattern: Array[FightEnums.Action]):
	move_pattern = new_pattern
	move_index = 0

# --- Signal Callbacks ---
func _on_action_window_start():
	# Enemy submits action immediately when window opens
	submit_enemy_action()
	
	# Visual cue for enemy action window
	modulate = Color.WHITE * 1.1

func _on_action_window_end():
	# Visual cue for end of action window
	modulate = Color.WHITE * 0.9

func _on_actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float):
	var player_emoji = get_action_emoji(player_action)
	var enemy_emoji = get_action_emoji(enemy_action)
	
	var result_text = ""
	var result_color = Color.WHITE
	
	# Show result from enemy's perspective
	match result:
		FightEnums.FightResult.PLAYER_HIT: # Player was hit (enemy succeeded)
			result_text = "ENEMY HIT PLAYER!"
			result_color = Color.RED
		FightEnums.FightResult.ENEMY_HIT: # Enemy was hit (player succeeded)
			result_text = "PLAYER HIT ENEMY!"
			result_color = Color.GREEN
		FightEnums.FightResult.BOTH_HIT:
			result_text = "BOTH HIT!"
			result_color = Color.ORANGE
		FightEnums.FightResult.NONE_HIT:
			result_text = "NO ONE HIT!"
			result_color = Color.YELLOW
	
	action_display.text = enemy_emoji + " vs " + player_emoji + " - " + result_text
	action_display.modulate = result_color
	
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _on_fight_ended(winner: String):
	if winner == "Enemy":
		action_display.text = "ENEMY VICTORY!"
		action_display.modulate = Color.RED
	elif winner == "Player":
		action_display.text = "ENEMY DEFEATED!"
		action_display.modulate = Color.BLUE

# --- Optional: Advanced enemy behaviors ---

# Make enemy react to player's previous actions (adaptive AI)
func _on_player_previous_action(action: FightEnums.Action):
	# Example: If player used high attacks frequently, enemy might block high more
	# This is just an example - implement your own logic
	pass

# Different difficulty patterns
func set_difficulty_easy():
	move_pattern = [
		FightEnums.Action.WAIT,
		FightEnums.Action.ATTACK_MIDDLE,
		FightEnums.Action.WAIT,
		FightEnums.Action.BLOCK_MIDDLE
	]
	move_index = 0

func set_difficulty_medium():
	move_pattern = [
		FightEnums.Action.ATTACK_HIGH,
		FightEnums.Action.BLOCK_LOW,
		FightEnums.Action.ATTACK_LOW,
		FightEnums.Action.BLOCK_HIGH,
		FightEnums.Action.ATTACK_MIDDLE,
		FightEnums.Action.WAIT
	]
	move_index = 0

func set_difficulty_hard():
	move_pattern = [
		FightEnums.Action.ATTACK_HIGH,
		FightEnums.Action.ATTACK_LOW,
		FightEnums.Action.BLOCK_MIDDLE,
		FightEnums.Action.ATTACK_MIDDLE,
		FightEnums.Action.BLOCK_HIGH,
		FightEnums.Action.ATTACK_LOW,
		FightEnums.Action.BLOCK_LOW,
		FightEnums.Action.ATTACK_HIGH
	]
	move_index = 0
