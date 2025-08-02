extends Node2D
@onready var beatslider = $BeatSlider

func _ready() -> void:

	BeatManager.play_track(0)
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")
	beatslider.start_beats(0.0)


func _process(delta):
	var current_time = BeatManager._get_current_time()
	beatslider.update_time(current_time)
