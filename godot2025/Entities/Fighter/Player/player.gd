class_name Player extends Fighter

@export var max_health: int = 3

var current_health: int
var selected_action_enum: FightEnums.Action = FightEnums.Action.NULL # Store the enum value
var selected_timing_enum: FightEnums.BeatTiming = FightEnums.BeatTiming.NULL

var hit_sound: AudioStreamPlayer

@onready var Sprite = $Sprite2D
@onready var button_display_container = $ButtonDisplayContainer
@onready var button_icon = $ButtonDisplayContainer/ButtonIcon
@onready var hurt_sound = $HurtSound
@onready var flash_shader = preload("res://shader/flash.tres")
@onready var highlight_shader = preload("res://shader/highlight.tres")

var action_to_button_texture = {
	FightEnums.Action.BLOCK_HIGH: "W.png",
	FightEnums.Action.BLOCK_MIDDLE: "S.png", 
	FightEnums.Action.BLOCK_LOW: "X.png",
	FightEnums.Action.ATTACK_HIGH: "O.png",
	FightEnums.Action.ATTACK_MIDDLE: "K.png",
	FightEnums.Action.ATTACK_LOW: "M.png"
}

var shader_material : ShaderMaterial

# Button animation state management
var button_animation_tween: Tween
var is_button_animating: bool = false

func _ready():
	current_health = max_health
	Sprite.material = flash_shader
	
	Sprite.play("WAIT")
	FightManager.register_player(self)
	shader_material = Sprite.material
	hit_sound = AudioStreamPlayer.new()
	hit_sound.stream = load("res://audio/hit3.wav")
	add_child(hit_sound)
	if button_icon:
		button_icon.visible = false

func _input(event):
	# WAŻNE: Sprawdź czy EndScreenManager kontroluje input
	if EndScreenManager.is_end_screen_active():
		print("Player: Blocking input - EndScreenManager is active")
		return  # Nie obsługuj inputu gdy ekran końcowy jest aktywny
	
	# Allow input anytime, but let the system validate timing	
	if event.is_action_pressed("ATTACK_HIGH"):
		submit_player_action_to_manager(FightEnums.Action.ATTACK_HIGH)
	elif event.is_action_pressed("ATTACK_LOW"):
		submit_player_action_to_manager(FightEnums.Action.ATTACK_LOW)
	elif event.is_action_pressed("ATTACK_MID"):
		submit_player_action_to_manager(FightEnums.Action.ATTACK_MIDDLE)
	elif event.is_action_pressed("BLOCK_HIGH"):
		submit_player_action_to_manager(FightEnums.Action.BLOCK_HIGH)
	elif event.is_action_pressed("BLOCK_LOW"):
		submit_player_action_to_manager(FightEnums.Action.BLOCK_LOW)
	elif event.is_action_pressed("BLOCK_MID"):
		submit_player_action_to_manager(FightEnums.Action.BLOCK_MIDDLE)

func submit_player_action_to_manager(action: FightEnums.Action):
	# Debug the window state before processing
	print("Currtime" + str(BeatManager._get_current_time()))
	print("=== Player Input Debug ===")
	print("Action: ", FightEnums.Action.keys()[action])
	
	# Get timing before submitting (this will consume the window)
	var timing = BeatManager.get_current_beat_timing()
	print("Timing result: ", FightEnums.BeatTiming.keys()[timing])
	
	# Use the new submit method which handles timing validation internally
	FightManager.submit_player_action(action)
	print("From player.gd = Player pressed " + FightEnums.Action.keys()[action] + ' ' + FightEnums.BeatTiming.keys()[timing])
	

	
	# Store the selected action and timing locally for display
	selected_action_enum = action
	selected_timing_enum = timing

