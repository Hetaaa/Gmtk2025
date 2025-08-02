extends Control

# Constants
const CALIBRATION_COUNT = 10

# UI elements
@onready var instructions_label := $Panel/VBoxContainer/Instructions
@onready var counter_label := $Panel/VBoxContainer/InputCounter
@onready var result_label := $Panel/VBoxContainer/OffsetResult
@onready var reset_button := $Panel/VBoxContainer/ResetButton

# Reference to your BeatManager singleton
@onready var beat_manager = get_node("/root/BeatManager")

# Calibration state
var is_calibrating: bool = false
var calibration_started: bool = false  # New flag to track if measurement has begun
var input_count: int = 0
var beat_times: Array[float] = []  # Actual beat times from beat map
var player_input_times: Array[float] = []
var original_offset: float = 0.0

# Store connection for proper cleanup
var beat_hit_connection: Callable

func _ready():
	# Store original offset to restore if needed
	original_offset = BeatManager.timing_offset
	reset_button.hide()
	
	# Start music immediately but don't begin measurement yet
	start_music()
	set_ui_state_waiting()

func set_ui_state_waiting():
	instructions_label.text = "Music is playing. Press K when you hear the first beat to start calibration."
	counter_label.visible = false
	result_label.visible = false
	reset_button.visible = true

func set_ui_state_calibrating():
	instructions_label.text = "Great! Keep pressing K on each beat."
	counter_label.visible = true
	result_label.visible = false
	reset_button.visible = true

func set_ui_state_complete():
	instructions_label.text = "Calibration complete! Press Reset to try again."
	counter_label.visible = false
	result_label.visible = true
	reset_button.visible = true

func _input(event: InputEvent):
	if event.is_action_pressed("ATTACK_MID"):
		if not calibration_started:
			# First key press - start the measurement
			start_calibration_measurement()
		
		if is_calibrating:
			# Record the player's input time
			var input_time = beat_manager.music_player.get_playback_position()
			player_input_times.append(input_time)
			input_count += 1
			counter_label.text = "Inputs: %s / %s" % [input_count, CALIBRATION_COUNT]
			
			print("Input %d recorded at: %.3f" % [input_count, input_time])
			
			# Check if we have enough inputs to finish
			if input_count >= CALIBRATION_COUNT:
				finish_calibration()

func _on_reset_button_pressed():
	reset_calibration()
	start_music()
	set_ui_state_waiting()

func start_music():
	# Temporarily set offset to 0 for pure measurement
	BeatManager.timing_offset = 0.0
	
	# Create the connection callable for beat recording
	beat_hit_connection = func(beat_count: int):
		# Record all beats that occur (we'll match them to inputs later)
		if beat_manager.use_beat_map and beat_manager.beat_index - 1 < beat_manager.beat_map.size():
			var actual_beat_time = beat_manager.beat_map[beat_manager.beat_index - 1]
			beat_times.append(actual_beat_time)
		else:
			# For BPM-based tracks, calculate expected beat time
			var expected_time = (beat_count - 1) * beat_manager.seconds_per_beat
			beat_times.append(expected_time)
	
	# Connect to beat_hit signal
	beat_manager.beat_hit.connect(beat_hit_connection)
	
	# Start playing music - use a track with a beat map for best results
	beat_manager.play_track(0)  # Adjust index based on your tracks
	
	print("Music started - waiting for first key press to begin calibration")

func start_calibration_measurement():
	calibration_started = true
	is_calibrating = true
	set_ui_state_calibrating()
	print("Calibration measurement started - continue pressing K on each beat")

func finish_calibration():
	is_calibrating = false
	calibration_started = false
	beat_manager.stop_track()
	
	# Disconnect the signal
	if beat_manager.beat_hit.is_connected(beat_hit_connection):
		beat_manager.beat_hit.disconnect(beat_hit_connection)
	
	calculate_and_display_offset()
	set_ui_state_complete()

func reset_calibration():
	is_calibrating = false
	calibration_started = false
	input_count = 0
	beat_times.clear()
	player_input_times.clear()
	result_label.text = "Ideal Offset: Not calculated"
	counter_label.text = "Inputs: 0 / %d" % CALIBRATION_COUNT
	
	# Disconnect signal if connected
	if beat_hit_connection and beat_manager.beat_hit.is_connected(beat_hit_connection):
		beat_manager.beat_hit.disconnect(beat_hit_connection)
	
	# Stop any playing track
	beat_manager.stop_track()
	
	# Restore original offset
	BeatManager.timing_offset = original_offset

func calculate_and_display_offset():
	# Ensure we have data to work with
	var num_inputs = player_input_times.size()
	var num_beats = beat_times.size()
	
	if num_inputs == 0:
		result_label.text = "Error: No inputs recorded."
		BeatManager.timing_offset = original_offset
		return
	
	if num_beats == 0:
		result_label.text = "Error: No beats recorded."
		BeatManager.timing_offset = original_offset
		return
	
	# Match inputs to nearest beats
	var total_offset: float = 0.0
	var valid_samples: int = 0
	
	for input_time in player_input_times:
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
			total_offset += offset
			valid_samples += 1
			print("Input at %.3f matched to beat at %.3f, offset: %.3f" % [input_time, closest_beat_time, offset])
	
	if valid_samples == 0:
		result_label.text = "Error: No valid input-beat pairs found."
		BeatManager.timing_offset = original_offset
		return
	
	# Calculate average offset
	var average_offset = total_offset / valid_samples
	
	# The timing_offset should be negative of the player's delay
	# If player consistently hits 50ms late, we need -50ms offset to compensate
	var recommended_offset = -average_offset
	
	# Display results
	result_label.text = "Player avg delay: %.3f ms\nRecommended offset: %.3f ms" % [average_offset * 1000, recommended_offset * 1000]
	
	# Apply the recommended offset
	BeatManager.timing_offset = recommended_offset
	
	print("Calibration complete:")
	print("- Average player delay: %.3f seconds" % average_offset)
	print("- Recommended timing_offset: %.3f seconds" % recommended_offset)
	print("- Applied to BeatManager")

# Optional: Add a button to test the new offset
func test_new_offset():
	if not is_calibrating:
		print("Testing with new offset: %.3f" % BeatManager.timing_offset)
		beat_manager.play_track(0)
