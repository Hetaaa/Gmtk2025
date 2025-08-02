extends Node2D
class_name EnemyActionPreview

## Configuration
@export var preview_count: int = 3
@export var base_position_offset: Vector2 = Vector2(0, -200)
@export var spacing: float = 100.0
@export var base_scale: float = 0.3
@export var scale_reduction: float = 0.1
@export var base_alpha: float = 1.0
@export var alpha_reduction: float = 0.3
@export var slide_duration: float = 0.3
@export var beat_scale_multiplier: float = 1.3
@export var beat_duration: float = 0.15
@export var action_textures: Dictionary = {} # Preload textures here or assign via inspector

## Constants
const MIN_ALPHA: float = 0.1
const SPRITE_START_OFFSET: Vector2 = Vector2(0, -50)

## Internal variables
var _action_sprites: Array[Sprite2D] = []
var _enemy_ref: Enemy
var _current_tween: Tween

func _ready() -> void:
	# Set slide duration based on BeatManager grace period
	slide_duration = BeatManager.grace_period / 2.0
	
	# Connect signals
	BeatManager.action_window_open.connect(_on_action_window_open)
	FightManager.fight_ended.connect(_on_fight_ended)
	
	# Get parent reference and ensure it's valid
	_enemy_ref = get_parent() as Enemy
	if not _enemy_ref:
		push_error("EnemyActionPreview: This node must be a child of an 'Enemy' node.")
		return
	
	# Preload textures if not already set in the inspector
	_preload_action_textures()

	_create_sprites()
	_update_display(false)

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
		_setup_sprite_visuals(sprite, i) # Setup initial visuals

func _clear_sprites() -> void:
	for sprite in _action_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	_action_sprites.clear()

func _setup_sprite_visuals(sprite: Sprite2D, index: int) -> void:
	sprite.position = base_position_offset + Vector2(0, -index * spacing)
	
	var scale_factor = base_scale - (index * scale_reduction)
	sprite.scale = Vector2(scale_factor, scale_factor)
	
	var alpha = max(MIN_ALPHA, base_alpha - (index * alpha_reduction))
	sprite.modulate.a = alpha

func _update_display(animate: bool = true) -> void:
	if not _enemy_ref or _action_sprites.is_empty():
		return
	
	var upcoming_actions = _get_upcoming_actions()
	
	if animate:
		_animate_slide_in(upcoming_actions)
	else:
		_update_sprites_immediately(upcoming_actions)

func _get_upcoming_actions() -> Array[FightEnums.Action]:
	var actions: Array[FightEnums.Action] = []
	
	if not _enemy_ref or _enemy_ref.move_pattern.is_empty():
		return actions
	
	var current_index = _enemy_ref.move_index - 1
	var pattern = _enemy_ref.move_pattern
	
	for i in range(preview_count):
		var index = (current_index + i) % pattern.size()
		actions.append(pattern[index])
	
	return actions

func _update_sprites_immediately(upcoming_actions: Array[FightEnums.Action]) -> void:
	for i in range(_action_sprites.size()):
		var sprite = _action_sprites[i]
		var texture = _get_action_texture(upcoming_actions[i] if i < upcoming_actions.size() else null)
		
		sprite.visible = texture != null
		if texture:
			sprite.texture = texture
			_setup_sprite_visuals(sprite, i) # Reset position and scale for non-animated update

func _animate_slide_in(upcoming_actions: Array[FightEnums.Action]) -> void:
	_stop_current_tween()
	
	_current_tween = create_tween()
	_current_tween.set_parallel(true)
	
	for i in range(_action_sprites.size()):
		var sprite = _action_sprites[i]
		var texture = _get_action_texture(upcoming_actions[i] if i < upcoming_actions.size() else null)
		
		sprite.visible = texture != null
		if texture:
			sprite.texture = texture
			
			var final_pos = base_position_offset + Vector2(0, -i * spacing)
			var target_scale_factor = base_scale - (i * scale_reduction)
			var target_scale = Vector2(target_scale_factor, target_scale_factor)
			
			# Set initial state for animation
			sprite.position = final_pos + SPRITE_START_OFFSET
			sprite.scale = target_scale * 0.5 # Start with smaller scale
			
			# Animate position
			_current_tween.tween_property(sprite, "position", final_pos, slide_duration)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			
			# Animate scale
			_current_tween.tween_property(sprite, "scale", target_scale, slide_duration)\
				.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

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
	
	# Fallback: if not preloaded, try to load it now (should ideally be preloaded)
	var texture_path = _get_texture_path(action)
	if ResourceLoader.exists(texture_path):
		var texture = load(texture_path)
		action_textures[action_key] = texture # Cache for future use
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


### Signal Handlers
func _on_action_window_open(window_id: int, beat_count: int):
	await get_tree().process_frame # Ensure all updates are processed before refreshing
	_update_display(true)

func _on_fight_ended(_winner: String) -> void:
	_stop_current_tween()
	for sprite in _action_sprites:
		sprite.visible = false

### Public API
func set_preview_count(count: int) -> void:
	preview_count = count
	_stop_current_tween()
	_create_sprites()
	_update_display(false)

func force_update() -> void:
	_stop_current_tween()
	_update_display(false)

func trigger_beat_effect(sprite_index: int = 0) -> void:
	if sprite_index >= _action_sprites.size() or not _action_sprites[sprite_index].visible:
		return
	
	var sprite = _action_sprites[sprite_index]
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
