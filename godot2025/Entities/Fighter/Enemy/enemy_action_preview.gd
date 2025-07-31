extends Node2D
class_name EnemyActionPreview

# Configuration
@export var preview_count: int = 3  # How many actions to show
@export var base_position_offset: Vector2 = Vector2(0, -200)  # Offset from enemy position
@export var spacing: float = 100.0  # Space between action sprites
@export var base_scale: float = 0.3  # Scale of the first (next) action
@export var scale_reduction: float = 0.1  # How much smaller each subsequent action gets
@export var base_alpha: float = 1.0  # Alpha of the first action
@export var alpha_reduction: float = 0.3  # How much more transparent each subsequent action gets

# Animation settings
@export var slide_distance: float = 30.0  # How far sprites slide in from
@export var slide_duration: float = 0.3  # How long the slide takes
@export var use_bounce_easing: bool = true  # Use bounce effect for slide-in

# Action sprite textures - you'll need to assign these in the inspector
@export var action_textures: Dictionary = {}

# Internal variables
var action_sprites: Array[Sprite2D] = []
var enemy_ref: Enemy
var current_slide_tween: Tween

func _ready():
	# Find the enemy this preview belongs to
	enemy_ref = get_parent() as Enemy
	if not enemy_ref:
		push_error("EnemyActionPreview must be a child of an Enemy node")
		return
	
	# Create sprite nodes for previews
	create_preview_sprites()
	
	# Connect to signals
	if FightManager:
		FightManager.actions_revealed.connect(_on_actions_revealed)
		FightManager.fight_ended.connect(_on_fight_ended)
	
	# Initial update (no animation on startup)
	update_preview_display(false)

func create_preview_sprites():
	# Clear existing sprites
	for sprite in action_sprites:
		if sprite and is_instance_valid(sprite):
			sprite.queue_free()
	action_sprites.clear()
	
	# Create new sprite nodes
	for i in range(preview_count):
		var sprite = Sprite2D.new()
		add_child(sprite)
		action_sprites.append(sprite)
		
		# Position sprites horizontally
		sprite.position = base_position_offset + Vector2(i * spacing, 0)
		
		# Scale and alpha based on position
		var scale_factor = base_scale - (i * scale_reduction)
		sprite.scale = Vector2(scale_factor, scale_factor)
		
		var alpha = base_alpha - (i * alpha_reduction)
		sprite.modulate.a = max(0.1, alpha)  # Minimum alpha of 0.1

func update_preview_display(animate: bool = true):
	if not enemy_ref or action_sprites.is_empty():
		return
	
	# Get upcoming actions from enemy
	var upcoming_actions = get_upcoming_enemy_actions()
	
	# Check if actions actually changed
	var actions_changed = false
	for i in range(action_sprites.size()):
		var sprite = action_sprites[i]
		var new_texture: Texture2D = null
		
		if i < upcoming_actions.size():
			var action = upcoming_actions[i]
			new_texture = get_action_texture(action)
		
		if sprite.texture != new_texture:
			actions_changed = true
			break
	
	# If nothing changed, don't animate
	if not actions_changed:
		return
	
	# Update sprites with or without animation
	if animate:
		animate_slide_in(upcoming_actions)
	else:
		update_sprites_immediately(upcoming_actions)

func update_sprites_immediately(upcoming_actions: Array[FightEnums.Action]):
	# Update each sprite immediately (no animation)
	for i in range(action_sprites.size()):
		var sprite = action_sprites[i]
		
		if i < upcoming_actions.size():
			var action = upcoming_actions[i]
			var texture = get_action_texture(action)
			
			if texture:
				sprite.texture = texture
				sprite.visible = true
				# Reset to final position and properties
				sprite.position = base_position_offset + Vector2(i * spacing, 0)
				var scale_factor = base_scale - (i * scale_reduction)
				sprite.scale = Vector2(scale_factor, scale_factor)
				var alpha = base_alpha - (i * alpha_reduction)
				sprite.modulate.a = max(0.1, alpha)
			else:
				sprite.visible = false
		else:
			sprite.visible = false

