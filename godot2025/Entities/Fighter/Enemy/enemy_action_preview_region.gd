extends Node2D
class_name EnemyActionPreview

## Configuration
@export var preview_count: int = 3
@export var base_position_offset: Vector2 = Vector2(0, -200) # Base position for the *first* sprite
@export var spacing: float = 100.0 # Vertical spacing between sprites
@export var base_scale: float = 0.3
@export var scale_reduction: float = 0.1
@export var base_alpha: float = 1.0
@export var alpha_reduction: float = 0.3
@export var beat_scale_multiplier: float = 1.3
@export var beat_duration: float = 0.15

@export var action_textures: Dictionary = {} # Preload textures here or assign via inspector

## Constants
const MIN_ALPHA: float = 0.1
const SPRITE_START_OFFSET_Y: float = -300 # How far above the final position sprites start

## Internal variables
var _action_sprites: Array[Sprite2D] = []
var _enemy_ref: Enemy
var _current_tween: Tween # Tween for the slide-in animation
var _slide_duration: float # Calculated based on BeatManager grace period

func _ready() -> void:
	# Calculate slide duration based on BeatManager's grace period.
	# The animation should complete exactly when the action window opens.
	# Since action_window_open is emitted at `time_to_action_window_open`,
	# which is `timing_offset - (grace_period / 2.0)`, the duration
	# of the slide should cover the period from _open_action_window
	# up to the actual beat_hit.
	_slide_duration = BeatManager.grace_period / 2.0 + BeatManager.timing_offset # This ensures they arrive AT the beat hit

	# Connect signals
	BeatManager.action_window_open.connect(_on_action_window_open)
	BeatManager.beat_hit.connect(_on_beat_hit) # Connect to beat_hit for the arrival
	FightManager.fight_ended.connect(_on_fight_ended)
	
	# Get parent reference and ensure it's valid
	_enemy_ref = get_parent() as Enemy
	if not _enemy_ref:
		push_error("EnemyActionPreview: This node must be a child of an 'Enemy' node.")
		return
	
	# Preload textures if not already set in the inspector
	_preload_action_textures()

	_create_sprites()
	_update_display_immediately() # Initial setup without animation

func _preload_action_textures() -> void:
	for action_enum_value in FightEnums.Action.values():
		var action_key = str(action_enum_value)
		# Only preload if not already set via inspector
		if not action_textures.has(action_key):
			var texture_path = _get_texture_path(action_enum_value)
			if ResourceLoader.exists(texture_path):
				action_textures[action_key] = load(texture_path)

func _create_sprites() -> void:
	_clear_sprites()
	
	for i in range(preview_count):
		var sprite = Sprite2D.new()
		add_child(sprite)
		_action_sprites.append(sprite)
		_setup_sprite_initial_state(sprite, i) # Setup initial visuals

func _clear_sprites() -> void:
	for sprite in _action_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_action_sprites.clear()

# Sets up the sprite's initial properties (scale, alpha) and its starting position off-screen
func _setup_sprite_initial_state(sprite: Sprite2D, index: int) -> void:
	# Calculate the final position for this sprite
	var final_y_pos = base_position_offset.y - (index * spacing)
	
	# Set the initial position off-screen at the top
	sprite.position = Vector2(base_position_offset.x, final_y_pos + SPRITE_START_OFFSET_Y)
	
	var scale_factor = base_scale - (index * scale_reduction)
	sprite.scale = Vector2(scale_factor, scale_factor)
	
	var alpha = max(MIN_ALPHA, base_alpha - (index * alpha_reduction))
	sprite.modulate.a = alpha
	
	sprite.visible = false # Hide them initially

# Gets the upcoming actions from the enemy's move pattern
func _get_upcoming_actions() -> Array[FightEnums.Action]:
	var actions: Array[FightEnums.Action] = []
	
	if not _enemy_ref or _enemy_ref.move_pattern.is_empty():
		return actions
	
	var current_index = _enemy_ref.move_index - 1
	var pattern = _enemy_ref.move_pattern
	
	for i in range(preview_count):
		var index_in_pattern = (current_index + i) % pattern.size()
		actions.append(pattern[index_in_pattern])
	
	return actions

