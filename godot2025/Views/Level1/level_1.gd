extends Node2D
@onready var beatslider = $BeatSlider

func _ready() -> void:
	BeatManager.play_track(9, 4)
	
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")
	beatslider.start_beats(0.0)
