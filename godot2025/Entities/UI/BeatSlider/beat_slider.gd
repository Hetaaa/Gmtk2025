extends Control
class_name BeatSlider

## Array of timestamps (in seconds) when sprites should hit the center
@export var beat_timestamps: Array[float] = []

## Array of phase lengths [enemy_count, player_count, enemy_count, player_count, ...]
@export var phase_pattern: Array[int] = []

## Distance sprites slide from right side of screen
@export var slide_distance: float = 400.0

## How far to the right of center the sprites spawn (always spawns to the right, moves left)
@export var spawn_offset: float = 400.0

## How many seconds before the beat to start the slide
@export var lead_time: float = 2.0

## Scale of the sprites
@export var sprite_scale: Vector2 = Vector2(1.0, 1.0)

## Whether to auto-remove sprites after they pass the center
@export var auto_cleanup: bool = true

## Time in seconds after beat to remove sprite (if auto_cleanup is true)
@export var cleanup_delay: float = 1.0

## Duration of fade in effect (in seconds)
@export var fade_in_duration: float = 0.3

## Duration of fade out effect (in seconds)
@export var fade_out_duration: float = 0.5

# Internal variables
var game_time: float = 0.0
var spawned_beats: Dictionary = {}
var active_sprites: Array[TextureRect] = []

# Skip mode tracking - simplified
var current_loop_skip_count: int = 0
var is_first_loop: bool = true  # Track if we're on the first loop
var global_gameplay_beat_counter: int = 0  # Track total gameplay beats across all loops

var enemy_sprite_texture
var player_sprite_texture

# Called when the node enters the scene tree
func _ready():
	BeatManager.mapLoaded.connect(_on_map_loaded)
	BeatManager.music_looped.connect(_on_music_looped)
	BeatManager.skip_mode_changed.connect(_on_skip_mode_changed)
	FightManager.phases_loaded.connect(_on_phases_loaded)
	# Ensure we have default textures if none provided
	enemy_sprite_texture = load("res://Entities/UI/BeatSlider/Assets/enemy_beat.png")
	player_sprite_texture = load("res://Entities/UI/BeatSlider/Assets/player_beat.png")

func create_default_texture(color: Color) -> Texture2D:
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func _process(delta: float) -> void:
	update_time(BeatManager._get_current_time())

func is_enemy_beat(beat_index: int) -> bool:
	if phase_pattern.is_empty():
		return true  # Default to enemy if no pattern specified
	
	# The beat_index represents the position in the beat_timestamps array
	# We need to convert this to a "gameplay beat number" that accounts for the pattern cycle
	var beat_number = beat_index + 1
	
	# Calculate the actual gameplay beat number considering global progression
	var gameplay_beat_number: int
	
	if BeatManager.is_first_loop and BeatManager.skip_first_beats > 0:
		# First loop with skipped beats
		if beat_number > BeatManager.skip_first_beats:
			# This beat comes after the skipped ones
			gameplay_beat_number = beat_number - BeatManager.skip_first_beats
		else:
			# This beat will be skipped, use raw beat number for visual consistency
			gameplay_beat_number = beat_number
	else:
		# Not first loop, or first loop without skips
		# We need to calculate how many gameplay beats have been processed so far
		
		# Calculate gameplay beats from first loop
		var first_loop_total_beats = beat_timestamps.size()
		var first_loop_skipped_beats = BeatManager.skip_first_beats if BeatManager.skip_first_beats > 0 else 0
		var first_loop_gameplay_beats = first_loop_total_beats - first_loop_skipped_beats
		
		# Calculate how many complete loops have finished
		# Since we're in a subsequent loop, at least one loop is complete
		var completed_loops = 1
		
		# For each additional completed loop, all beats are gameplay beats
		var additional_gameplay_beats = (completed_loops - 1) * beat_timestamps.size()
		
		# Total gameplay beats processed before this loop
		var total_previous_gameplay_beats = first_loop_gameplay_beats + additional_gameplay_beats
		
		# Current beat's position in the global gameplay sequence
		gameplay_beat_number = total_previous_gameplay_beats + beat_number
	
	# Calculate total beats in one complete pattern cycle
	var total_pattern_beats = 0
	for phase_length in phase_pattern:
		total_pattern_beats += phase_length * 2  # Each number creates 2 phases (enemy + player)
	
	if total_pattern_beats == 0:
		return true  # Safety check for empty pattern
	
	# Find which beat we are within the repeating pattern
	var beat_in_pattern = (gameplay_beat_number - 1) % total_pattern_beats
	
	# Walk through the pattern to find which phase this beat belongs to
	var current_beat = 0
	
	for i in range(phase_pattern.size()):
		var phase_length = phase_pattern[i]
		
		# Enemy phase for this length
		if beat_in_pattern >= current_beat and beat_in_pattern < current_beat + phase_length:
			return true  # Enemy phase
		current_beat += phase_length
		
		# Player phase for this length
		if beat_in_pattern >= current_beat and beat_in_pattern < current_beat + phase_length:
			return false  # Player phase
		current_beat += phase_length
	
	# This should never be reached, but default to enemy just in case
	return true


