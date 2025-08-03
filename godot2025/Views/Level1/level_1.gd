extends Node2D
@onready var beatslider = $BeatSlider


func _ready() -> void:

	BeatManager.play_track(0)
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")
	beatslider.start_beats(0.0)
	
	FightManager.fight_ended.connect(_on_fight_ended)

func _process(delta):
	var current_time = BeatManager._get_current_time()
	beatslider.update_time(current_time)

func _on_fight_ended(winner: String) -> void:
	BeatManager.stop_track()
	EndScreenManager.show(winner)
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		EndScreenManager.stop()
		set_process_input(false)
		print("Zamykam ekran końca walki.")
		# Tu można przejść do innej sceny

	
