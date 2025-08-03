extends Control

@onready var credits_sprite: Sprite2D = $Credits

var credits_visible: bool = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	credits_sprite.visible = false


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_start_pressed() -> void:
		SceneManager.change_scene("choosing_levels")

func _on_rules_pressed() -> void:
	# pokazujemy credits
	credits_sprite.visible = true
	credits_visible = true

	# zabieramy fokus przyciskowi, żeby nie wisiał styl Focus
	var btn := get_viewport().gui_get_focus_owner()
	if btn and btn is Control:
		btn.focus_mode = Control.FOCUS_NONE
		await get_tree().process_frame  # poczekaj 1 klatkę
		btn.focus_mode = Control.FOCUS_ALL

func _on_exit_pressed() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	# Jeśli Credits są widoczne i wystąpi dowolne kliknięcie myszy lub klawiatury -> ukryj
	if credits_visible and (event is InputEventMouseButton or event is InputEventKey):
		credits_sprite.visible = false
		credits_visible = false
