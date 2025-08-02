extends Node2D

## Configuration
@export var preview_count: int = 3 # How many future actions to display
@export var base_position_offset: Vector2 = Vector2(0, -200) # The final position for the *first* action
@export var spacing: float = 100.0 # Vertical spacing between actions at their final positions
@export var base_scale: float = 0.3
@export var scale_reduction: float = 0.1 # Scale reduction per subsequent action
@export var base_alpha: float = 1.0
@export var alpha_reduction: float = 0.3 # Alpha reduction per subsequent action

@export var sprite_start_offset_y: float = -300.0 # Y-offset for starting position (above final pos)
@export var sprite_start_scale_multiplier: float = 0.5 # Scale at the start of the animation
@export var slide_ease_trans: Tween.TransitionType = Tween.TRANS_SINE
@export var slide_ease_type: Tween.EaseType = Tween.EASE_OUT

@export var active_sprite_scale_multiplier: float = 1.2 # Scale for the currently active action
@export var beat_scale_multiplier: float = 1.3 # Pop scale on beat hit
@export var beat_duration: float = 0.15 # Duration of the beat pop animation

@export var action_textures: Dictionary = {} # Preload textures here or assign via inspector

## Constants
const MIN_ALPHA: float = 0.1

## Internal variables
var _action_sprites: Array[Dictionary] = [] # Stores {sprite: Sprite2D, target_beat_time: float}
var _enemy_ref: Enemy
var _last_known_music_position: float = 0.0 # To track music progress

func _ready() -> void:
	# Ensure BeatManager is available
	if not is_instance_valid(BeatManager):
		push_error("EnemyActionPreview: BeatManager instance not found. Please ensure it's in the scene.")
		return

	# Connect signals
	BeatManager.beat_hit.connect(_on_beat_hit)
	BeatManager.action_window_open.connect(_on_action_window_open)
	BeatManager.resolve_current_round.connect(_on_resolve_current_round) # To clean up past actions
	FightManager.fight_ended.connect(_on_fight_ended)
	
	# Get parent reference
	_enemy_ref = get_parent() as Enemy
	if not _enemy_ref:
		push_error("EnemyActionPreview: This node must be a child of an 'Enemy' node.")
		return
	
	_preload_action_textures()
	_initialize_previews()

func _preload_action_textures() -> void:
	for action_enum_value in FightEnums.Action.values():
		var action_key = str(action_enum_value)
		if not action_textures.has(action_key):
			var texture_path = _get_texture_path(action_enum_value)
			if ResourceLoader.exists(texture_path):
				action_textures[action_key] = load(texture_path)

func _initialize_previews() -> void:
	# Clear any existing sprites first
	_clear_all_sprites()
	
	# Get the initial set of upcoming actions
	var upcoming_actions_data = _get_upcoming_actions_with_timing()
	
	for i in range(min(preview_count, upcoming_actions_data.size())):
		var action_data = upcoming_actions_data[i]
		_create_and_animate_sprite(action_data.action, action_data.relative_beat_time, i)

func _clear_all_sprites() -> void:
	for item in _action_sprites:
		var sprite = item.sprite as Sprite2D
		if is_instance_valid(sprite):
			sprite.queue_free()
	_action_sprites.clear()

func _get_upcoming_actions_with_timing() -> Array[Dictionary]:
	var actions_data: Array[Dictionary] = []
	
	if not _enemy_ref or _enemy_ref.move_pattern.is_empty():
		return actions_data
	
	var pattern = _enemy_ref.move_pattern
	var current_move_index = _enemy_ref.move_index # This is the index of the *next* action

	var music_player_ref = BeatManager.music_player
	if not music_player_ref or not music_player_ref.is_playing():
		_last_known_music_position = 0.0 # Or handle initial state appropriately
	else:
		_last_known_music_position = music_player_ref.get_playback_position()
	
	var seconds_per_beat = BeatManager.seconds_per_beat
	var timing_offset = BeatManager.timing_offset

	# Calculate the absolute time of the *next* beat relative to the song's start
	var next_absolute_beat_time = (floor(_last_known_music_position / seconds_per_beat) + 1) * seconds_per_beat - timing_offset

	for i in range(preview_count):
		var action_index_in_pattern = (current_move_index + i) % pattern.size()
		var action_enum = pattern[action_index_in_pattern]
		
		# Calculate the absolute time this action's beat will occur
		# This assumes move_index updates on beat_hit, so i=0 is the current beat's action
		var action_beat_absolute_time = next_absolute_beat_time + (i * seconds_per_beat)

		# Calculate the time remaining until this action's beat, from the current music position
		var time_to_arrival = action_beat_absolute_time - _last_known_music_position

		# Only add if it's a future action (or very nearly current, with a small buffer)
		if time_to_arrival > -0.05: # Allow a small buffer for already active or slightly past beats
			actions_data.append({
				"action": action_enum,
				"relative_beat_time": time_to_arrival, # Time until this specific beat hits
				"display_index": i # Store the logical display index for positioning/scaling
			})
	
	return actions_data

