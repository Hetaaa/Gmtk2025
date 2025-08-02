# ScreenShake.gd - Attach this to your Camera2D node
extends Camera2D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_timer: float = 0.0
var original_offset: Vector2

func _ready():
	original_offset = offset
	
	# Connect to FightManager signal (assuming FightManager is autoloaded)
	if FightManager:
		FightManager.actions_revealed.connect(_on_actions_revealed)

func _process(delta):
	if shake_timer > 0:
		shake_timer -= delta
		
		# Generate random shake offset
		var shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		
		# Apply shake with decay
		var decay = shake_timer / shake_duration
		offset = original_offset + shake_offset * decay
		
		# End shake when timer expires
		if shake_timer <= 0:
			offset = original_offset
			shake_intensity = 0.0

func shake(intensity: float, duration: float):
	shake_intensity = intensity
	shake_duration = duration
	shake_timer = duration

func _on_actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float, window_id: int):
	if result == FightEnums.FightResult.ENEMY_HIT:
		var base_intensity = 50
		var base_duration = 0.2
		
		# Perfect timing gets stronger shake
		var intensity_multiplier = 1.0 + (timing_bonus * 0.5) # 1.0 to 1.5x
		var final_intensity = base_intensity * intensity_multiplier
		
		shake(final_intensity, base_duration)