func show_button_animation(action: FightEnums.Action):
	"""Pokazuje animację przycisku nad głową gracza z proper cleanup"""
	if not button_icon or not action_to_button_texture.has(action):
		return
	
	# KRYTYCZNE: Zatrzymaj poprzednią animację jeśli trwa
	_cleanup_button_animation()
	
	# Jeśli animacja już trwa, nie rozpoczynaj nowej
	if is_button_animating:
		print("Button animation already in progress, skipping...")
		return
	
	is_button_animating = true
	button_icon.visible = true
	
	# Załaduj odpowiednią teksturę
	var texture_path = "res://Textures/UI/KeyboardButtons/" + action_to_button_texture[action]
	var texture = load(texture_path)
	
	if not texture:
		_reset_button_state()
		return
	
	button_icon.texture = texture
	
	# Reset pozycji i właściwości
	var start_pos = Vector2(0, -80)
	var end_pos = Vector2(0, -120)
	
	button_icon.position = start_pos
	button_icon.scale = Vector2(1.0, 1.0)
	button_icon.modulate.a = 0.0
	
	# Utwórz nowy tween z proper cleanup
	button_animation_tween = create_tween()
	button_animation_tween.set_parallel(true)
	
	# Połącz sygnał finished dla cleanup
	button_animation_tween.finished.connect(_on_button_animation_finished, CONNECT_ONE_SHOT)
	
	# Animacja opacity: 0 -> 1 -> 0
	button_animation_tween.tween_method(_set_button_alpha, 0.0, 1.0, 0.3)
	button_animation_tween.tween_method(_set_button_alpha, 1.0, 0.0, 0.3).set_delay(0.6)
	
	# Animacja pozycji: ruch w górę
	button_animation_tween.tween_property(button_icon, "position", end_pos, 0.9)
	
	# Opcjonalnie: lekkie skalowanie dla efektu
	button_animation_tween.tween_property(button_icon, "scale", Vector2(1.2, 1.2), 0.15)
	button_animation_tween.tween_property(button_icon, "scale", Vector2(1.0, 1.0), 0.15).set_delay(0.15)

func _cleanup_button_animation():
	"""Czyści poprzednią animację przycisku"""
	if button_animation_tween and button_animation_tween.is_valid():
		button_animation_tween.kill()
		button_animation_tween = null
	
	is_button_animating = false

func _on_button_animation_finished():
	"""Callback wywoływany gdy animacja się kończy"""
	print("Button animation finished, cleaning up...")
	_reset_button_state()

func _reset_button_state():
	"""Resetuje stan ikony przycisku do stanu początkowego"""
	is_button_animating = false
	if button_icon:
		button_icon.visible = false
		button_icon.modulate.a = 1.0  # Reset alpha
		button_icon.scale = Vector2(1.0, 1.0)  # Reset scale
		button_icon.position = Vector2(0, -80)  # Reset position
	
	button_animation_tween = null

func _set_button_alpha(alpha: float):
	"""Helper function do ustawiania alpha ikony przycisku"""
	if button_icon:
		button_icon.modulate.a = alpha

# WAŻNE: Cleanup przy niszczeniu obiektu
func _exit_tree():
	_cleanup_button_animation()
		
func take_damage(amount: int):
	current_health -= amount
	current_health = max(0, current_health)
	
	#Sound effect
	hit_sound.play()
	
	Sprite.play("PLAYER_HIT")
	hurt_sound.play()
	# Visual damage effect
	#modulate = Color.RED
	#var tween = create_tween()
	#tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	health_changed.emit()
	shader_material.set_shader_parameter("active", true)
	await get_tree().create_timer(0.1, false).timeout
	shader_material.set_shader_parameter("active", false)

func change_animation(anim : StringName):
	print("NAZWA ANIMACJI ", anim)
	Sprite.play(anim)

func _on_sprite_2d_animation_finished() -> void:
	change_animation("WAIT")

func highlight():
	Sprite.material = highlight_shader
	await get_tree().create_timer(0.4, false).timeout
	Sprite.material = flash_shader