func animate_slide_in(upcoming_actions: Array[FightEnums.Action]):
	# Stop any existing slide animation
	if current_slide_tween:
		current_slide_tween.kill()
	
	# Update textures first
	for i in range(action_sprites.size()):
		var sprite = action_sprites[i]
		
		if i < upcoming_actions.size():
			var action = upcoming_actions[i]
			var texture = get_action_texture(action)
			
			if texture:
				sprite.texture = texture
				sprite.visible = true
				
				# Position sprite off to the right for slide-in
				var final_pos = base_position_offset + Vector2(i * spacing, 0)
				sprite.position = final_pos + Vector2(slide_distance, 0)
				
				# Set scale and alpha
				var scale_factor = base_scale - (i * scale_reduction)
				sprite.scale = Vector2(scale_factor, scale_factor)
				var alpha = base_alpha - (i * alpha_reduction)
				sprite.modulate.a = max(0.1, alpha)
			else:
				sprite.visible = false
		else:
			sprite.visible = false
	
	# Create slide-in animation
	current_slide_tween = create_tween()
	current_slide_tween.set_parallel(true)
	
	# Animate each visible sprite sliding to its final position
	for i in range(action_sprites.size()):
		var sprite = action_sprites[i]
		
		if sprite.visible:
			var final_pos = base_position_offset + Vector2(i * spacing, 0)
			var tween_property = current_slide_tween.tween_property(sprite, "position", final_pos, slide_duration)
			
			# Add easing
			if use_bounce_easing:
				tween_property.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
			else:
				tween_property.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func get_upcoming_enemy_actions() -> Array[FightEnums.Action]:
	var actions: Array[FightEnums.Action] = []
	
	if not enemy_ref or enemy_ref.move_pattern.is_empty():
		return actions
	
	var current_index = enemy_ref.move_index-1
	var pattern = enemy_ref.move_pattern
	
	# Get next few actions based on current move_index
	for i in range(preview_count):
		var index = (current_index + i) % pattern.size()
		actions.append(pattern[index])
	
	return actions

func get_action_texture(action: FightEnums.Action) -> Texture2D:
	# First check if we have a custom texture assigned
	var action_key = str(action)
	if action_textures.has(action_key):
		return action_textures[action_key]
	
	# Fall back to loading from resources (you'll need to organize your textures)
	var texture_path = get_texture_path_for_action(action)
	if ResourceLoader.exists(texture_path):
		return load(texture_path)
	
	return null

func get_texture_path_for_action(action: FightEnums.Action) -> String:
	# Define paths to your action PNG files
	# Adjust these paths to match your project structure
	match action:
		FightEnums.Action.ATTACK_HIGH:
			return "res://Entities/Fighter/Enemy/Assets/AttackIcons/attack_up.png"
		FightEnums.Action.ATTACK_MIDDLE:
			return "res://Entities/Fighter/Enemy/Assets/AttackIcons/attack_mid.png"
		FightEnums.Action.ATTACK_LOW:
			return "res://Entities/Fighter/Enemy/Assets/AttackIcons/attack_down.png"
		FightEnums.Action.BLOCK_HIGH:
			return "res://Entities/Fighter/Enemy/Assets/AttackIcons/block_up.png"
		FightEnums.Action.BLOCK_MIDDLE:
			return "res://Entities/Fighter/Enemy/Assets/AttackIcons/block_mid.png"
		FightEnums.Action.BLOCK_LOW:
			return "res://Entities/Fighter/Enemy/Assets/AttackIcons/block_down.png"
		FightEnums.Action.WAIT:
			return "res://Entities/Fighter/Enemy/Assets/AttackIcons/wait.png"
		_:
			return "res://Entities/Fighter/Enemy/Assets/AttackIcons/wait.png"

# Signal callbacks
func _on_actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float):
	# Action was just executed, update the preview for next actions with animation
	await get_tree().process_frame  # Wait a frame to ensure enemy's move_index is updated
	update_preview_display(true)

func _on_fight_ended(winner: String):
	# Hide all previews when fight ends
	if current_slide_tween:
		current_slide_tween.kill()
	for sprite in action_sprites:
		sprite.visible = false

# Public methods for customization
func set_preview_count(count: int):
	preview_count = count
	if current_slide_tween:
		current_slide_tween.kill()
	create_preview_sprites()
	update_preview_display(false)

func set_spacing(new_spacing: float):
	spacing = new_spacing
	if current_slide_tween:
		current_slide_tween.kill()
	create_preview_sprites()
	update_preview_display(false)

func set_position_offset(offset: Vector2):
	base_position_offset = offset
	if current_slide_tween:
		current_slide_tween.kill()
	create_preview_sprites()
	update_preview_display(false)

func add_custom_texture(action: FightEnums.Action, texture: Texture2D):
	action_textures[str(action)] = texture

# Force immediate update (skips animation)
func force_immediate_update():
	if current_slide_tween:
		current_slide_tween.kill()
	var upcoming_actions = get_upcoming_enemy_actions()
	update_sprites_immediately(upcoming_actions)

# Optional: Quick pulse animation for immediate feedback
func pulse_animation():
	if current_slide_tween and current_slide_tween.is_valid():
		return  # Don't pulse during slide animation
		
	var pulse_tween = create_tween()
	pulse_tween.set_parallel(true)
	
	for i in range(action_sprites.size()):
		var sprite = action_sprites[i]
		if sprite.visible:
			var original_scale = sprite.scale
			pulse_tween.tween_property(sprite, "scale", original_scale * 1.15, 0.1)
			pulse_tween.tween_property(sprite, "scale", original_scale, 0.1).set_delay(0.1)

# Debug function to test with different actions
func debug_set_test_actions(actions: Array[FightEnums.Action]):
	if not enemy_ref:
		return
	
	enemy_ref.move_pattern = actions
	enemy_ref.move_index = 0
	update_preview_display()
