extends Node

const SIDE_LEVEL := preload("res://scripts/neighborhood.gd")
const FRONT_LEVEL := preload("res://scripts/front_load_level.gd")
const TRUCK_PICTURE := preload("res://scripts/menu_truck.gd")

var _screen: Node
var _front_selected := false
var _side_button: Button
var _front_button: Button


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if "--smoke-menu" in args:
		_show_menu()
		_test_navigation.call_deferred()
		return
	if "--capture-menu" in args:
		_show_menu()
		_capture_menu.call_deferred()
		return
	# Existing command-line checks and captures still open their original route.
	for argument in args:
		if argument.begins_with("--smoke-") or argument.begins_with("--capture-") or argument == "--front-level":
			_start_level("--smoke-front-route" in args or "--capture-front" in args or "--front-level" in args)
			return
	_show_menu()


func _clear_screen() -> void:
	if is_instance_valid(_screen):
		remove_child(_screen)
		_screen.queue_free()


func _start_level(front: bool) -> void:
	_clear_screen()
	_front_selected = front
	_screen = FRONT_LEVEL.new() if front else SIDE_LEVEL.new()
	_screen.restart_requested.connect(_restart_level, CONNECT_DEFERRED)
	_screen.menu_requested.connect(_show_menu, CONNECT_DEFERRED)
	add_child(_screen)


func _restart_level() -> void:
	_start_level(_front_selected)


