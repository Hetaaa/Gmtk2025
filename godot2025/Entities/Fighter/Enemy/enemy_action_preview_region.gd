extends CanvasLayer
# Configuration
@export var overlay_alpha: float = 0.3  # Transparency of the overlays
@export var fade_duration: float = 0.5  # How long fade in/out takes
@export var pulse_intensity: float = 0.2  # How much the overlay pulses
@export var pulse_speed: float = 2.0  # Speed of pulsing animation

# Zone configuration (as percentages of screen height)
@export var high_zone_height: float = 0.33  # Top 33% of screen
@export var middle_zone_height: float = 0.34  # Middle 34% of screen (33% + 34% = 67%)
@export var low_zone_height: float = 0.33  # Bottom 33% of screen

# Colors for different attack zones
@export var high_attack_color: Color = Color.RED
@export var middle_attack_color: Color = Color.RED
@export var low_attack_color: Color = Color.RED
@export var block_color: Color = Color.BLUE
@export var wait_color: Color = Color.GRAY

# Internal variables
var high_overlay: ColorRect
var middle_overlay: ColorRect
var low_overlay: ColorRect
var enemy_ref: Enemy
var current_tween: Tween
var pulse_tween: Tween
var current_active_overlay: ColorRect = null

func _ready():
	# Set layer to be on top of game but below UI
	layer = 10
	
	# Find the enemy this preview belongs to
	enemy_ref = find_enemy_reference()
	if not enemy_ref:
		push_error("EnemyActionPreview must be accessible from an Enemy node")
		return
	
	# Create the zone overlays
	create_zone_overlays()
	
	# Connect to signals
	if FightManager:
		FightManager.actions_revealed.connect(_on_actions_revealed)
		FightManager.fight_ended.connect(_on_fight_ended)
	
	# Initially all hidden
	hide_all_overlays()

func find_enemy_reference() -> Enemy:
	# Try to find enemy reference through parent hierarchy
	var current_node = get_parent()
	while current_node:
		if current_node is Enemy:
			return current_node as Enemy
		current_node = current_node.get_parent()
	
	# If not found in parents, try to find in scene
	var scene_root = get_tree().current_scene
	if scene_root:
		var enemies = find_children("*", "Enemy", true, false)
		if enemies.size() > 0:
			return enemies[0] as Enemy
	
	return null

func create_zone_overlays():
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Create HIGH zone overlay (top portion)
	high_overlay = ColorRect.new()
	high_overlay.name = "HighAttackOverlay"
	high_overlay.position = Vector2.ZERO
	high_overlay.size = Vector2(viewport_size.x, viewport_size.y * high_zone_height)
	high_overlay.color = Color.TRANSPARENT
	high_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(high_overlay)
	
	# Create MIDDLE zone overlay (middle portion)
	middle_overlay = ColorRect.new()
	middle_overlay.name = "MiddleAttackOverlay"
	middle_overlay.position = Vector2(0, viewport_size.y * high_zone_height)
	middle_overlay.size = Vector2(viewport_size.x, viewport_size.y * middle_zone_height)
	middle_overlay.color = Color.TRANSPARENT
	middle_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(middle_overlay)
	
	# Create LOW zone overlay (bottom portion)
	low_overlay = ColorRect.new()
	low_overlay.name = "LowAttackOverlay"
	low_overlay.position = Vector2(0, viewport_size.y * (high_zone_height + middle_zone_height))
	low_overlay.size = Vector2(viewport_size.x, viewport_size.y * low_zone_height)
	low_overlay.color = Color.TRANSPARENT
	low_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(low_overlay)
	
	# Connect to viewport size changes to update overlay sizes
	get_viewport().size_changed.connect(_on_viewport_size_changed)

func _on_viewport_size_changed():
	# Recreate overlays when viewport size changes
	if high_overlay:
		high_overlay.queue_free()
	if middle_overlay:
		middle_overlay.queue_free()
	if low_overlay:
		low_overlay.queue_free()
	
	await get_tree().process_frame
	create_zone_overlays()

