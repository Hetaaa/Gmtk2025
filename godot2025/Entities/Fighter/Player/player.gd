class_name Player extends Fighter

@export var max_health: int = 3
@onready var  action_display: Label = $PlaceholderLabel

var current_health: int
var selected_action_enum: FightEnums.Action = FightEnums.Action.NULL # Store the enum value
var selected_timing_enum: FightEnums.BeatTiming = FightEnums.BeatTiming.NULL



func _ready():
	current_health = max_health
	# Register player with FightManager (still a direct call as FightManager manages player state)
	FightManager.register_player(self)
	
	# Connect to BeatManager signals directly using its autoload name
	BeatManager.action_window_start.connect(_on_action_window_start)
	BeatManager.action_window_end.connect(_on_action_window_end)
	
	# Connect to FightManager's actions revealed signal
	FightManager.actions_revealed.connect(_on_actions_revealed)
	FightManager.fight_ended.connect(_on_fight_ended) # Optional: handle game over

func _input(event):
	if not FightManager.accepting_submissions:
		return
	
	if event.is_action_pressed("ATTACK_HIGH"):
		submit_player_action_to_manager(FightEnums.Action.ATTACK_HIGH)
	elif event.is_action_pressed("ATTACK_LOW"):
		submit_player_action_to_manager(FightEnums.Action.ATTACK_LOW)
	elif event.is_action_pressed("ATTACK_MID"):
		submit_player_action_to_manager(FightEnums.Action.ATTACK_MIDDLE)
	elif event.is_action_pressed("BLOCK_HIGH"):
		submit_player_action_to_manager(FightEnums.Action.BLOCK_HIGH)
	elif event.is_action_pressed("BLOCK_LOW"):
		submit_player_action_to_manager(FightEnums.Action.BLOCK_LOW)
	elif event.is_action_pressed("BLOCK_MID"):
		submit_player_action_to_manager(FightEnums.Action.BLOCK_MIDDLE)
func submit_player_action_to_manager(action: FightEnums.Action):
	# Get current timing from BeatManager
	var timing = BeatManager.get_current_beat_timing()
	print(FightEnums.BeatTiming.keys()[timing] +' ' +str(BeatManager.get_current_beat_timing_ms())+ 'ms')
	
	# Emit the signal to FightManager to submit the action
	# FightManager will handle whether it successfully queues it or not based on its 'accepting_submissions'
	FightManager.player_action_submitted.emit(action, timing)
	
	# Store the selected action and timing locally for display
	selected_action_enum = action
	selected_timing_enum = timing
	
	show_selected_action_on_display(action, timing)

func show_selected_action_on_display(action: FightEnums.Action, timing: FightEnums.BeatTiming):
	var action_name = str(action).replace("FightEnums.Action.", "") 
	var timing_name = str(timing).replace("FightEnums.BeatTiming.", "")
	
	var emoji = get_action_emoji(action)
	var color = get_timing_color(timing)
	
	action_display.text = "Selected: " + emoji + " " + action_name.capitalize() + " (" + timing_name + ")"
	action_display.modulate = color

func get_timing_color(timing: FightEnums.BeatTiming) -> Color:
	match timing:
		FightEnums.BeatTiming.PERFECT: return Color.GOLD
		FightEnums.BeatTiming.GOOD: return Color.GREEN
		FightEnums.BeatTiming.NICE: return Color.BLUE
		FightEnums.BeatTiming.LATE: return Color.ORANGE
		FightEnums.BeatTiming.EARLY: return Color.PURPLE
		_: return Color.RED # For NULL

func get_action_emoji(action: FightEnums.Action) -> String:
	match action:
		FightEnums.Action.ATTACK_HIGH, FightEnums.Action.ATTACK_MIDDLE, FightEnums.Action.ATTACK_LOW: return "⚔️" # Generic attack
		FightEnums.Action.BLOCK_HIGH, FightEnums.Action.BLOCK_MIDDLE, FightEnums.Action.BLOCK_LOW: return "🛡️" # Generic block
		FightEnums.Action.WAIT: return "⏳"
		_: return "❓"

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	# Visual damage effect
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	

# --- Signal Callbacks from BeatManager and FightManager ---
func _on_action_window_start():
	# Reset local selections for the new round
	selected_action_enum = FightEnums.Action.NULL
	selected_timing_enum = FightEnums.BeatTiming.NULL
	
	action_display.text = "Choose Your Action!" # Update prompt
	action_display.modulate = Color.WHITE
	modulate = Color.WHITE * 1.2 # Visual cue for start of input window

func _on_action_window_end(): 
	# If no action was selected (meaning the player didn't input anything during the window)
	if selected_action_enum == FightEnums.Action.NULL:
		# FightManager will automatically set this to WAIT, but we can show it here too
		action_display.text = "No action selected! Defaulting to WAIT."
		action_display.modulate = Color.RED
	modulate = Color.WHITE * 0.8 # Visual cue for end of input window

func _on_actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float):
	var player_emoji = get_action_emoji(player_action)
	var enemy_emoji = get_action_emoji(enemy_action)
	
	var result_text = ""
	var result_color = Color.WHITE
	
	# Convert FightEnums.FightResult to string for display if needed, or match directly
	match result:
		FightEnums.FightResult.PLAYER_HIT: # This means the *player* was hit
			result_text = "YOU WERE HIT!"
			result_color = Color.RED
		FightEnums.FightResult.ENEMY_HIT: # This means the *enemy* was hit (player's attack landed)
			result_text = "YOU HIT THE ENEMY!"
			if timing_bonus > 0.8: # Check for perfect timing bonus
				result_text += " (PERFECT!)"
			result_color = Color.GREEN
		FightEnums.FightResult.BOTH_HIT:
			result_text = "BOTH HIT!"
			result_color = Color.ORANGE
		FightEnums.FightResult.NONE_HIT:
			result_text = "NO ONE HIT!"
			result_color = Color.YELLOW
	
	action_display.text = player_emoji + " vs " + enemy_emoji + " - " + result_text
	action_display.modulate = result_color
	
	var tween = create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)

func _on_fight_ended(winner: String):
	if winner == "Enemy":
		action_display.text = "DEFEATED!"
		action_display.modulate = Color.RED
		# Handle player defeat (e.g., show game over screen)
	elif winner == "Player":
		action_display.text = "VICTORY!"
		action_display.modulate = Color.GOLD
		# Handle player victory (e.g., show win screen)
