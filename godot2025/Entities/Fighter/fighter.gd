class_name Fighter extends CharacterBody2D

func _ready():
	BeatManager.action_window_start.connect(_on_action_window_start)
	BeatManager.action_window_end.connect(_on_action_window_end)
	BeatManager.execute_actions.connect(_on_execute_actions)
	print("Test is ready!")
	
	BeatManager.play_track(1)


func _on_action_window_start():
	modulate = Color.WHITE * 1.1

func _on_action_window_end():
	# Visual indicator that input window closed
	modulate = Color.WHITE * 0.9
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func _on_execute_actions():
	# All actions execute simultaneously - visual feedback
	pass

func execute_action(action_type: String, action_data: Dictionary):
	if action_type == "attack":
		#print("🎯 Executing attack with power:", action_data.get("power", 0))
		
		if BeatManager.is_paused:
			BeatManager.resume_beats()
		else:
			BeatManager.pause_beats()



func _input(event):
	if event.is_action_pressed("attack"): 
		queue_attack()

func queue_attack():
	if BeatManager.is_input_window_open():
		var success = BeatManager.queue_action(self, "attack", {"power": 5})
		if success:
			print("✅ Attack queued in rhythm!")
		else:
			print("⚠️ Failed to queue attack.")
	else:
		print("❌ Attack ignored – not in rhythm window.")