func show_overlay_for_action(action: FightEnums.Action):
	# Hide any currently active overlay first
	hide_all_overlays()
	
	# Get the appropriate overlay for this action
	var target_overlay = get_overlay_for_action(action)
	if not target_overlay:
		return
	
	current_active_overlay = target_overlay
	
	# Stop any existing animations
	stop_current_animations()
	
	# Get color for the action
	var target_color = get_color_for_action(action)
	target_color.a = overlay_alpha
	
	# Fade in animation
	current_tween = create_tween()
	current_tween.set_parallel(true)
	
	# Fade in the overlay
	var fade_tween = current_tween.tween_property(target_overlay, "color", target_color, fade_duration)
	fade_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	# Start pulsing animation after fade in
	current_tween.tween_callback(start_pulse_animation).set_delay(fade_duration)

func hide_all_overlays():
	# Stop any existing animations
	stop_current_animations()
	
	if not current_active_overlay:
		return
	
	# Fade out animation
	current_tween = create_tween()
	var fade_tween = current_tween.tween_property(current_active_overlay, "color", Color.TRANSPARENT, fade_duration)
	fade_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	
	# Clear reference after fade out
	current_tween.tween_callback(func(): current_active_overlay = null).set_delay(fade_duration)

func get_overlay_for_action(action: FightEnums.Action) -> ColorRect:
	match action:
		FightEnums.Action.ATTACK_HIGH:
			return high_overlay
		FightEnums.Action.ATTACK_MIDDLE:
			return middle_overlay
		FightEnums.Action.ATTACK_LOW:
			return low_overlay
		FightEnums.Action.BLOCK_HIGH:
			return high_overlay
		FightEnums.Action.BLOCK_MIDDLE:
			return middle_overlay
		FightEnums.Action.BLOCK_LOW:
			return low_overlay
		FightEnums.Action.WAIT:
			return middle_overlay  # Show wait in middle zone
		_:
			return middle_overlay

func start_pulse_animation():
	if not current_active_overlay:
		return
	
	# Stop existing pulse
	if pulse_tween:
		pulse_tween.kill()
	
	# Get current base color
	var base_color = current_active_overlay.color
	var pulse_color = base_color
	pulse_color.a = min(1.0, base_color.a + pulse_intensity)
	
	# Create pulsing animation
	pulse_tween = create_tween()
	pulse_tween.set_loops()
	
	# Pulse up and down
	var pulse_up = pulse_tween.tween_property(current_active_overlay, "color", pulse_color, 1.0 / pulse_speed)
	pulse_up.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	var pulse_down = pulse_tween.tween_property(current_active_overlay, "color", base_color, 1.0 / pulse_speed)
	pulse_down.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

func stop_current_animations():
	if current_tween:
		current_tween.kill()
		current_tween = null
	
	if pulse_tween:
		pulse_tween.kill()
		pulse_tween = null

func get_color_for_action(action: FightEnums.Action) -> Color:
	match action:
		FightEnums.Action.ATTACK_HIGH:
			return high_attack_color
		FightEnums.Action.ATTACK_MIDDLE:
			return middle_attack_color
		FightEnums.Action.ATTACK_LOW:
			return low_attack_color
		FightEnums.Action.BLOCK_HIGH, FightEnums.Action.BLOCK_MIDDLE, FightEnums.Action.BLOCK_LOW:
			return block_color
		FightEnums.Action.WAIT:
			return wait_color
		_:
			return Color.GRAY

func get_next_enemy_action() -> FightEnums.Action:
	if not enemy_ref or enemy_ref.move_pattern.is_empty():
		return FightEnums.Action.WAIT
	
	var current_index = enemy_ref.move_index
	var pattern = enemy_ref.move_pattern
	
	# Get the next action (current move_index points to next action)
	return pattern[current_index % pattern.size()]

