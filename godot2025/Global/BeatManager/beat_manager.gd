extends Node

func on_beat_timeout():
	emit_signal("beat_hit")

## implementacja prosto z chata, może ci pomoże a jak nie to wywal. W założeniu: on action_window_start enemy oraz gracz kolejkują ruchy, które są wykonywane w tym samym czasie.
## Trzeba zsynchronizować z muzyką
	
signal beat_hit(beat_count: int)
signal measure_complete(measure_count: int)
signal tempo_changed(new_bpm: float)
signal action_window_start()  # When players can input actions
signal action_window_end()    # When input window closes
signal execute_actions()      # When all queued actions execute

@export var bpm: float = 120.0
@export var beats_per_measure: int = 4
@export var input_window_duration: float = 0.8  # How long players have to input (as fraction of beat)

var beat_count: int = 0
var measure_count: int = 0
var beat_timer: Timer
var input_window_timer: Timer
var seconds_per_beat: float
var accepting_input: bool = false

# Action queue system
var queued_actions: Array[Dictionary] = []

func _ready():
	setup_timers()
	
func setup_timers():
	# Main beat timer
	beat_timer = Timer.new()
	add_child(beat_timer)
	beat_timer.timeout.connect(_on_beat)
	
	# Input window timer
	input_window_timer = Timer.new()
	add_child(input_window_timer)
	input_window_timer.timeout.connect(_on_input_window_end)
	input_window_timer.one_shot = true
	
	update_tempo()
	beat_timer.start()

func update_tempo():
	seconds_per_beat = 60.0 / bpm
	if beat_timer:
		beat_timer.wait_time = seconds_per_beat

func _on_beat():
	beat_count += 1
	
	# First, execute all queued actions from previous beat
	if queued_actions.size() > 0:
		execute_actions.emit()
		execute_queued_actions()
	
	# Then start new input window for next beat
	start_input_window()
	
	beat_hit.emit(beat_count)
	
	# Check if measure is complete
	if beat_count % beats_per_measure == 0:
		measure_count += 1
		measure_complete.emit(measure_count)

func start_input_window():
	accepting_input = true
	queued_actions.clear()
	action_window_start.emit()
	
	# Set timer for when input window closes
	input_window_timer.wait_time = seconds_per_beat * input_window_duration
	input_window_timer.start()

func _on_input_window_end():
	accepting_input = false
	action_window_end.emit()

func queue_action(actor: Node, action_type: String, action_data: Dictionary = {}):
	if not accepting_input:
		return false
	
	var action = {
		"actor": actor,
		"type": action_type,
		"data": action_data,
		"timestamp": Time.get_time_dict_from_system()
	}
	
	queued_actions.append(action)
	return true

func execute_queued_actions():
	# Sort actions by priority if needed (optional)
	# queued_actions.sort_custom(func(a, b): return a.get("priority", 0) > b.get("priority", 0))
	
	for action in queued_actions:
		if is_instance_valid(action.actor):
			action.actor.execute_action(action.type, action.data)
	
	queued_actions.clear()

func is_input_window_open() -> bool:
	return accepting_input

func set_bpm(new_bpm: float):
	bpm = new_bpm
	update_tempo()
	tempo_changed.emit(bpm)

func start_beats():
	if beat_timer:
		beat_timer.start()

func stop_beats():
	if beat_timer:
		beat_timer.stop()

func reset_beats():
	beat_count = 0
	measure_count = 0
	queued_actions.clear()
	accepting_input = false
