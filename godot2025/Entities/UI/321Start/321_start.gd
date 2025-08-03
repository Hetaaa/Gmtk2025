extends Node2D

@onready var countdown_label = $CountdownLabel  # Add this UI element to your scene

var countdown_timer: Timer
var countdown_started: bool = false

func _ready() -> void:
	BeatManager.mapLoaded.connect(start_countdown_system)
	countdown_timer = Timer.new()
	add_child(countdown_timer)
	countdown_timer.wait_time = 1.0  # 1 second intervals
	countdown_timer.timeout.connect(_on_countdown_tick)


func start_countdown_system():
	if BeatManager.beat_map.size() == 0:
		print("No beats in beat_map!")
		return
	
	var first_beat_time = BeatManager.beat_map[0]
	var countdown_start_time = first_beat_time - 3.0
	
	# If countdown should start immediately or has already passed
	if countdown_start_time <= 0:
		start_countdown()
	else:
		# Wait until 3 seconds before first beat
		var delay_timer = Timer.new()
		add_child(delay_timer)
		delay_timer.wait_time = countdown_start_time
		delay_timer.one_shot = true
		delay_timer.timeout.connect(start_countdown)
		delay_timer.start()

func start_countdown():
	if countdown_started:
		return
		
	countdown_started = true
	show_countdown_number(3)
	countdown_timer.start()

var current_countdown = 3

func _on_countdown_tick():
	current_countdown -= 1
	
	if current_countdown > 0:
		show_countdown_number(current_countdown)
	elif current_countdown == 0:
		show_fight_text()
		countdown_timer.stop()
		# Hide countdown after showing "FIGHT!"
		var hide_timer = Timer.new()
		add_child(hide_timer)
		hide_timer.wait_time = 1.0
		hide_timer.one_shot = true
		hide_timer.timeout.connect(hide_countdown)
		hide_timer.start()

func show_countdown_number(number: int):
	if countdown_label:
		countdown_label.text = str(number)
		countdown_label.visible = true
		# Removed the scaling animation for countdown numbers.
		# They will just appear at their normal scale.

func show_fight_text():
	if countdown_label:
		countdown_label.text = "FIGHT!"
		countdown_label.visible = true # Ensure it's visible when "FIGHT!" appears
		countdown_label.modulate = Color(1, 1, 1, 1) # Ensure it's fully opaque initially

		var tween = create_tween()
		
		# 1. Wait for 1 second (the duration "FIGHT!" is visible at full opacity)
		tween.tween_interval(1.0) # This pauses the tween for 1 second

		# 2. After the 1-second delay, start the fade-out
		tween.tween_property(countdown_label, "modulate", Color(1, 1, 1, 0), 0.2) # Fade out over 0.2 seconds
		
		# 3. After the fade-out is complete, hide the label
		tween.tween_callback(func(): countdown_label.visible = false)

func hide_countdown():
	if countdown_label:
		countdown_label.visible = false
		countdown_label.scale = Vector2(1.0, 1.0)  # Reset scale