# Call this to start the beat slider system
func start_beats(start_time: float = 0.0):
	game_time = start_time
	spawned_beats.clear()
	cleanup_all_sprites()

# Call this every frame with the current game time
func update_time(current_time: float):
	game_time = current_time
	check_for_new_beats()
	update_existing_sprites()
	cleanup_passed_sprites()

# Check if any new beats need to be spawned
func check_for_new_beats():
	for i in range(beat_timestamps.size()):
		var beat_time = beat_timestamps[i]
		var spawn_time = beat_time - lead_time
		var beat_number = i + 1  # Beat numbers start from 1
		
		# Skip spawning if this beat should be skipped (only applies to current loop)
		if should_skip_beat(beat_number):
			# Mark as spawned so we don't check it again
			if not spawned_beats.has(i):
				spawned_beats[i] = true
			continue
		
		# Check if it's time to spawn this beat and we haven't spawned it yet
		if game_time >= spawn_time and not spawned_beats.has(i):
			spawn_beat_sprite(beat_time, i)
			spawned_beats[i] = true

# Simplified skip logic - only check current loop state
func should_skip_beat(beat_number: int) -> bool:
	# Only skip if we're on the first loop AND have a skip count set AND the beat is within that range
	return is_first_loop and current_loop_skip_count > 0 and beat_number <= current_loop_skip_count

# Spawn a sprite for a specific beat
func spawn_beat_sprite(beat_time: float, beat_index: int):
	var sprite = TextureRect.new()
	var is_enemy = is_enemy_beat(beat_index)
	
	# Set texture based on phase
	if is_enemy:
		sprite.texture = enemy_sprite_texture
	else:
		sprite.texture = player_sprite_texture
	
	sprite.scale = sprite_scale
	# Set pivot to center for equal expansion on all sides
	sprite.pivot_offset = sprite.get_rect().size * 0.5
	
	# Set z_index to appear above border elements
	sprite.z_index = 10  # Adjust this value as needed to be above your border
	
	# Position sprite at the starting position (right side)
	var center_x = size.x * 0.5
	var center_y = 0.0  # Center at relative y = 0
	var start_x = center_x + spawn_offset  # Start from right side based on spawn_offset
	
	# Position the sprite so its center (pivot) aligns with the desired position
	sprite.position = Vector2(start_x, center_y)
	
	# Store beat info in the sprite
	sprite.set_meta("beat_time", beat_time)
	sprite.set_meta("beat_index", beat_index)
	sprite.set_meta("start_x", start_x)
	sprite.set_meta("center_x", center_x)
	sprite.set_meta("is_enemy", is_enemy)
	sprite.set_meta("spawn_time", game_time)  # Track when sprite was spawned
	
	# Start with transparent sprite for fade in effect
	sprite.modulate.a = 0.0
	
	add_child(sprite)
	active_sprites.append(sprite)

# Update positions of all active sprites
func update_existing_sprites():
	for sprite in active_sprites:
		if not is_instance_valid(sprite):
			continue
			
		var beat_time = sprite.get_meta("beat_time")
		var start_x = sprite.get_meta("start_x")
		var center_x = sprite.get_meta("center_x")
		var is_enemy = sprite.get_meta("is_enemy")
		var spawn_time = sprite.get_meta("spawn_time")
		
		# Calculate progress (0.0 at spawn, 1.0 at beat hit)
		var time_since_spawn = game_time - (beat_time - lead_time)
		var progress = time_since_spawn / lead_time
		
		# Interpolate position - sprite.position is now the center point
		var current_x = lerp(start_x, center_x, progress)
		sprite.position.x = current_x
		
		# Use normal scale always
		sprite.scale = sprite_scale
		
		# Handle fade effects
		update_sprite_alpha(sprite, beat_time, spawn_time)

