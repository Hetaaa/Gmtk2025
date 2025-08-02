extends Control

@onready var health_bar: ProgressBar = $HealthBar
@onready var health_label: Label = $HealthLabel

func _ready():
	# Initialize the health bar
	update_health_bar()
	
	if FightManager.player_ref:
		FightManager.player_ref.health_changed.connect(_on_health_changed)

func _process(_delta):
	# Update health bar every frame (you might want to optimize this)
	update_health_bar()

func update_health_bar():
	if not FightManager or not FightManager.player_ref:
		return
	
	var current_hp = FightManager.player_ref.current_health
	var max_hp = FightManager.player_ref.max_health
	
	# Update progress bar
	health_bar.max_value = max_hp
	health_bar.value = current_hp
	
	# Update label text
	health_label.text = str(current_hp) + " / " + str(max_hp)
	
	# Optional: Change color based on health percentage
	var health_percentage = float(current_hp) / float(max_hp)
	if health_percentage > 0.6:
		health_bar.modulate = Color(0.22, 1, 0.08, 1)  # Green RGB (fully opaque)
		health_label.add_theme_color_override("font_color", Color.WHITE) # Set text to white
	elif health_percentage > 0.3:
		health_bar.modulate = Color(0.93, 0.92, 0.22, 1)   # Yellow RGB (fully opaque)
		health_label.add_theme_color_override("font_color", Color.BLACK) # Example: set text to black
	else:
		health_bar.modulate = Color(0.93, 0, 0.01, 1)   # Red RGB (fully opaque)
		health_label.add_theme_color_override("font_color", Color.WHITE) # Example: set text to white
	
	# The health_label.modulate = Color.WHITE line can be removed as add_theme_color_override is more direct for font color.
	# health_label.modulate = Color.WHITE # This line is less effective for font color directly

# Optional: More efficient update method if you have health change signals
func _on_health_changed():
	update_health_bar()
