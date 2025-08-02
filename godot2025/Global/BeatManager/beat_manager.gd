extends Node

signal beat_hit(beat_count: int)
signal measure_complete(measure_count: int)
signal tempo_changed(new_bpm: float)

signal action_window_open(window_id: int, beat_count: int)
signal action_window_close(window_id: int, beat_count: int)
signal resolve_round(window_id: int, beat_count: int)

@onready var music_player := AudioStreamPlayer.new()
@onready var beat_indicator_player := AudioStreamPlayer.new()

@export var bpm: float = 60.0
@export var beats_per_measure: int = 4
@export var grace_period: float = 0.4
@export var timing_offset: float = 0.00

@export var beat_sound_path: String = "res://Global/BeatManager/audiomass-output.mp3"

@export var use_beat_map := false
@export var beat_map: Array[float] = []

var is_paused = true

var beat_count := 0
var measure_count := 0
var beat_index := 0

var beat_timer: Timer
var seconds_per_beat: float

# New: Track multiple overlapping action windows
var active_windows: Array[ActionWindow] = []
var next_window_id := 0

# ActionWindow class to track individual windows
class ActionWindow:
	var id: int
	var beat_count: int
	var target_beat_time: float
	var window_start_time: float
	var window_end_time: float
	var is_open: bool = false
	var is_resolved: bool = false
	
	func _init(window_id: int, beat_num: int, beat_time: float, grace: float, offset: float):
		id = window_id
		beat_count = beat_num
		target_beat_time = beat_time + offset
		window_start_time = target_beat_time - (grace / 2.0)
		window_end_time = target_beat_time + (grace / 2.0)

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
		"path": "res://Audio/soyouthinkmucheasier.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/soyouthinkMap.txt"
	},
	{ 
		"path": "res://Audio/synthdrill.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/synthdrillMap.txt"
	},
	{ 
		"path": "res://Audio/bonus.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/bonusMap.txt"
	},
	{ 
		"path": "res://Audio/thebindingofbeatboxer.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/bindingMap.txt"
	},
	{ 
		"path": "res://Audio/pluck.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/pluckMap.txt"
	},
	{ 
		"path": "res://Audio/hihatcity.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/hihatMap.txt"
	},
	{ 
		"path": "res://Audio/jazdazkur.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/jazdaMap.txt"
	},
	{ 
		"path": "res://Audio/fastmeloody.mp3", 
		"beat_map_file": "res://Audio/BeatMaps/festMap.txt"
	}
]

func _ready():
	setup_timer()
	add_child(music_player)
	add_child(beat_indicator_player)
	beat_indicator_player.stream = load(beat_sound_path)
	beat_hit.connect(_on_beat_hit_play_sound)

var last_time := 0.0

func _process(_delta):
	if is_paused:
		return
	
	var current_time = music_player.get_playback_position() if use_beat_map else 0.0
	
	if use_beat_map:
		# If track reversed (e.g., loop), reset
		if current_time < last_time:
			beat_index = 0
			beat_count = 0
			measure_count = 0
			_reset_all_windows()

		last_time = current_time

		if beat_index < beat_map.size():
			var current_beat_time = beat_map[beat_index]
			var beat_scheduling_trigger_time = current_beat_time - 0.5

			if current_time >= beat_scheduling_trigger_time:
				beat_count += 1
				if beat_count % beats_per_measure == 0:
					measure_count += 1
					measure_complete.emit(measure_count)
				
				_schedule_beat_events_custom(current_beat_time)
				beat_index += 1
	
	# Update all active windows
	_update_active_windows()

func _update_active_windows():
	var current_time = _get_current_time()
	
	# Check for windows that need to open
	for window in active_windows:
		if not window.is_open and current_time >= window.window_start_time:
			window.is_open = true
			action_window_open.emit(window.id, window.beat_count)
	
	# Check for windows that need to close and resolve
	var windows_to_remove = []
	for window in active_windows:
		if window.is_open and not window.is_resolved and current_time >= window.window_end_time:
			window.is_resolved = true
			action_window_close.emit(window.id, window.beat_count)
			resolve_round.emit(window.id, window.beat_count)
			windows_to_remove.append(window)
		# Also remove windows that were marked as resolved immediately
		elif window.is_resolved:
			windows_to_remove.append(window)
	
	# Remove resolved windows
	for window in windows_to_remove:
		active_windows.erase(window)

