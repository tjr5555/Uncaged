class_name UiTheme
extends RefCounted

const FONT_PATH = "res://fonts/Elms_Sans/ElmsSans-Regular.ttf"
const PANEL_COLOR = Color(0.07, 0.1, 0.17, 0.97)
const PANEL_BORDER = Color(1.0, 1.0, 1.0, 0.08)
const ACCENT = Color(0.45, 0.72, 1.0)
const TEXT = Color(0.93, 0.95, 1.0)
const TEXT_DIM = Color(0.64, 0.7, 0.8)


static func build() -> Theme:
	var t := Theme.new()
	if FONT_PATH != "" and ResourceLoader.exists(FONT_PATH):
		t.default_font = load(FONT_PATH)
	t.default_font_size = 26

	t.set_stylebox("panel", "PanelContainer", _box(PANEL_COLOR, 22, 1, PANEL_BORDER, Vector2.ZERO))
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		t.set_constant(side, "MarginContainer", 40)

	t.set_color("font_color", "Label", TEXT)
	t.set_type_variation("HeaderLarge", "Label")
	t.set_font_size("font_size", "HeaderLarge", 52)
	t.set_color("font_color", "HeaderLarge", TEXT)
	t.set_type_variation("DimLabel", "Label")
	t.set_font_size("font_size", "DimLabel", 22)
	t.set_color("font_color", "DimLabel", TEXT_DIM)

	var pad := Vector2(28, 14)
	t.set_stylebox("normal", "Button", _box(Color(1, 1, 1, 0.06), 12, 0, Color.TRANSPARENT, pad))
	t.set_stylebox("hover", "Button", _box(Color(1, 1, 1, 0.12), 12, 0, Color.TRANSPARENT, pad))
	t.set_stylebox("pressed", "Button", _box(ACCENT.darkened(0.35), 12, 0, Color.TRANSPARENT, pad))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), 12, 2, ACCENT, pad))
	t.set_stylebox("disabled", "Button", _box(Color(1, 1, 1, 0.03), 12, 0, Color.TRANSPARENT, pad))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(key, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_DIM)

	var check_pad := Vector2(6, 4)
	t.set_stylebox("normal", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("pressed", "CheckButton", StyleBoxEmpty.new())
	t.set_stylebox("hover", "CheckButton", _box(Color(1, 1, 1, 0.05), 10, 0, Color.TRANSPARENT, check_pad))
	t.set_stylebox("hover_pressed", "CheckButton", _box(Color(1, 1, 1, 0.05), 10, 0, Color.TRANSPARENT, check_pad))
	t.set_stylebox("focus", "CheckButton", _box(Color(0, 0, 0, 0), 10, 2, ACCENT, check_pad))
	t.set_icon("checked", "CheckButton", _switch(true, 1.0))
	t.set_icon("unchecked", "CheckButton", _switch(false, 1.0))
	t.set_icon("checked_disabled", "CheckButton", _switch(true, 0.4))
	t.set_icon("unchecked_disabled", "CheckButton", _switch(false, 0.4))

	t.set_stylebox("slider", "HSlider", _track(Color(1, 1, 1, 0.14)))
	t.set_stylebox("grabber_area", "HSlider", _track(ACCENT))
	t.set_stylebox("grabber_area_highlight", "HSlider", _track(ACCENT.lightened(0.15)))
	t.set_icon("grabber", "HSlider", _circle(28, TEXT))
	t.set_icon("grabber_highlight", "HSlider", _circle(30, Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", _circle(28, TEXT_DIM))

	var tab_pad := Vector2(28, 12)
	t.set_stylebox("panel", "TabContainer", _box(Color(1, 1, 1, 0.03), 14, 0, Color.TRANSPARENT, Vector2(32, 28)))
	var tab_selected := _box(Color(1, 1, 1, 0.1), 12, 0, Color.TRANSPARENT, tab_pad)
	tab_selected.corner_radius_bottom_left = 0
	tab_selected.corner_radius_bottom_right = 0
	t.set_stylebox("tab_selected", "TabContainer", tab_selected)
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color(0, 0, 0, 0), 12, 0, Color.TRANSPARENT, tab_pad))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color(1, 1, 1, 0.05), 12, 0, Color.TRANSPARENT, tab_pad))
	t.set_color("font_selected_color", "TabContainer", TEXT)
	t.set_color("font_unselected_color", "TabContainer", TEXT_DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)

	t.set_constant("h_separation", "GridContainer", 32)
	t.set_constant("v_separation", "GridContainer", 22)
	t.set_constant("separation", "VBoxContainer", 20)
	t.set_constant("separation", "HBoxContainer", 16)
	var line := StyleBoxLine.new()
	line.color = Color(1, 1, 1, 0.08)
	line.thickness = 1
	t.set_stylebox("separator", "HSeparator", line)
	return t


static func _box(color: Color, radius: int, border: int, border_color: Color, margin: Vector2) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(radius)
	b.set_border_width_all(border)
	b.border_color = border_color
	b.content_margin_left = margin.x
	b.content_margin_right = margin.x
	b.content_margin_top = margin.y
	b.content_margin_bottom = margin.y
	return b


static func _track(color: Color) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = color
	b.set_corner_radius_all(5)
	b.content_margin_top = 4
	b.content_margin_bottom = 4
	return b


static func _circle(size: int, color: Color) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var r := size * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(color, color.a * clampf(r - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


static func _switch(on: bool, opacity: float) -> ImageTexture:
	var w := 64
	var h := 34
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var r := h * 0.5
	var track := ACCENT if on else Color(1, 1, 1, 0.2)
	var knob_x := w - r if on else r
	var knob_r := r - 4.0
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var track_a := clampf(r - p.distance_to(Vector2(clampf(p.x, r, w - r), r)), 0.0, 1.0)
			var knob_a := clampf(knob_r - p.distance_to(Vector2(knob_x, r)), 0.0, 1.0)
			var col := Color(track, track.a * track_a)
			col = col.blend(Color(1, 1, 1, knob_a))
			img.set_pixel(x, y, Color(col, col.a * opacity))
	return ImageTexture.create_from_image(img)
