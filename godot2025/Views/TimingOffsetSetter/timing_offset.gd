extends Control

# Constants
const CALIBRATION_COUNT = 10

# UI elements
@onready var instructions_label := $Panel/VBoxContainer/Instructions
@onready var counter_label := $Panel/VBoxContainer/InputCounter
@onready var result_label := $Panel/VBoxContainer/OffsetResult
@onready var start_button := $Panel/VBoxContainer/StartButton
@onready var reset_button := $Panel/VBoxContainer/ResetButton

# Reference to your BeatManager singleton
@onready var beat_manager = get_node("/root/BeatManager")

# Calibration state
var is_calibrating: bool = false
var input_count: int = 0
var ideal_beat_times: Array = []
var player_input_times: Array = []

func _ready():
	BeatManager.timing_offset = 0
	reset_button.hide()
	# Set the initial state of the UI
	_set_ui_state(false)

func _set_ui_state(calibrating: bool):
	instructions_label.text = "Press the K to the beat 10 times." if not calibrating else "Listen carefully and press K on each beat."
	start_button.visible = not calibrating
	reset_button.visible = not start_button.visible
	counter_label.visible = calibrating
	result_label.visible = not calibrating

func _input(event: InputEvent):
	if is_calibrating and event.is_action_pressed("ATTACK_MID"):
		# Record the player's input time relative to the music stream
		var input_time = beat_manager.music_player.get_playback_position()
		player_input_times.append(input_time)
		input_count += 1
		counter_label.text = "Inputs: %s / %s" % [input_count, CALIBRATION_COUNT]
		
		# Check if we have enough inputs to finish
		if input_count >= CALIBRATION_COUNT:
			_finish_calibration()

func _on_start_button_pressed():
	# Reset state and start the process
	_reset_calibration()
	_start_calibration()

func _on_reset_button_pressed():
	_reset_calibration()
	_start_calibration()

func _start_calibration():
	is_calibrating = true
	_set_ui_state(true)
	
	# Connect to the beat_hit signal to get the ideal beat times
	# We use a lambda to ensure the connection is temporary and easy to disconnect
	beat_manager.beat_hit.connect(func(beat_count):
		# Only record the first CALIBRATION_COUNT beats
		if beat_count <= CALIBRATION_COUNT:
			var beat_time = beat_manager.music_player.get_playback_position()
			ideal_beat_times.append(beat_time)
		# After recording the last beat, we can disconnect to be clean
		if beat_count == CALIBRATION_COUNT:
			beat_manager.beat_hit.disconnect(beat_manager.beat_hit.get_connections().back().callable)
	)

	# Start the beat manager's music and timer
	# We'll use the second track for this example
	beat_manager.play_track(1)

func _finish_calibration():
	is_calibrating = false
	beat_manager.stop_track()
	_calculate_and_display_offset()
	_set_ui_state(false)
	reset_button.show()
	start_button.hide()
	
func _reset_calibration():
	is_calibrating = false
	input_count = 0
	ideal_beat_times.clear()
	player_input_times.clear()
	result_label.text = "Ideal Offset: Calculating..."
	counter_label.text = "Inputs: 0 / 10"
	_set_ui_state(false)

func _calculate_and_display_offset():
	var total_offset: float = 0.0
	
	# Ensure we have the same number of input and ideal beat times
	var num_samples = min(player_input_times.size(), ideal_beat_times.size())
	if num_samples == 0:
		result_label.text = "Error: No inputs recorded."
		return
	
	for i in range(num_samples):
		# Calculate the difference for each input
		var offset = player_input_times[i] - ideal_beat_times[i]
		total_offset += offset
		
	# Calculate the average offset
	var average_offset = total_offset / num_samples
	
	# Display the result
	result_label.text = "Ideal Offset: %.3f" % [average_offset]
	BeatManager.timing_offset = average_offset
	
	# You can now use this value to update your BeatManager's timing_offset!
	print("Calculated ideal timing_offset: ", average_offset)