func _create_and_animate_sprite(action: FightEnums.Action, time_to_arrival: float, display_index: int) -> void:
	var sprite = Sprite2D.new()
	add_child(sprite)
	
	var texture = _get_action_texture(action)
	if not texture:
		sprite.queue_free() # Don't add if no texture
		return

	sprite.texture = texture
	sprite.visible = true # Make visible for animation

	# Calculate final position, scale, and alpha
	var final_pos_y = base_position_offset.y - (display_index * spacing)
	var final_position = Vector2(base_position_offset.x, final_pos_y)
	
	var target_scale_factor = base_scale - (display_index * scale_reduction)
	var target_scale = Vector2(target_scale_factor, target_scale_factor)
	
	var target_alpha = max(MIN_ALPHA, base_alpha - (display_index * alpha_reduction))

	# Set initial position (off-screen top) and scale/alpha
	sprite.position = final_position + Vector2(0, sprite_start_offset_y)
	sprite.scale = target_scale * sprite_start_scale_multiplier
	sprite.modulate.a = 0.0 # Start invisible and fade in

	# Store sprite data
	_action_sprites.append({
		"sprite": sprite,
		"target_beat_time": time_to_arrival, # This is the time *from now* until it should arrive
		"final_position": final_position,
		"final_scale": target_scale,
		"final_alpha": target_alpha,
		"display_index": display_index # Keep track of its current logical order
	})

	# Create tween for this individual sprite
	var slide_tween = create_tween()
	slide_tween.set_parallel(true)
	
	# Animate position
	slide_tween.tween_property(sprite, "position", final_position, time_to_arrival)\
		.set_ease(slide_ease_type).set_trans(slide_ease_trans) # Corrected here!
		
	# Animate scale
	slide_tween.tween_property(sprite, "scale", target_scale, time_to_arrival)\
		.set_ease(slide_ease_type).set_trans(slide_ease_trans) # Corrected here!

	# Animate alpha
	slide_tween.tween_property(sprite, "modulate:a", target_alpha, time_to_arrival * 0.5)\
		.set_delay(time_to_arrival * 0.1) # Start fading in a bit later

	# If this is the first (active) sprite, adjust its scale slightly more
	if display_index == 0:
		slide_tween.tween_property(sprite, "scale", target_scale * active_sprite_scale_multiplier, time_to_arrival)\
			.set_ease(slide_ease_type).set_trans(slide_ease_trans) # Corrected here!
		
	# When animation finishes, mark it as active (if it's the first one)
	slide_tween.tween_callback(func():
		_on_sprite_arrival(sprite, display_index)
	).set_delay(time_to_arrival) # Callback at the end of the slide


func _on_sprite_arrival(sprite_arrived: Sprite2D, display_index: int) -> void:
	# No need to do anything special here as `_on_beat_hit` will handle the next state.
	# This function is mostly for debugging or if you need precise callback at arrival.
	pass

func _get_action_texture(action: FightEnums.Action) -> Texture2D:
	if action == null:
		return null
	
	var action_key = str(action)
	if action_textures.has(action_key):
		return action_textures[action_key]
	
	var texture_path = _get_texture_path(action)
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		action_textures[action_key] = texture
		return texture
	
	return null

func _get_texture_path(action: FightEnums.Action) -> String:
	var base_path = "res://Entities/Fighter/Enemy/Assets/AttackIcons/"
	
	match action:
		FightEnums.Action.ATTACK_HIGH: return base_path + "attack_up.png"
		FightEnums.Action.ATTACK_MIDDLE: return base_path + "attack_mid.png"
		FightEnums.Action.ATTACK_LOW: return base_path + "attack_down.png"
		FightEnums.Action.BLOCK_HIGH: return base_path + "block_up.png"
		FightEnums.Action.BLOCK_MIDDLE: return base_path + "block_mid.png"
		FightEnums.Action.BLOCK_LOW: return base_path + "block_down.png"
		_: return base_path + "wait.png"


### Signal Handlers ###

# This will trigger for EACH beat. We want the first sprite to pop.
func _on_beat_hit(beat_count: int) -> void:
	# Trigger beat effect on the currently active (first) sprite
	if not _action_sprites.is_empty():
		var first_sprite_data = _action_sprites[0]
		trigger_beat_effect(first_sprite_data.sprite)

# The action window opening signifies that the *next* action is becoming active.
# This is where we might want to ensure the _new_ first sprite is fully in place.
func _on_action_window_open(window_id: int, beat_count: int):
	# In this new system, sprites are constantly moving.
	# When the window opens, it means the first sprite is 'active'.
	# We might want to slightly adjust its visuals or prepare for input,
	# but the slide-in is already handled by its individual tween.
	
	# Optional: visually emphasize the first sprite further.
	if not _action_sprites.is_empty():
		var first_sprite_data = _action_sprites[0]
		var sprite = first_sprite_data.sprite as Sprite2D
		
		var original_scale = first_sprite_data.final_scale # Use its final scale as base
		var active_scale = original_scale * active_sprite_scale_multiplier

		var emphasis_tween = create_tween()
		emphasis_tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		emphasis_tween.tween_property(sprite, "scale", active_scale, 0.1)
		emphasis_tween.tween_property(sprite, "scale", original_scale, 0.2).set_delay(0.1)


