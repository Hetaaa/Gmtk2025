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

@export var use_beat_map := false
@export var beat_map: Array[float] = []

var is_paused = true

var beat_count := 0
var measure_count := 0
var beat_index := 0

var beat_timer: Timer
var seconds_per_beat: float

var action_window_opened := false

var tracks = [
	{ 
		"path": "res://Audio/oldDisc.mp3",
		"beat_map_file": "res://Audio//BeatMaps/oldDiscMap.txt"
	},
	{
		"path": "res://Audio/synth136.mp3", 
		"bpm": 136
	},
	{
		"path": "res://Audio/noca90.mp3",
		"bpm": 90 
	},
	{ 
		"path": "res://Audio/trance150.mp3", 
		"bpm": 150 
		},
	{ 
		"path": "res://Audio/techno120.mp3",
		"bpm": 150 
	},
	{ 
		"path": "res://Audio/soyouthink.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/soyouthinkMap.txt"
	}
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

	if track.has("beat_map_file"):
		use_beat_map = true
		beat_map = load_beat_map_from_file(track["beat_map_file"])

	else:
		use_beat_map = false
		set_bpm(track["bpm"])

	music_player.stream = load(track["path"])
	music_player.stream.loop = true
	music_player.play()
	is_paused = false

	if not use_beat_map:
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
	if is_paused or use_beat_map:
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

func _schedule_beat_events_custom(beat_time: float):
	var current_time = music_player.get_playback_position()
	var time_to_beat = beat_time - current_time

	var time_to_open = time_to_beat - (grace_period / 2.0)
	var time_to_close = time_to_beat + (grace_period / 2.0)

	if time_to_open <= 0:
		_open_action_window()
	else:
		get_tree().create_timer(time_to_open).timeout.connect(_open_action_window)

	get_tree().create_timer(time_to_close).timeout.connect(_close_action_window)

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
		beat_indicator_player.play()
		
var last_time := 0.0

func _process(_delta):
	if is_paused or not use_beat_map:
		return

	var current_time = music_player.get_playback_position()

	# Jeśli track cofnął się (czyli loop), resetujemy
	if current_time < last_time:
		beat_index = 0
		beat_count = 0
		measure_count = 0

	last_time = current_time

	if beat_index < beat_map.size() and current_time >= beat_map[beat_index] - timing_offset:
		beat_count += 1
		if beat_count % beats_per_measure == 0:
			measure_count += 1
			measure_complete.emit(measure_count)

		beat_hit.emit(beat_count)
		_schedule_beat_events_custom(beat_map[beat_index])
		beat_index += 1



func can_accept_input() -> bool:
	if is_paused or not action_window_opened:
		return false

	var current_playback_time = music_player.get_playback_position()
	
	var beat_time = seconds_per_beat if not use_beat_map else get_time_to_next_beat()
	if beat_time <= 0:
		return false
	
	var ideal_beat_time_relative_to_zero = fmod(current_playback_time + timing_offset, seconds_per_beat)
	if ideal_beat_time_relative_to_zero < 0:
		ideal_beat_time_relative_to_zero += seconds_per_beat

	var half_grace = grace_period / 2.0

	return (ideal_beat_time_relative_to_zero <= half_grace) or \
		   (ideal_beat_time_relative_to_zero >= seconds_per_beat - half_grace)

func get_time_to_next_beat() -> float:
	if beat_index < beat_map.size():
		return beat_map[beat_index] - music_player.get_playback_position()
	return seconds_per_beat

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
		
func load_beat_map_from_file(path: String) -> Array[float]:
	var beat_times: Array[float] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Nie udało się otworzyć pliku: " + path)
		return beat_times

	while not file.eof_reached():
		var line := file.get_line().strip_edges(true, true)
		if line != "":
			var parts := line.split(",", false)
			for part in parts:
				var number := part.strip_edges()
				if number != "":
					beat_times.append(float(number))

	file.close()
	return beat_times
