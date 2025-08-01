extends Node

signal beat_hit(beat_count: int)
signal measure_complete(measure_count: int)
signal tempo_changed(new_bpm: float)

signal action_window_open()
signal action_window_close()
signal resolve_current_round()

@onready var music_player := AudioStreamPlayer.new()
@onready var beat_indicator_player := AudioStreamPlayer.new() # New AudioStreamPlayer for the beat sound

@export var bpm: float = 60.0
@export var beats_per_measure: int = 4
@export var grace_period: float = 0.4  # Total grace window centered on beat
@export var timing_offset: float = 0.023 # This offset shifts the entire timing sequence

@export var beat_sound_path: String = "res://Global/BeatManager/audiomass-output.mp3"# Path to your beat sound file (e.g., a kick drum)

var is_paused = true

var beat_count := 0
var measure_count := 0
var beat_timer: Timer
var seconds_per_beat: float

var action_window_opened := false

var tracks = [
	{ "path": "res://audio/oldDisc.mp3", "bpm": 35.7 },
	{ "path": "res://audio/synth136.mp3", "bpm": 136 },
	{ "path": "res://audio/noca90.mp3", "bpm": 90 },
	{ "path": "res://audio/trance150.mp3", "bpm": 150 },
	{ "path": "res://audio/techno120.mp3", "bpm": 150 }
]

func _ready():
	setup_timer()
	add_child(music_player)
	add_child(beat_indicator_player) # Add the new beat indicator player to the scene
	beat_indicator_player.stream = load(beat_sound_path) # Load the beat sound

	# Connect the beat_hit signal to play the beat sound
	beat_hit.connect(_on_beat_hit_play_sound)

func setup_timer():
	beat_timer = Timer.new()
	beat_timer.one_shot = false
	add_child(beat_timer)
	beat_timer.timeout.connect(_on_beat_timer_timeout)
	update_tempo()

func update_tempo():
	seconds_per_beat = 60.0 / bpm
	if beat_timer:
		beat_timer.wait_time = seconds_per_beat

func set_bpm(new_bpm: float):
	bpm = new_bpm
	update_tempo()
	tempo_changed.emit(bpm)

func play_track(index: int):
	reset()
	var track = tracks[index]
	set_bpm(track["bpm"])
	music_player.stream = load(track["path"])
	music_player.stream.loop = true
	music_player.play()
	is_paused = false
	beat_timer.start()

func stop_track():
	music_player.stop()
	beat_timer.stop()
	reset()
	is_paused = true

func reset():
	beat_count = 0
	measure_count = 0
	action_window_opened = false

func _on_beat_timer_timeout():
	if is_paused:
		return

	beat_count += 1
	if beat_count % beats_per_measure == 0:
		measure_count += 1
		measure_complete.emit(measure_count)

	_schedule_beat_events()

func _schedule_beat_events():
	var time_to_actual_beat = timing_offset

	var time_to_action_window_open = time_to_actual_beat - (grace_period / 2.0)
	if time_to_action_window_open < 0:
		_open_action_window()
	else:
		get_tree().create_timer(time_to_action_window_open).timeout.connect(_open_action_window)

	get_tree().create_timer(time_to_actual_beat).timeout.connect(
		func():
			beat_hit.emit(beat_count) # This signal now triggers the beat sound
	)

	var time_to_action_window_close = time_to_actual_beat + (grace_period / 2.0)
	get_tree().create_timer(time_to_action_window_close).timeout.connect(_close_action_window)

func _open_action_window():
	if not action_window_opened:
		action_window_opened = true
		action_window_open.emit()

func _close_action_window():
	if action_window_opened:
		action_window_opened = false
		action_window_close.emit()
		resolve_current_round.emit()

# New function to play the beat sound
func _on_beat_hit_play_sound(_beat_count: int):
	if beat_indicator_player.stream:
		#beat_indicator_player.play()
		pass

func can_accept_input() -> bool:
	if is_paused or not action_window_opened:
		return false

	var current_playback_time = music_player.get_playback_position()
	var ideal_beat_time_relative_to_zero = fmod(current_playback_time + timing_offset, seconds_per_beat)

	if ideal_beat_time_relative_to_zero < 0:
		ideal_beat_time_relative_to_zero += seconds_per_beat

	var half_grace = grace_period / 2.0

	return (ideal_beat_time_relative_to_zero <= half_grace) or \
		   (ideal_beat_time_relative_to_zero >= seconds_per_beat - half_grace)

func get_current_beat_timing() -> FightEnums.BeatTiming:
	var current_playback_time = music_player.get_playback_position()
	var ideal_beat_time_relative_to_zero = fmod(current_playback_time + timing_offset, seconds_per_beat)

	if ideal_beat_time_relative_to_zero < 0:
		ideal_beat_time_relative_to_zero += seconds_per_beat

	var beat_distance = min(ideal_beat_time_relative_to_zero, seconds_per_beat - ideal_beat_time_relative_to_zero)

	print (beat_distance)
	
	if not can_accept_input():
		print("window closed")
		return FightEnums.BeatTiming.NULL

	if beat_distance <= 0.05:
		return FightEnums.BeatTiming.PERFECT
	elif beat_distance <= 0.1:
		return FightEnums.BeatTiming.GOOD
	elif beat_distance <= 0.15:
		return FightEnums.BeatTiming.NICE
	elif beat_distance <= grace_period / 2.0:
		return FightEnums.BeatTiming.LATE
	else:
		return FightEnums.BeatTiming.NULL
