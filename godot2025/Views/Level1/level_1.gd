extends Node2D
@onready var beatslider = $BeatSlider
@export var end_screen: Sprite2D

func _ready() -> void:
	end_screen.visible = false
	BeatManager.play_track(0)
	FightManager.load_phase_pattern("res://audio/BeatMaps/test.txt")
	beatslider.start_beats(0.0)
	
	FightManager.fight_ended.connect(_on_fight_ended)

func _process(delta):
	var current_time = BeatManager._get_current_time()
	beatslider.update_time(current_time)

func _on_fight_ended(winner: String) -> void:
	print("Walka zakończona. Zwycięzca: %s" % winner)
	BeatManager.stop_track()
	_show_end_screen(winner)

func _show_end_screen(winner: String) -> void:
	if winner != "Player":
		end_screen.texture = load("res://Entities/UI/FightEnd/Death_Screen.png")
	else:
		end_screen.texture = load("res://Entities/UI/FightEnd/WIN_SCREEN.png")

	end_screen.visible = true

	# Rozpocznij pulsowanie
	_start_pulsing()

	# Włącz input detection
	set_process_input(true)

var pulse_tween: Tween = null

func _start_pulsing() -> void:
	var base_scale = end_screen.scale 
	var pulse_up = base_scale * 1.1   
	var pulse_down = base_scale        
	
	pulse_tween = create_tween()
	pulse_tween.set_loops()  

	pulse_tween.tween_property(end_screen, "scale", pulse_up, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tween.tween_property(end_screen, "scale", pulse_down, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_stop_pulsing()
		set_process_input(false)
		print("Dowolny klawisz wciśnięty — możesz przejść dalej.")
		
		# Tu możesz np. przejść do innej sceny:
		# get_tree().change_scene_to_file("res://Menu.tscn")

func _stop_pulsing() -> void:
	if pulse_tween and pulse_tween.is_running():
		pulse_tween.kill()
	
