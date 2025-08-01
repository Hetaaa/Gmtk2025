class_name Enemy extends Fighter

@export var max_health: int = 3
@export var move_pattern: Array[FightEnums.Action] = [
	FightEnums.Action.BLOCK_HIGH,
	FightEnums.Action.BLOCK_HIGH,
	FightEnums.Action.BLOCK_HIGH,
]

var current_health: int
var move_index: int = 0

func _ready():
	current_health = max_health
	# Register enemy with FightManager
	FightManager.register_enemy(self)
	
	# Connect to BeatManager signals
	BeatManager.action_window_open.connect(_on_action_window_open)
	BeatManager.action_window_close.connect(_on_action_window_close)
	
	# Ensure we have a valid move pattern
	if move_pattern.is_empty():
		move_pattern = [FightEnums.Action.WAIT]  # Default fallback

func get_next_action() -> FightEnums.Action:
	if move_pattern.is_empty():
		return FightEnums.Action.WAIT
	
	var action = move_pattern[move_index]
	move_index = (move_index + 1) % move_pattern.size()  # Loop back to start
	return action

func submit_enemy_action(target_window_id: int = -1):
	var action = get_next_action()
	
	# Use FightManager's method instead of direct signal emission
	FightManager.submit_enemy_action(action, target_window_id)
	
func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	# Visual damage effect
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	
# Method to change enemy's pattern mid-fight (optional)
func set_new_pattern(new_pattern: Array[FightEnums.Action]):
	move_pattern = new_pattern
	move_index = 0

# --- Signal Callbacks ---
func _on_action_window_open(window_id: int, beat_count: int) -> void:
	# Submit action for this specific window
	submit_enemy_action(window_id)
	modulate = Color.WHITE * 1.1

func _on_action_window_close(window_id: int, beat_count: int):
	# Visual cue for end of action window
	modulate = Color.WHITE * 0.9
