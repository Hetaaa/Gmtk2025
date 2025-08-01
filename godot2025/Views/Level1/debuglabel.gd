extends Label

# Export variables for customization
@export var show_beat_count: bool = true
@export var show_measure_count: bool = true
@export var show_bpm: bool = true
@export var show_timing_window: bool = true
@export var show_current_actions: bool = true
@export var show_health_status: bool = true

# Animation settings
@export var flash_on_beat: bool = true
@export var flash_duration: float = 0.1

# Display formatting
var display_lines: Array[String] = []

func _ready():
	# Set up label properties
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP
	add_theme_font_size_override("font_size", 14)
	
	# Connect to BeatManager signals
	BeatManager.beat_hit.connect(_on_beat_hit)
	BeatManager.measure_complete.connect(_on_measure_complete)
	BeatManager.action_window_open.connect(_on_action_window_start)
	BeatManager.action_window_close.connect(_on_action_window_end)
	BeatManager.tempo_changed.connect(_on_tempo_changed)
	
	# Connect to FightManager signals
	FightManager.actions_revealed.connect(_on_actions_revealed)
	FightManager.fight_ended.connect(_on_fight_ended)
	
	# Initial display update
	update_display()

func update_display():
	display_lines.clear()
	
	# Beat and measure info
	if show_beat_count:
		display_lines.append("Beat: " + str(BeatManager.beat_count))
	
	if show_measure_count:
		display_lines.append("Measure: " + str(BeatManager.measure_count))
	
	if show_bpm:
		display_lines.append("BPM: " + str(BeatManager.bpm))
	
	
	# Current queued actions
	if show_current_actions:
		var actions = FightManager.get_current_actions()
		var player_action = get_action_name(actions.get("player", FightEnums.Action.NULL))
		var enemy_action = get_action_name(actions.get("enemy", FightEnums.Action.NULL))
		
		display_lines.append("Player: " + get_action_emoji(actions.get("player", FightEnums.Action.NULL)) + " " + player_action)
		display_lines.append("Enemy: " + get_action_emoji(actions.get("enemy", FightEnums.Action.NULL)) + " " + enemy_action)
	
	# Health status
	if show_health_status:
		var player_health = get_player_health()
		var enemy_health = get_enemy_health()
		display_lines.append("Health - Player: " + str(player_health) + " | Enemy: " + str(enemy_health))
	
	# Update the label text
	text = "\n".join(display_lines)

func get_player_health() -> String:
	if FightManager.player_ref and FightManager.player_ref.has_method("get") and FightManager.player_ref.current_health != null:
		return str(FightManager.player_ref.current_health) + "/" + str(FightManager.player_ref.max_health)
	return "N/A"

func get_enemy_health() -> String:
	if FightManager.enemy_ref and FightManager.enemy_ref.has_method("get") and FightManager.enemy_ref.current_health != null:
		return str(FightManager.enemy_ref.current_health) + "/" + str(FightManager.enemy_ref.max_health)
	return "N/A"

func get_action_name(action: FightEnums.Action) -> String:
	if action == FightEnums.Action.NULL:
		return "None"
	return str(action).replace("FightEnums.Action.", "").capitalize()

func get_action_emoji(action: FightEnums.Action) -> String:
	match action:
		FightEnums.Action.ATTACK_HIGH: return "⚔️↗"
		FightEnums.Action.ATTACK_MIDDLE: return "⚔️→"
		FightEnums.Action.ATTACK_LOW: return "⚔️↘"
		FightEnums.Action.BLOCK_HIGH: return "🛡️↗"
		FightEnums.Action.BLOCK_MIDDLE: return "🛡️→"
		FightEnums.Action.BLOCK_LOW: return "🛡️↘"
		FightEnums.Action.WAIT: return "⏳"
		FightEnums.Action.NULL: return "❓"
		_: return "❓"

func get_timing_name(timing: FightEnums.BeatTiming) -> String:
	match timing:
		FightEnums.BeatTiming.PERFECT: return "PERFECT"
		FightEnums.BeatTiming.GOOD: return "GOOD"
		FightEnums.BeatTiming.NICE: return "NICE"
		FightEnums.BeatTiming.EARLY: return "EARLY"
		FightEnums.BeatTiming.LATE: return "LATE"
		FightEnums.BeatTiming.NULL: return "N/A"
		_: return "UNKNOWN"

func get_timing_color(timing: FightEnums.BeatTiming) -> Color:
	match timing:
		FightEnums.BeatTiming.PERFECT: return Color.GOLD
		FightEnums.BeatTiming.GOOD: return Color.GREEN
		FightEnums.BeatTiming.NICE: return Color.BLUE
		FightEnums.BeatTiming.EARLY, FightEnums.BeatTiming.LATE: return Color.ORANGE
		_: return Color.WHITE

# --- Signal Callbacks ---
func _on_beat_hit(beat_count: int):
	update_display()
	
	if flash_on_beat:
		flash_beat_indicator()

func _on_measure_complete(measure_count: int):
	update_display()
	
	# Special flash for measure completion
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.YELLOW, 0.1)
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func _on_action_window_start():
	update_display()
	modulate = Color.WHITE * 1.2  # Brighten when window opens

func _on_action_window_end():
	update_display()
	modulate = Color.WHITE * 0.8  # Dim when window closes

func _on_tempo_changed(new_bpm: float):
	update_display()

func _on_actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float):
	update_display()
	
	# Show result with color coding
	var result_color = Color.WHITE
	match result:
		FightEnums.FightResult.PLAYER_HIT:
			result_color = Color.RED
		FightEnums.FightResult.ENEMY_HIT:
			result_color = Color.GREEN
		FightEnums.FightResult.BOTH_HIT:
			result_color = Color.ORANGE
		FightEnums.FightResult.NONE_HIT:
			result_color = Color.YELLOW
	
	# Flash with result color
	var tween = create_tween()
	tween.tween_property(self, "modulate", result_color, 0.2)
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func _on_fight_ended(winner: String):
	var end_color = Color.RED if winner == "Enemy" else Color.GREEN
	modulate = end_color
	
	# Add fight end status to display
	display_lines.append("FIGHT ENDED - " + winner.to_upper() + " WINS!")
	text = "\n".join(display_lines)

func flash_beat_indicator():
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.CYAN, flash_duration)
	tween.tween_property(self, "modulate", Color.WHITE, flash_duration)

# --- Process update for real-time timing display ---
func _process(_delta):
	update_display()

# --- Utility functions for external control ---
func toggle_beat_flash():
	flash_on_beat = !flash_on_beat

func set_display_options(beat: bool = true, measure: bool = true, bpm: bool = true, timing: bool = true, actions: bool = true, health: bool = true):
	show_beat_count = beat
	show_measure_count = measure
	show_bpm = bpm
	show_timing_window = timing
	show_current_actions = actions
	show_health_status = health
	update_display()

func reset_display():
	modulate = Color.WHITE
	update_display()