# Instantly updates sprite textures and positions without animation
func _update_display_immediately() -> void:
	if not _enemy_ref or _action_sprites.is_empty():
		return
	
	var upcoming_actions = _get_upcoming_actions()
	
	for i in range(_action_sprites.size()):
		var sprite = _action_sprites[i]
		var texture = _get_action_texture(upcoming_actions[i] if i < upcoming_actions.size() else null)
		
		sprite.visible = texture != null
		if texture:
			sprite.texture = texture
			# Reset position to its final state instantly
			var final_y_pos = base_position_offset.y - (i * spacing)
			sprite.position = Vector2(base_position_offset.x, final_y_pos)
			# Reset scale and alpha
			var scale_factor = base_scale - (i * scale_reduction)
			sprite.scale = Vector2(scale_factor, scale_factor)
			var alpha = max(MIN_ALPHA, base_alpha - (i * alpha_reduction))
			sprite.modulate.a = alpha

# Animates sprites sliding in from the top
func _animate_slide_in(upcoming_actions: Array[FightEnums.Action]) -> void:
	_stop_current_tween() # Stop any ongoing tween
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true) # Allow properties to tween simultaneously
	
	for i in range(_action_sprites.size()):
		var sprite = _action_sprites[i]
		var texture = _get_action_texture(upcoming_actions[i] if i < upcoming_actions.size() else null)
		
		sprite.visible = texture != null # Only show if there's a texture
		if texture:
			sprite.texture = texture
			
			# Calculate the final position for this sprite
			var final_pos = Vector2(base_position_offset.x, base_position_offset.y - (i * spacing))
			
			# Calculate the target scale for this sprite
			var target_scale_factor = base_scale - (i * scale_reduction)
			var target_scale = Vector2(target_scale_factor, target_scale_factor)
			
			# Set the sprite's starting position (off-screen top) for the tween
			sprite.position = final_pos + Vector2(0, SPRITE_START_OFFSET_Y)
			sprite.scale = target_scale * 0.5 # Start slightly smaller for a "pop" effect
			sprite.modulate.a = max(MIN_ALPHA, base_alpha - (i * alpha_reduction)) # Ensure alpha is correct for start

			# Animate position from top to final_pos
			_current_tween.tween_property(sprite, "position", final_pos, _slide_duration)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
			
			# Animate scale from smaller to target_scale
			_current_tween.tween_property(sprite, "scale", target_scale, _slide_duration)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC) # Elastic for a subtle bounce

func _stop_current_tween() -> void:
	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()
		_current_tween = null

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

# When the action window opens, start the slide-in animation.
func _on_action_window_open() -> void:
	# Get the upcoming actions and start the animation
	var upcoming_actions = _get_upcoming_actions()
	_animate_slide_in(upcoming_actions)

# When a beat is hit, we assume the previous action has just completed or is being resolved.
# We then "shift" the sprites by updating their displayed actions.
func _on_beat_hit(_beat_count: int) -> void:
	# After the beat hits, the first sprite (index 0) represents the action that just occurred.
	# We want to shift the display to show the *next* set of upcoming actions.
	# This effectively makes the previous "first" action disappear, and new ones slide in.
	
	# We delay this slightly to allow the beat effect to be seen on the first sprite
	# before it potentially updates to the next action.
	get_tree().create_timer(beat_duration * 0.5).timeout.connect(
		func():
			_update_display_immediately() # Update immediately for the next set of previews
	)

func _on_fight_ended(_winner: String) -> void:
	_stop_current_tween()
	for sprite in _action_sprites:
		sprite.visible = false

### Public API ###

func set_preview_count(count: int) -> void:
	preview_count = count
	_stop_current_tween()
	_create_sprites()
	_update_display_immediately()

func force_update() -> void:
	_stop_current_tween()
	_update_display_immediately()

func trigger_beat_effect(sprite_index: int = 0) -> void:
	if sprite_index >= _action_sprites.size() or not _action_sprites[sprite_index].visible:
		return
	
	var sprite = _action_sprites[sprite_index]
	
	# Recalculate original scale based on current index, as positions may have shifted.
	var original_scale_factor = base_scale - (sprite_index * scale_reduction)
	var original_scale = Vector2(original_scale_factor, original_scale_factor)
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
