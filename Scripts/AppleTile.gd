extends Panel
class_name AppleTile

@onready var number_label: Label = $Number
@onready var apple_image: TextureRect = $AppleImage

@export var normal_tex: Texture2D
@export var golden_tex: Texture2D

var value: int = 1
var is_golden: bool = false

func setup(v: int) -> void:
	value = v
	if not is_node_ready():
		await ready
	number_label.text = str(value)
	

func set_golden(on: bool) -> void:
	is_golden = on
	if not is_node_ready():
		await ready
	apple_image.texture = golden_tex if on else normal_tex

func get_points() -> int:
	return 3 if is_golden else 1

func set_highlight(on: bool) -> void:
	modulate.a = 0.65 if on else 1.0

func play_regrow_anim() -> void:
	scale = Vector2(0.15, 0.15)
	modulate.a = 0.0

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)