func _show_menu() -> void:
	_clear_screen()
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen = root
	add_child(root)
	var background := ColorRect.new()
	background.color = Color("#e8f3ee")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	center.add_child(layout)
	_label(layout, "LET’S MAKE THE TOWN SHINE", 17, Color("#3e7867"))
	_label(layout, "Little Clean Crew", 54, Color("#173c38"))
	_label(layout, "Choose your truck. A fresh route is waiting!", 22, Color("#52716a"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	layout.add_child(cards)
	_side_button = _route_card(cards, false, "SIDE LOADER", "Neighborhood", "Cruise the street and empty 6 blue cans.", "Stop beside a can — the arm does the rest.", Color("#dceef9"))
	_front_button = _route_card(cards, true, "FRONT LOADER", "Market Lane", "Visit the shops and empty 3 big dumpsters.", "Line up the forks, then lift over the cab!", Color("#f9eac7"))
	_label(layout, "Mouse to choose  ·  Arrows / D-pad to select  ·  Enter / A to play", 17, Color("#52716a"))
	_label(layout, "In a route: WASD / arrows drive · Space stops · Esc chooses a level", 16, Color("#52716a"))
	_front_button.focus_neighbor_left = _front_button.get_path_to(_side_button)
	_side_button.focus_neighbor_right = _side_button.get_path_to(_front_button)
	(_front_button if _front_selected else _side_button).grab_focus()


func _route_card(parent: Control, front: bool, kind: String, title: String, description: String, hint: String, color: Color) -> Button:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(490.0, 388.0)
	var style := _style(Color.WHITE)
	style.content_margin_left = 24.0
	style.content_margin_right = 24.0
	style.content_margin_top = 18.0
	style.content_margin_bottom = 20.0
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	panel.add_child(column)
	var picture = TRUCK_PICTURE.new()
	picture.front_loader = front
	picture.backdrop = color
	picture.custom_minimum_size = Vector2(440.0, 146.0)
	column.add_child(picture)
	_label(column, kind, 15, Color("#3e7867"))
	_label(column, title, 29, Color("#173c38"))
	_label(column, description, 18, Color("#52716a"))
	_label(column, hint, 16, Color("#52716a"))
	var button := Button.new()
	button.text = "Play front loader" if front else "Play side loader"
	button.custom_minimum_size.y = 54.0
	button.add_theme_font_size_override("font_size", 21)
	button.add_theme_stylebox_override("normal", _style(Color("#216553")))
	button.add_theme_stylebox_override("hover", _style(Color("#2e8067")))
	button.add_theme_stylebox_override("pressed", _style(Color("#173c38")))
	var focus := _style(Color(0, 0, 0, 0))
	focus.set_border_width_all(4)
	focus.border_color = Color("#edb53e")
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(_start_level.bind(front), CONNECT_DEFERRED)
	column.add_child(button)
	return button


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(18)
	return style


func _label(parent: Control, text: String, size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)


func _capture_menu() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://renders/level_selection.png")
	get_tree().quit()


func _test_navigation() -> void:
	await get_tree().process_frame
	if not _test_expect(_screen is Control and _side_button.has_focus(), "Opening screen did not focus the side loader choice"):
		return
	_send_key(KEY_ENTER)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_expect(_screen.get_script() == SIDE_LEVEL, "Side loader choice did not open the neighborhood"):
		return
	if not _test_expect(get_tree().get_nodes_in_group("collectible_cans").size() == 6, "Neighborhood did not contain six cans"):
		return
	_send_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_expect(_screen is Control, "Escape did not return to level selection"):
		return
	_send_key(KEY_RIGHT)
	await get_tree().process_frame
	_send_key(KEY_ENTER)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_expect(_screen.get_script() == FRONT_LEVEL, "Front loader route was not active"):
		return
	if not _test_expect(get_tree().get_nodes_in_group("collectible_cans").is_empty(), "Residential cans survived a level change"):
		return
	if not _test_expect(get_tree().get_nodes_in_group("collectible_dumpsters").size() == 3, "Expected three dumpsters in the front loader route"):
		return
	# B must remain available for reverse, not return to the menu.
	var reverse := InputEventJoypadButton.new()
	reverse.button_index = JOY_BUTTON_B
	reverse.pressed = true
	Input.parse_input_event(reverse)
	await get_tree().process_frame
	if not _test_expect(_screen.get_script() == FRONT_LEVEL, "Front loader route was not active"):
		return
	reverse = InputEventJoypadButton.new()
	reverse.button_index = JOY_BUTTON_B
	Input.parse_input_event(reverse)
	# Complete a pickup before restarting, so the reset has state to clear.
	Engine.time_scale = 6.0
	_screen._player_truck.position.x = 28.6
	var deadline := Time.get_ticks_msec() + 8000
	while _screen._side_loader.collected_count == 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _test_expect(_screen._side_loader.collected_count == 1, "Pickup did not complete before the restart check"):
		return
	_send_key(KEY_R)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_expect(_screen.get_script() == FRONT_LEVEL and _screen._side_loader.collected_count == 0, "Restart did not reset the current route"):
		return
	if not _test_expect(get_tree().get_nodes_in_group("collectible_dumpsters").size() == 3, "Expected three dumpsters in the front loader route"):
		return
	# Returning to the menu must also work while a dumpster is on the forks.
	_screen._player_truck.position.x = 28.6
	deadline = Time.get_ticks_msec() + 8000
	while _screen._side_loader.current_phase != "lifting" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	if not _test_expect(_screen._side_loader.current_phase == "lifting", "Pickup did not reach the overhead lift"):
		return
	_send_key(KEY_ESCAPE)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_expect(_front_button.has_focus(), "Returning to the menu did not retain the selected level"):
		return
	if not _test_expect(get_tree().get_nodes_in_group("collectible_dumpsters").is_empty(), "Dumpsters survived returning to the menu"):
		return
	Engine.time_scale = 1.0
	# Give the audio mixer time to release removed route playbacks.
	await get_tree().create_timer(0.25).timeout
	print("Menu passed: both route choices, return to menu, front route restart, and clean scene transitions.")
	get_tree().quit()


func _send_key(key: Key) -> void:
	var press := InputEventKey.new()
	press.keycode = key
	press.pressed = true
	Input.parse_input_event(press)
	var release := InputEventKey.new()
	release.keycode = key
	Input.parse_input_event(release)


func _test_expect(condition: bool, message: String) -> bool:
	if not condition:
		push_error("Menu check failed: " + message)
		get_tree().quit(1)
	return condition