func _get_current_time() -> float:
	if use_beat_map:
		return music_player.get_playback_position() + timing_offset
	else:
		return Time.get_ticks_msec() / 1000.0

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
	_reset_all_windows()

func _reset_all_windows():
	active_windows.clear()
	next_window_id = 0

func _on_beat_timer_timeout():
	if is_paused or use_beat_map:
		return

	beat_count += 1
	if beat_count % beats_per_measure == 0:
		measure_count += 1
		measure_complete.emit(measure_count)

	_schedule_beat_events()

func _schedule_beat_events():
	var current_time = _get_current_time()
	var target_beat_time = current_time + timing_offset
	
	# Create new action window
	var window = ActionWindow.new(next_window_id, beat_count, target_beat_time, grace_period, 0.0)
	next_window_id += 1
	active_windows.append(window)
	
	# Schedule beat hit signal
	get_tree().create_timer(timing_offset).timeout.connect(
		func():
			beat_hit.emit(beat_count)
	)

func _schedule_beat_events_custom(beat_time: float):
	# Create new action window
	var window = ActionWindow.new(next_window_id, beat_count, beat_time, grace_period, timing_offset)
	next_window_id += 1
	active_windows.append(window)
	
	# Schedule beat hit signal
	var current_time = music_player.get_playback_position()
	var delay_to_hit = (beat_time + timing_offset) - current_time
	
	if delay_to_hit <= 0:
		beat_hit.emit(beat_count)
	else:
		var timer_hit = get_tree().create_timer(delay_to_hit, false)
		timer_hit.timeout.connect(func(): beat_hit.emit(beat_count))

func _on_beat_hit_play_sound(_beat_count: int):
	if beat_indicator_player.stream:
		beat_indicator_player.play()

# Get the earliest open window that can accept input
func get_earliest_open_window() -> int:
	var earliest_window = null
	for window in active_windows:
		if window.is_open and not window.is_resolved:
			if earliest_window == null or window.target_beat_time < earliest_window.target_beat_time:
				earliest_window = window
	
	return earliest_window.id if earliest_window else -1

# Get timing for a specific window
func get_timing_for_window(window_id: int) -> FightEnums.BeatTiming:
	var target_window = null
	for window in active_windows:
		if window.id == window_id:
			target_window = window
			break
	
	if not target_window:
		return FightEnums.BeatTiming.NULL
	
	var current_time = _get_current_time()
	var distance = abs(current_time - target_window.target_beat_time)
	print(distance)
	
	if distance <= 0.1:
		return FightEnums.BeatTiming.PERFECT
	elif distance <= 0.15:
		return FightEnums.BeatTiming.GOOD
	elif distance <= 0.25:
		return FightEnums.BeatTiming.NICE
	elif distance <= grace_period / 2.0:
		return FightEnums.BeatTiming.LATE
	else:
		return FightEnums.BeatTiming.NULL

# Legacy method for backward compatibility - returns timing for earliest window
func get_current_beat_timing() -> FightEnums.BeatTiming:
	var earliest_id = get_earliest_open_window()
	if earliest_id == -1:
		return FightEnums.BeatTiming.NULL
	return get_timing_for_window(earliest_id)

# Check if any action window is currently open
func has_open_window() -> bool:
	for window in active_windows:
		if window.is_open and not window.is_resolved:
			return true
	return false

# Get all currently open window IDs
func get_open_window_ids() -> Array[int]:
	var ids: Array[int] = []
	for window in active_windows:
		if window.is_open and not window.is_resolved:
			ids.append(window.id)
	return ids

# Mark a window as resolved (called when FightManager resolves immediately)
func mark_window_resolved(window_id: int):
	for window in active_windows:
		if window.id == window_id:
			window.is_resolved = true
			break

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
