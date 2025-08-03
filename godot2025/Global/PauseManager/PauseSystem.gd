# PauseSystem.gd - Singleton (AutoLoad)
extends Node

signal game_paused
signal game_resumed

var is_game_paused: bool = false
var current_level: Node = null
var pause_menu: Control = null

# Komponenty do pauzowania/wznawiania
var pausable_components: Array[Dictionary] = []

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

# Rejestracja levelu i jego komponentów
func register_level(level: Node, components: Dictionary = {}):
	current_level = level
	pausable_components.clear()
	
	# Znajdź PauseMenu automatycznie
	pause_menu = find_pause_menu_in_level(level)
	if pause_menu:
		pause_menu.hide()
		print("PauseMenu znaleziony i zarejestrowany")
	else:
		print("OSTRZEŻENIE: PauseMenu nie został znaleziony!")
	
	# Zarejestruj komponenty do pauzowania
	if components.has("beatslider"):
		add_pausable_component("beatslider", components.beatslider)
	
	if components.has("beat_manager") and components.beat_manager:
		add_pausable_component("beat_manager", components.beat_manager)
	else:
		# Domyślnie użyj globalnego BeatManager
		add_pausable_component("beat_manager", BeatManager)

# Dodaj komponent do pauzowania
func add_pausable_component(name: String, component: Node):
	pausable_components.append({
		"name": name,
		"component": component
	})

# Znajdź PauseMenu w strukturze levelu
func find_pause_menu_in_level(level: Node) -> Control:
	return find_pause_menu_recursive(level)

func find_pause_menu_recursive(node: Node) -> Control:
	# Sprawdź czy to jest PauseMenu
	if node.name.to_lower().contains("pause") and node is Control:
		return node as Control
	
	# Rekurencyjnie sprawdź dzieci
	for child in node.get_children():
		var result = find_pause_menu_recursive(child)
		if result:
			return result
	
	return null

# Główna funkcja pauzowania
func pause_game():
	if is_game_paused:
		return
		
	is_game_paused = true
	get_tree().paused = true
	
	if pause_menu:
		pause_menu.show()
	
	# Spauzuj wszystkie zarejestrowane komponenty
	for comp_data in pausable_components:
		pause_component(comp_data.component, comp_data.name)
	
	game_paused.emit()
	print("Gra spauzowana przez PauseSystem")

# Główna funkcja wznawiania
func resume_game():
	if not is_game_paused:
		return
		
	is_game_paused = false
	get_tree().paused = false
	
	if pause_menu:
		pause_menu.hide()
	
	# Wznów wszystkie zarejestrowane komponenty
	for comp_data in pausable_components:
		resume_component(comp_data.component, comp_data.name)
	
	game_resumed.emit()
	print("Gra wznowiona przez PauseSystem")

# Toggle pauzy
func toggle_pause():
	if is_game_paused:
		resume_game()
	else:
		pause_game()

# Pauzowanie konkretnego komponentu
func pause_component(component: Node, component_name: String):
	if not component:
		return
		
	match component_name:
		"beatslider":
			if component.has_method("pause"):
				component.pause()
				print("BeatSlider spauzowany")
		"beat_manager":
			if component.has_method("pause_track"):
				component.pause_track()
				print("BeatManager spauzowany")

# Wznawianie konkretnego komponentu
func resume_component(component: Node, component_name: String):
	if not component:
		return
		
	match component_name:
		"beatslider":
			if component.has_method("resume"):
				component.resume()
				print("BeatSlider wznowiony")
		"beat_manager":
			if component.has_method("resume_track"):
				component.resume_track()
				print("BeatManager wznowiony")

# Czyszczenie przed zmianą sceny
func cleanup_before_scene_change():
	print("PauseSystem: Czyszczenie przed zmianą sceny")
	
	# Zatrzymaj wszystkie komponenty całkowicie
	for comp_data in pausable_components:
		stop_component_completely(comp_data.component, comp_data.name)
	
	# Reset stanu
	is_game_paused = false
	get_tree().paused = false
	current_level = null
	pause_menu = null
	pausable_components.clear()

# Całkowite zatrzymanie komponentu (dla zmiany sceny)
func stop_component_completely(component: Node, component_name: String):
	if not component:
		return
		
	match component_name:
		"beatslider":
			if component.has_method("stop"):
				component.stop()
			elif component.has_method("reset"):
				component.reset()
			component.visible = false
			print("BeatSlider zatrzymany całkowicie")
		"beat_manager":
			if component.has_method("stop_track"):
				component.stop_track()
				print("BeatManager zatrzymany całkowicie")
			elif component.has_method("reset"):
				component.reset()
				print("BeatManager zresetowany")

# Wyrejestrowywanie levelu
func unregister_level():
	current_level = null
	pause_menu = null
	pausable_components.clear()
	is_game_paused = false