# Update the alpha value of a sprite based on fade in/out timing
func update_sprite_alpha(sprite: TextureRect, beat_time: float, spawn_time: float):
	var current_alpha = 1.0
	
	# Fade in effect at the beginning
	var time_since_spawn = game_time - spawn_time
	if time_since_spawn < fade_in_duration:
		var fade_in_progress = time_since_spawn / fade_in_duration
		current_alpha = ease_in_out(fade_in_progress)
	
	# Fade out effect at the end (during cleanup period)
	var time_since_beat = game_time - beat_time
	if time_since_beat > 0 and auto_cleanup:
		var fade_out_start_time = cleanup_delay - fade_out_duration
		if fade_out_start_time < 0:
			fade_out_start_time = 0  # Start fading immediately if cleanup_delay is shorter than fade_out_duration
		
		if time_since_beat >= fade_out_start_time:
			var fade_out_elapsed = time_since_beat - fade_out_start_time
			var fade_out_progress = fade_out_elapsed / fade_out_duration
			fade_out_progress = clamp(fade_out_progress, 0.0, 1.0)
			
			var fade_out_alpha = 1.0 - ease_in_out(fade_out_progress)
			current_alpha = min(current_alpha, fade_out_alpha)
	
	sprite.modulate.a = clamp(current_alpha, 0.0, 1.0)

# Smooth easing function for fade effects
func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t)  # Smoothstep function

# Remove sprites that have passed their cleanup time  
func cleanup_passed_sprites():
	if not auto_cleanup:
		return
		
	var sprites_to_remove: Array[TextureRect] = []
	
	for sprite in active_sprites:
		if not is_instance_valid(sprite):
			sprites_to_remove.append(sprite)
			continue
			
		var beat_time = sprite.get_meta("beat_time")
		if game_time >= beat_time + cleanup_delay:
			sprites_to_remove.append(sprite)
	
	# Remove sprites
	for sprite in sprites_to_remove:
		active_sprites.erase(sprite)
		if is_instance_valid(sprite):
			sprite.queue_free()

# Manually remove all sprites
func cleanup_all_sprites():
	for sprite in active_sprites:
		if is_instance_valid(sprite):
			sprite.queue_free()
	active_sprites.clear()

# Get current accuracy for debugging (how close to center the closest sprite is)
func get_current_accuracy() -> float:
	var center_x = size.x * 0.5
	var closest_distance = INF
	
	for sprite in active_sprites:
		if not is_instance_valid(sprite):
			continue
			
		var sprite_center_x = sprite.position.x + sprite.get_rect().size.x * 0.5
		var distance = abs(sprite_center_x - center_x)
		closest_distance = min(closest_distance, distance)
	
	return closest_distance if closest_distance != INF else -1.0

# Helper function to get the phase type of a specific beat (for debugging)
func get_beat_phase_type(beat_index: int) -> String:
	return "Enemy" if is_enemy_beat(beat_index) else "Player"

# Signal handlers for BeatManager
func _on_map_loaded():
	beat_timestamps = BeatManager.beat_map
	
func _on_phases_loaded():
	phase_pattern = FightManager.phase_pattern

# Handle music loop - reset for new loop
func _on_music_looped():
	# Calculate how many gameplay beats we processed in the previous loop
	var beats_in_previous_loop = 0
	if is_first_loop and current_loop_skip_count > 0:
		# On first loop, we process all beats except the skipped ones
		beats_in_previous_loop = beat_timestamps.size() - current_loop_skip_count
	else:
		# On subsequent loops, we process all beats
		beats_in_previous_loop = beat_timestamps.size()
	
	# Add to global counter
	global_gameplay_beat_counter += beats_in_previous_loop
	
	spawned_beats.clear()  # Clear the spawned beats dictionary to allow re-spawning
	current_loop_skip_count = 0  # Reset skip count - no skipping on subsequent loops
	is_first_loop = false  # Mark that we're no longer on the first loop
	cleanup_all_sprites()

# Handle skip mode changes from BeatManager
func _on_skip_mode_changed(is_skipping: bool, skip_count: int):
	if is_skipping:
		current_loop_skip_count = skip_count
		is_first_loop = true  # If we're entering skip mode, we're on the first loop
	else:
		current_loop_skip_count = 0
		is_first_loop = false  # If skip mode is turned off, we're no longer on first loop
