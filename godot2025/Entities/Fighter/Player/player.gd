class_name Player extends Fighter

@export var max_health: int = 3

var current_health: int
var selected_action_enum: FightEnums.Action = FightEnums.Action.NULL # Store the enum value
var selected_timing_enum: FightEnums.BeatTiming = FightEnums.BeatTiming.NULL

func _ready():
	current_health = max_health
	FightManager.register_player(self)
	


func _input(event):
	# Allow input anytime, but let the system validate timing	
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
	# Use the new submit method which handles timing validation internally
	FightManager.submit_player_action(action)
	var timing = BeatManager.get_current_beat_timing()
	print(FightEnums.Action.keys()[action] + ' ' + FightEnums.BeatTiming.keys()[timing])
	
	# Store the selected action and timing locally for display
	selected_action_enum = action
	selected_timing_enum = timing
	

func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	# Visual damage effect
	modulate = Color.RED
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)
