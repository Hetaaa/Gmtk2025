extends Node2D

func _ready() -> void:

	BeatManager.play_track(0)
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")