# When the round resolves, the *previous* action is done, and we need to update the display.
func _on_resolve_current_round() -> void:
	if _action_sprites.is_empty():
		return

	# Remove the first sprite (the one that just completed)
	var completed_sprite_data = _action_sprites.pop_front()
	var completed_sprite = completed_sprite_data.sprite as Sprite2D
	
	# Tween out the completed sprite
	var fade_out_tween = create_tween()
	fade_out_tween.set_parallel(true)
	fade_out_tween.tween_property(completed_sprite, "modulate:a", 0.0, BeatManager.grace_period / 2.0) # Fade out
	fade_out_tween.tween_property(completed_sprite, "scale", completed_sprite_data.final_scale * 0.5, BeatManager.grace_period / 2.0) # Shrink
	fade_out_tween.tween_callback(completed_sprite.queue_free) # Delete after fading out

	# Shift all remaining sprites up and re-tween their positions
	for i in range(_action_sprites.size()):
		var sprite_data = _action_sprites[i]
		var sprite = sprite_data.sprite as Sprite2D
		
		# Recalculate target position based on new display index
		var new_final_pos_y = base_position_offset.y - (i * spacing)
		var new_final_position = Vector2(base_position_offset.x, new_final_pos_y)
		
		var new_target_scale_factor = base_scale - (i * scale_reduction)
		var new_target_scale = Vector2(new_target_scale_factor, new_target_scale_factor)
		
		var new_target_alpha = max(MIN_ALPHA, base_alpha - (i * alpha_reduction))

		# Update stored final values
		sprite_data.final_position = new_final_position
		sprite_data.final_scale = new_target_scale
		sprite_data.final_alpha = new_target_alpha
		sprite_data.display_index = i # Update display index

		var shift_tween = create_tween()
		shift_tween.set_parallel(true)
		shift_tween.tween_property(sprite, "position", new_final_position, BeatManager.seconds_per_beat * 0.5)\
			.set_ease(slide_ease_type).set_trans(slide_ease_trans)
		shift_tween.tween_property(sprite, "scale", new_target_scale, BeatManager.seconds_per_beat * 0.5)\
			.set_ease(slide_ease_type).set_trans(slide_ease_trans)
		shift_tween.tween_property(sprite, "modulate:a", new_target_alpha, BeatManager.seconds_per_beat * 0.5)\
			.set_ease(slide_ease_type).set_trans(slide_ease_trans)
	
	# Add a new sprite for the next upcoming action
	_add_new_action_to_preview()

func _add_new_action_to_preview() -> void:
	var upcoming_actions_data = _get_upcoming_actions_with_timing()
	# Find the action that is beyond what we currently display
	var new_action_data_index = _action_sprites.size() # This is the index for the *new* sprite
	
	if new_action_data_index < upcoming_actions_data.size():
		var action_data_to_add = upcoming_actions_data[new_action_data_index]
		
		# Calculate relative_beat_time for the new sprite based on its new position in sequence
		# It should arrive at its beat, which is 'new_action_data_index' beats from now.
		var time_to_arrival_for_new_sprite = action_data_to_add.relative_beat_time

		_create_and_animate_sprite(action_data_to_add.action, time_to_arrival_for_new_sprite, new_action_data_index)


func _on_fight_ended(_winner: String) -> void:
	_clear_all_sprites()

### Public API ###

func trigger_beat_effect(sprite: Sprite2D) -> void:
	if not is_instance_valid(sprite) or not sprite.visible:
		return
	
	var original_scale_data = sprite.get_meta("original_scale", sprite.scale) # Retrieve original scale if stored
	# Find the sprite data to get its current final scale for pop
	var current_sprite_data = _action_sprites.find(func(item): return item.sprite == sprite)
	var original_scale = original_scale_data
	if current_sprite_data != -1:
		original_scale = _action_sprites[current_sprite_data].final_scale
	else:
		# Fallback if sprite not found in _action_sprites (shouldn't happen for active sprites)
		original_scale = sprite.scale # Use current scale as fallback

	var beat_scale = original_scale * beat_scale_multiplier
	
	var beat_tween = create_tween()
	beat_tween.set_parallel(true)
	
	beat_tween.tween_property(sprite, "scale", beat_scale, beat_duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	beat_tween.tween_property(sprite, "scale", original_scale, beat_duration * 0.7)\
		.set_delay(beat_duration * 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	
	_trigger_beat_visual_effect(sprite)

func _trigger_beat_visual_effect(sprite: Sprite2D) -> void:
	var original_modulate = sprite.modulate
	var flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color.WHITE * 1.5, 0.05)
	flash_tween.tween_property(sprite, "modulate", original_modulate, 0.1)
