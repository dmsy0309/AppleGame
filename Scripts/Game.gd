extends Control

@export var cols := 18 #가로줄
@export var rows := 9 #세로줄
@export var target_sum := 10
@export var regrow_delay := 8 #사과 재생성 시간
@export var game_duration := 120.0 #게임 시간

@export var tile_scene: PackedScene

@onready var grid: GridContainer = $VBoxContainer/BoardRoot/BoardCenter/Grid
@onready var drag_layer: Control = $VBoxContainer/BoardRoot/DragLayer
@onready var score_label: Label = $Apples/ScoreLabel
@onready var time_label: Label = $TimeLabel
@onready var back_button: Button = $BackButton
@onready var game_timer: Timer = $GameTimer
@onready var time_bar: ProgressBar = $TimeBar
@onready var bgm: AudioStreamPlayer2D = $BGMPlayer
@onready var effects_layer: Control = $VBoxContainer/BoardRoot/EffectsLayer

@onready var result_overlay: Control = $VBoxContainer/BoardRoot/ResultOverlay
@onready var final_score_label: Label = $VBoxContainer/BoardRoot/ResultOverlay/ResultPanel/VBoxContainer/FinalScoreLabel
@onready var result_back_button: Button = $VBoxContainer/BoardRoot/ResultOverlay/ResultPanel/VBoxContainer/BackButton
@onready var result_panel: Control = $VBoxContainer/BoardRoot/ResultOverlay/ResultPanel
@onready var se_player: AudioStreamPlayer2D = $SEPlayer

var rng := RandomNumberGenerator.new()

var low_time_fx_started := false
var low_time_tween: Tween

var score := 0
var remaining := 0.0
var game_over := false

# 슬롯(칸)들
var slots: Array[Control] = []              # size = cols*rows
var regrow_pending := {}                    # Dictionary: slot_index -> true

# 드래그 상태
var dragging := false
var drag_start := Vector2.ZERO
var drag_end := Vector2.ZERO
var highlighted: Array[int] = []            # 현재 드래그 박스에 포함된 slot indices

func _ready() -> void:
	rng.randomize()

	# 그리드 설정
	grid.columns = cols

	drag_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	drag_layer.gui_input.connect(_on_drag_gui_input)

	back_button.pressed.connect(_go_menu)

	game_timer.one_shot = true
	game_timer.timeout.connect(_on_time_up)
	
	result_overlay.visible = false
	result_back_button.pressed.connect(_go_menu)

	_start_game()

func _process(delta: float) -> void:
	if game_over:
		return
	remaining = maxf(0.0, remaining - delta)
	time_label.text = "%.1f" % remaining
	time_bar.value = remaining
	if not low_time_fx_started and remaining <= 10.0 and not game_over:
		_start_low_time_fx()

func _start_game() -> void:
	game_over = false
	score = 0
	remaining = game_duration
	regrow_pending.clear()
	_clear_board()
	_build_slots(cols * rows)
	_fill_all_slots()

	score_label.text = "0"
	time_label.text = "%.1f" % remaining
	
	time_bar.min_value = 0
	time_bar.max_value = game_duration
	time_bar.value = game_duration
	
	low_time_fx_started = false
	if low_time_tween:
		low_time_tween.kill()
	low_time_tween = null
	
	bgm.play()
	
	time_bar.modulate = Color(1,1,1,1)

	game_timer.start(game_duration)

func _on_time_up() -> void:
	game_over = true
	bgm.stop()
	if low_time_tween:
		low_time_tween.kill()
	time_bar.modulate = Color(1, 1, 1, 1)
	_clear_highlight()
	time_label.text = "0.0"
	_show_result_popup()

func _go_menu() -> void:
	bgm.stop()
	get_tree().change_scene_to_file("res://Scenes/StartMenu.tscn")

# ----------------------------
# 보드(슬롯/타일) 관리
# ----------------------------

func _clear_board() -> void:
	slots.clear()
	for c in grid.get_children():
		c.queue_free()

func _build_slots(count: int) -> void:
	for i in count:
		var slot := Control.new()
		slot.custom_minimum_size = Vector2(40, 40)
		grid.add_child(slot)
		slots.append(slot)

func _fill_all_slots() -> void:
	for i in slots.size():
		_plant_tile(i, false)

func _plant_tile(slot_index: int, animate := false) -> void:
	if game_over:
		return
	var slot := slots[slot_index]
	if slot.get_child_count() > 0:
		return

	var t := tile_scene.instantiate() as AppleTile
	slot.add_child(t)
	t.setup(rng.randi_range(1, 9))
	
	t.set_golden(rng.randf() < 0.15)

	t.anchor_left = 0; t.anchor_top = 0; t.anchor_right = 1; t.anchor_bottom = 1
	t.offset_left = 0; t.offset_top = 0; t.offset_right = 0; t.offset_bottom = 0

	if animate:
		t.play_regrow_anim()

func _remove_tile(slot_index: int) -> void:
	var slot := slots[slot_index]
	if slot.get_child_count() == 0:
		return
	var t := slot.get_child(0)
	t.queue_free()

func _schedule_regrow(slot_index: int) -> void:
	if regrow_pending.has(slot_index):
		return
	regrow_pending[slot_index] = true

	_regrow_after_delay(slot_index)

func _regrow_after_delay(slot_index: int) -> void:
	await get_tree().create_timer(regrow_delay).timeout
	regrow_pending.erase(slot_index)
	if game_over:
		return
	_plant_tile(slot_index, true)

# ----------------------------
# 드래그 입력/선택/합 판정
# ----------------------------