func update_preview_display():
	if not enemy_ref:
		return
	
	var next_action = get_next_enemy_action()
	
	# Show overlay for the next action
	show_overlay_for_action(next_action)

func is_attack_action(action: FightEnums.Action) -> bool:
	return action in [
		FightEnums.Action.ATTACK_HIGH,
		FightEnums.Action.ATTACK_MIDDLE,
		FightEnums.Action.ATTACK_LOW
	]

# Signal callbacks
func _on_actions_revealed(player_action: FightEnums.Action, enemy_action: FightEnums.Action, result: FightEnums.FightResult, timing_bonus: float):
	# Action was just executed, hide current overlay first
	hide_all_overlays()
	
	# Wait a bit, then show preview for next action
	await get_tree().create_timer(0.5).timeout  # Give time for the attack animation to play
	
	# Update preview for next action
	await get_tree().process_frame  # Wait a frame to ensure enemy's move_index is updated
	update_preview_display()

func _on_fight_ended(winner: String):
	# Hide all overlays when fight ends
	hide_all_overlays()

# Public methods for customization
func set_overlay_alpha(alpha: float):
	overlay_alpha = clamp(alpha, 0.0, 1.0)

func set_fade_duration(duration: float):
	fade_duration = max(0.1, duration)

func set_pulse_settings(intensity: float, speed: float):
	pulse_intensity = clamp(intensity, 0.0, 0.5)
	pulse_speed = max(0.1, speed)
	
	# Restart pulse with new settings if currently pulsing
	if current_active_overlay and pulse_tween and pulse_tween.is_valid():
		start_pulse_animation()

func set_zone_heights(high: float, middle: float, low: float):
	# Normalize to ensure they add up to 1.0
	var total = high + middle + low
	high_zone_height = high / total
	middle_zone_height = middle / total
	low_zone_height = low / total
	
	# Recreate overlays with new dimensions
	_on_viewport_size_changed()

func set_action_color(action: FightEnums.Action, color: Color):
	match action:
		FightEnums.Action.ATTACK_HIGH:
			high_attack_color = color
		FightEnums.Action.ATTACK_MIDDLE:
			middle_attack_color = color
		FightEnums.Action.ATTACK_LOW:
			low_attack_color = color
		FightEnums.Action.BLOCK_HIGH, FightEnums.Action.BLOCK_MIDDLE, FightEnums.Action.BLOCK_LOW:
			block_color = color
		FightEnums.Action.WAIT:
			wait_color = color

# Force immediate update
func force_immediate_update():
	stop_current_animations()
	if high_overlay:
		high_overlay.color = Color.TRANSPARENT
	if middle_overlay:
		middle_overlay.color = Color.TRANSPARENT
	if low_overlay:
		low_overlay.color = Color.TRANSPARENT
	current_active_overlay = null
	update_preview_display()

# Quick flash effect for immediate feedback
func flash_zone(action: FightEnums.Action, flash_color: Color = Color.WHITE, flash_duration: float = 0.2):
	var target_overlay = get_overlay_for_action(action)
	if not target_overlay:
		return
	
	var flash_tween = create_tween()
	flash_color.a = overlay_alpha * 0.8
	
	flash_tween.tween_property(target_overlay, "color", flash_color, flash_duration * 0.3)
	flash_tween.tween_property(target_overlay, "color", Color.TRANSPARENT, flash_duration * 0.7)

# Debug functions
func debug_show_action(action: FightEnums.Action):
	show_overlay_for_action(action)

func debug_hide():
	hide_all_overlays()

func debug_show_zones():
	# Show all zones with different colors for testing
	high_overlay.color = Color(1, 0, 0, 0.2)  # Red
	middle_overlay.color = Color(0, 1, 0, 0.2)  # Green
	low_overlay.color = Color(0, 0, 1, 0.2)  # Blue
