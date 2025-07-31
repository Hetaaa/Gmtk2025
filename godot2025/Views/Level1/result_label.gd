extends Label


@export var display_duration: float = 2.0  # How long to show the result

func _ready():
	# Set up label properties
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 24)
	
	# Connect to FightManager
	FightManager.actions_revealed.connect(_on_actions_revealed)
	FightManager.fight_ended.connect(_on_fight_ended)
	
	# Start hidden
	text = ""
	modulate = Color.TRANSPARENT

func _on_actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float):
	var result_text = ""
	var result_color = Color.WHITE
	
	match result:
		FightEnums.FightResult.PLAYER_HIT:
			result_text = "PLAYER HIT!"
			result_color = Color.RED
		FightEnums.FightResult.ENEMY_HIT:
			result_text = "ENEMY HIT!"
			if timing_bonus > 0.8:
				result_text = "ENEMY HIT! PERFECT!"
			result_color = Color.GREEN
		FightEnums.FightResult.BOTH_HIT:
			result_text = "BOTH HIT!"
			result_color = Color.ORANGE
		FightEnums.FightResult.NONE_HIT:
			result_text = "BLOCKED!"
			result_color = Color.YELLOW
	
	show_result(result_text, result_color)

func _on_fight_ended(winner: String):
	var end_text = winner.to_upper() + " WINS!"
	var end_color = Color.RED if winner == "Enemy" else Color.GREEN
	show_result(end_text, end_color, 5.0)  # Show longer for fight end

func show_result(result_text: String, color: Color, duration: float = display_duration):
	text = result_text
	modulate = color
	
	# Fade in
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale up effect
	scale = Vector2(0.5, 0.5)
	tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.1).set_delay(0.1)
	
	# Fade out after duration
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5).set_delay(duration)
