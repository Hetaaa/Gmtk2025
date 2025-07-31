extends Node2D

func _ready() -> void:
	BeatManager.play_track(1)
	BeatManager.start_beats()
