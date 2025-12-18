extends Control

@onready var information: Control = $Information
@onready var settings: Control = $Settings
@onready var music_check: CheckBox = $Settings/MusicCheck
@onready var sfx_check: CheckBox = $Settings/SfxCheck

func _ready() -> void:
	$VBoxContainer/StartButton.pressed.connect(_on_start)
	$VBoxContainer/InformationButton.pressed.connect(_on_information)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit)
	$Information/InformationCloseButton.pressed.connect(_on_close_information)
	$Settings/SettingsCloseButton.pressed.connect(_on_close_settings)

	music_check.button_pressed = Settings.music_on
	sfx_check.button_pressed = Settings.sfx_on
	music_check.toggled.connect(_on_music_toggled)
	sfx_check.toggled.connect(_on_sfx_toggled)

func _on_start() -> void:
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func _on_information() -> void:
	_open_information()

func _on_close_information() -> void:
	information.visible = false

func _on_settings() -> void:
	_open_settings()
	
func _on_music_toggled(on: bool) -> void:
	Settings.music_on = on
	Settings.apply_audio()
	
func _on_sfx_toggled(on: bool) -> void:
	Settings.sfx_on = on
	Settings.apply_audio()
	
func _on_close_settings() -> void:
	settings.visible = false
	
func _on_quit() -> void:
	get_tree().quit()
	
func _open_information() -> void:
	information.visible = true

	information.scale = Vector2(0.9, 0.9)
	information.modulate.a = 0.0

	var t := information.create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(information, "scale", Vector2(1, 1), 0.18)
	t.parallel().tween_property(information, "modulate:a", 1.0, 0.18)
	
func _open_settings() -> void:
	settings.visible = true
	
	settings.scale = Vector2(0.9, 0.9)
	settings.modulate.a = 0.0
	
	var t := settings.create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(settings, "scale", Vector2(1, 1), 0.18)
	t.parallel().tween_property(settings, "modulate:a", 1.0, 0.18)
