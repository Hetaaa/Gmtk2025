class_name Player extends Fighter

func _ready():
	super._ready() # Ważne: Wywołaj _ready() z klasy bazowej

func queue_attack():
	var success = BeatManager.queue_action(self, "attack", {})

	
