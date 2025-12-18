extends Control

var game: Node

func _ready() -> void:
	game = get_parent().get_parent()

func _draw() -> void:
	if game.dragging:
		var r: Rect2 = game._drag_rect_local()
		draw_rect(r, Color(1,1,1,0.15), true)
		draw_rect(r, Color(1,1,1,0.8), false, 2.0)
