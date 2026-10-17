extends Control

## Small vector illustrations keep the opening screen crisp at every size.
var front_loader := false
var backdrop := Color.WHITE


func _draw() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = backdrop
	background.set_corner_radius_all(12)
	draw_style_box(background, Rect2(Vector2.ZERO, size))
	var ink := Color("#254c47")
	var gold := Color("#eba737")
	draw_line(Vector2(26, 124), Vector2(414, 124), Color("#a8c4b8"), 3, true)
	draw_style_box(_rounded(Color("#4c9d6d")), Rect2(164, 36, 176, 74))
	draw_style_box(_rounded(Color("#76bd7a")), Rect2(99, 55, 69, 55))
	draw_style_box(_rounded(Color("#d5edf0")), Rect2(108, 63, 38, 24))
	draw_rect(Rect2(169, 86, 165, 9), gold)
	draw_rect(Rect2(93, 103, 249, 10), ink)
	for x: float in [125.0, 284.0, 316.0]:
		draw_circle(Vector2(x, 114), 15, ink)
		draw_circle(Vector2(x, 114), 7, Color("#cedbd5"))
	if front_loader:
		draw_polyline(PackedVector2Array([Vector2(184, 60), Vector2(80, 32), Vector2(52, 94)]), gold, 9, true)
		draw_line(Vector2(40, 96), Vector2(84, 96), ink, 5, true)
		draw_style_box(_rounded(Color("#268a70")), Rect2(29, 81, 48, 34))
		draw_rect(Rect2(26, 77, 54, 7), ink)
		draw_line(Vector2(33, 99), Vector2(73, 99), gold, 4, true)
	else:
		draw_polyline(PackedVector2Array([Vector2(218, 80), Vector2(244, 48), Vector2(364, 86)]), gold, 9, true)
		draw_style_box(_rounded(Color("#459ed1")), Rect2(351, 83, 29, 34))
		draw_rect(Rect2(348, 79, 35, 7), ink)
		draw_line(Vector2(350, 97), Vector2(382, 97), gold, 5, true)
	draw_circle(Vector2(114, 50), 5, gold)


func _rounded(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(5)
	return style