func _on_drag_gui_input(event: InputEvent) -> void:
	if game_over:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				dragging = true
				drag_start = mb.position
				drag_end = mb.position
				_update_drag_selection()
			else:
				dragging = false
				_finalize_drag()

	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		drag_end = mm.position
		_update_drag_selection()

#func _drag_rect_local() -> Rect2:
	#var pos := Vector2(minf(drag_start.x, drag_end.x), minf(drag_start.y, drag_end.y))
	#var size := Vector2(absf(drag_end.x - drag_start.x), absf(drag_end.y - drag_start.y))
	#return Rect2(pos, size)
	
func _drag_rect_local() -> Rect2:
	var pos := Vector2(minf(drag_start.x, drag_end.x), minf(drag_start.y, drag_end.y))
	var size := Vector2(absf(drag_end.x - drag_start.x), absf(drag_end.y - drag_start.y))

	# ✅ 최소 드래그 크기 보장 (0이면 어떤 타일도 intersects가 안 될 수 있음)
	var min_drag := 2.0
	size.x = maxf(size.x, min_drag)
	size.y = maxf(size.y, min_drag)

	return Rect2(pos, size)

func _update_drag_selection() -> void:
	# 1) 드래그 박스
	drag_layer.queue_redraw()

	# 2) 어떤 슬롯이 드래그 박스에 들어왔는지 계산
	_clear_highlight()

	var r := _drag_rect_local()
	var r_global := Rect2(drag_layer.global_position + r.position, r.size)

	for i in slots.size():
		var slot := slots[i]
		if slot.get_child_count() == 0: # 빈 칸 제외
			continue
		var slot_rect := slot.get_global_rect()
		if slot_rect.intersects(r_global):
			highlighted.append(i)
			var tile := slot.get_child(0) as AppleTile
			tile.set_highlight(true)

func _finalize_drag() -> void:
	if highlighted.is_empty():
		return

	var sum := 0
	for idx in highlighted:
		var slot := slots[idx]
		if slot.get_child_count() == 0:
			continue
		var tile := slot.get_child(0) as AppleTile
		sum += tile.value

	if sum == target_sum:
		var gained := 0
		for idx in highlighted:
			var slot := slots[idx]
			if slot.get_child_count() == 0:
				continue
			var tile := slot.get_child(0) as AppleTile
			gained += tile.get_points()
			_drop_and_free(tile) 
			_schedule_regrow(idx)
		score += gained
		score_label.text = "%d" % score
		se_player.play()

	_clear_highlight()
	drag_layer.queue_redraw()

func _clear_highlight() -> void:
	for idx in highlighted:
		var slot := slots[idx]
		if slot.get_child_count() > 0:
			var tile := slot.get_child(0) as AppleTile
			tile.set_highlight(false)
	highlighted.clear()

func _start_low_time_fx() -> void:
	low_time_fx_started = true

	var fill := time_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill:
		var new_fill := fill.duplicate() as StyleBoxFlat
		new_fill.bg_color = Color(1.0, 0.25, 0.25, 1.0)
		time_bar.add_theme_stylebox_override("fill", new_fill)

	low_time_tween = time_bar.create_tween()
	low_time_tween.set_loops()
	low_time_tween.tween_property(time_bar, "modulate:a", 0.35, 0.25)
	low_time_tween.tween_property(time_bar, "modulate:a", 1.0, 0.25)

func _drop_and_free(tile: AppleTile) -> void:
	var gpos: Vector2 = tile.global_position
	var gsize: Vector2 = tile.size

	var old_parent := tile.get_parent()
	old_parent.remove_child(tile)
	effects_layer.add_child(tile)

	tile.anchor_left = 0
	tile.anchor_top = 0
	tile.anchor_right = 0
	tile.anchor_bottom = 0
	tile.offset_left = 0
	tile.offset_top = 0
	tile.offset_right = 0
	tile.offset_bottom = 0

	tile.global_position = gpos
	tile.size = gsize

	tile.pivot_offset = tile.size * 0.5

	tile.rotation = deg_to_rad(rng.randf_range(-25.0, 25.0))

	# ---------
	# 파라미터
	# ---------
	var pop_up := rng.randf_range(18.0, 34.0)           # 위로 튀는 높이
	var duration_pop := 0.07                            # 팝 시간
	var duration_fall := 0.22                           # 낙하 시간

	var drop_y := rng.randf_range(220.0, 300.0)         # 총 낙하 거리
	var side_dir := -1.0 if rng.randf() < 0.5 else 1.0
	var curve_x := rng.randf_range(90.0, 170.0) * side_dir

	# 시작/팝/중간/끝 포인트
	var p0 := tile.global_position
	var p_pop := p0 + Vector2(0.0, -pop_up)             # 위로 살짝
	var p1 := p0 + Vector2(curve_x * 0.55, drop_y * 0.35)  # 곡선 중간
	var p2 := p0 + Vector2(curve_x, drop_y)             # 최종

	var tween := tile.create_tween()

	# 0
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "global_position", p_pop, duration_pop)

	# 1
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(tile, "global_position", p1, duration_fall * 0.45)

	# 2
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(tile, "global_position", p2, duration_fall * 0.55)

	tween.finished.connect(tile.queue_free)

func _show_result_popup() -> void:
	final_score_label.text = "%d" % score
	result_overlay.visible = true

	result_panel.scale = Vector2(0.9, 0.9)
	result_panel.modulate.a = 0.0

	var t := result_panel.create_tween()
	t.set_trans(Tween.TRANS_SINE)
	t.set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(result_panel, "scale", Vector2(1, 1), 0.18)
	t.parallel().tween_property(result_panel, "modulate:a", 1.0, 0.18)
