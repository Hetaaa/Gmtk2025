extends Control

# Constants
const CALIBRATION_COUNT = 10

# UI elements
@onready var counter_label := $Panel/TextLabel
@onready var music_indicator := $MusicIndicator

# Calibration state
var is_calibrating: bool = false
var calibration_started: bool = false
var input_count: int = 0
var beat_times: Array[float] = []
var player_input_times: Array[float] = []
var original_offset: float = 0.0

# Animation variables
var tween: Tween
var original_scale: Vector2

# Store connection for proper cleanup
var beat_hit_connection: Callable

func _ready():
	# Store original offset and scale
	if music_indicator:
		original_scale = music_indicator.scale
	
	# Create tween for animations
	tween = create_tween()
	tween.kill()  # Stop it initially
	
	set_ui_state_waiting()

func set_ui_state_waiting():
	counter_label.text = "0/%d" % CALIBRATION_COUNT
	counter_label.visible = true

func set_ui_state_calibrating():
	counter_label.visible = true

func set_ui_state_complete():
	counter_label.visible = true
	stop_music_indicator_pulse()

func _input(event: InputEvent):
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.keycode == KEY_SPACE and event.pressed):
		if not calibration_started:
			# First key press - start the calibration
			start_calibration()
		elif is_calibrating:
			# Record the player's input time
			record_input()

func record_input():
	var input_time = BeatManager.music_player.get_playback_position()
	player_input_times.append(input_time)
	input_count += 1
	counter_label.text = "%d/%d" % [input_count, CALIBRATION_COUNT]
	
	print("Input %d recorded at: %.3f seconds" % [input_count, input_time])
	
	# Check if we have enough inputs to finish
	if input_count >= CALIBRATION_COUNT:
		finish_calibration()

func _on_reset_button_pressed():
	reset_calibration()

func start_calibration():
	calibration_started = true
	is_calibrating = true
	
	# Start music and indicator
	start_music()
	start_music_indicator_pulse()
	set_ui_state_calibrating()
	
	print("Calibration started - press SPACE on each beat you hear")

func start_music():
	# Temporarily set offset to 0 for pure measurement
	
	# Create the connection callable for beat recording
	beat_hit_connection = func(beat_count: int):
		# Record all beats that occur
		if BeatManager.use_beat_map and BeatManager.beat_index - 1 < BeatManager.beat_map.size():
			var actual_beat_time = BeatManager.beat_map[BeatManager.beat_index - 1]
			beat_times.append(actual_beat_time)
		else:
			# For BPM-based tracks, calculate expected beat time
			var expected_time = (beat_count - 1) * BeatManager.seconds_per_beat
			beat_times.append(expected_time)
		
		# Pulse the indicator on each beat
		pulse_music_indicator()
	
	# Connect to beat_hit signal
	if not BeatManager.beat_hit.is_connected(beat_hit_connection):
		BeatManager.beat_hit.connect(beat_hit_connection)
	
	# Start playing music
	BeatManager.play_track(0)  # Adjust index based on your tracks

func start_music_indicator_pulse():
	if not music_indicator:
		return
		
	# Start a continuous subtle pulse
	tween = create_tween()
	tween.set_loops()
	tween.tween_property(music_indicator, "scale", original_scale * 1.1, 0.1)
	tween.tween_property(music_indicator, "scale", original_scale, 0.1)

func pulse_music_indicator():
	if not music_indicator:
		return
		
	# Create a more pronounced pulse on beat
	var beat_tween = create_tween()
	beat_tween.tween_property(music_indicator, "scale", original_scale * 1.3, 0.05)
	beat_tween.tween_property(music_indicator, "scale", original_scale, 0.15)

func stop_music_indicator_pulse():
	if music_indicator:
		if tween:
			tween.kill()
		music_indicator.scale = original_scale

func finish_calibration():
	is_calibrating = false
	calibration_started = false
	
	# Stop music and disconnect signals
	BeatManager.stop_track()
	if beat_hit_connection and BeatManager.beat_hit.is_connected(beat_hit_connection):
		BeatManager.beat_hit.disconnect(beat_hit_connection)
	
	calculate_and_display_offset()
	set_ui_state_complete()

func reset_calibration():
	# Reset state
	is_calibrating = false
	calibration_started = false
	input_count = 0
	beat_times.clear()
	player_input_times.clear()
	
	# Reset UI
	counter_label.text = "0/%d" % CALIBRATION_COUNT
	
	# Stop music and animations
	BeatManager.stop_track()
	stop_music_indicator_pulse()
	
	# Disconnect signal if connected
	if beat_hit_connection and BeatManager.beat_hit.is_connected(beat_hit_connection):
		BeatManager.beat_hit.disconnect(beat_hit_connection)
	
	# Restore original offset
	
	# Reset to waiting state
	set_ui_state_waiting()

func calculate_and_display_offset():
	var num_inputs = player_input_times.size()
	var num_beats = beat_times.size()
	
	print("\n=== CALIBRATION RESULTS ===")
	print("Inputs recorded: %d" % num_inputs)
	print("Beats detected: %d" % num_beats)
	
	if num_inputs == 0:
		print("ERROR: No inputs recorded")
		return
	
	if num_beats == 0:
		print("ERROR: No beats detected")
		return
	
	# Match inputs to nearest beats
	var total_offset: float = 0.0
	var valid_samples: int = 0
	var offsets: Array[float] = []
	
	for i in range(num_inputs):
		var input_time = player_input_times[i]
		
		# Find the closest beat to this input
		var closest_beat_time = beat_times[0]
		var min_distance = abs(input_time - closest_beat_time)
		
		for beat_time in beat_times:
			var distance = abs(input_time - beat_time)
			if distance < min_distance:
				min_distance = distance
				closest_beat_time = beat_time
		
		# Only include inputs that are reasonably close to a beat (within 0.5 seconds)
		if min_distance < 0.5:
			var offset = input_time - closest_beat_time
			offsets.append(offset)
			total_offset += offset
			valid_samples += 1
			print("Input %d: %.3fs -> Beat: %.3fs | Offset: %.3fs (%.1fms)" % [i+1, input_time, closest_beat_time, offset, offset * 1000])
		else:
			print("Input %d: %.3fs -> No close beat found (min distance: %.3fs)" % [i+1, input_time, min_distance])
	
	if valid_samples == 0:
		print("ERROR: No valid input-beat pairs found")
		return
	
	# Calculate statistics
	var average_offset = total_offset / valid_samples
	var recommended_offset = -average_offset  # Negative to compensate
	
	# Calculate standard deviation for consistency check
	var variance = 0.0
	for offset in offsets:
		variance += pow(offset - average_offset, 2)
	variance /= valid_samples
	var std_deviation = sqrt(variance)
	
	# Display and apply results
	SceneManager.isOffset = true
	var result_text = "Offset: %.1fms" % (recommended_offset * 1000)
		
	SceneManager.change_scene("choosing_levels")
