extends Node

var music_on: bool = true
var sfx_on: bool = true

func apply_audio() -> void:
	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_mute(music_idx, not music_on)

	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_mute(sfx_idx, not sfx_on)
