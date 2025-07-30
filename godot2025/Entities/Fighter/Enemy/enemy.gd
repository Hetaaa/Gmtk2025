class_name Enemy extends Fighter

func _ready():
	super._ready() # Ważne: Wywołaj _ready() z klasy bazowej

func _on_beat_hit():
	return


func _on_action_window_start():
	BeatManager.queue_action(self, "attack", {})
