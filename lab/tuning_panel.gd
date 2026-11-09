extends PanelContainer
## Live tuning panel: one slider per exported numeric property (with a range hint) of a layer.
## Works with any effect that offers get_tunable_layers(), get_tunable(name) and
## set_tuning(name, property, value). Toggled with Tab in the lab.
##
## Releasing a slider emits `committed` (the lab strikes, so each change is seen at once).
## Print writes the tuned values to the output in .tscn syntax, ready to paste into the scene.

signal committed

var effect: Node

var _layer_select := OptionButton.new()
var _rows := VBoxContainer.new()
var _layer := ""
var _defaults := {} # layer name -> {property: value} as they were before any tuning


func _ready() -> void:
	custom_minimum_size = Vector2(340, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := VBoxContainer.new()
	add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	_layer_select.focus_mode = Control.FOCUS_NONE
	_layer_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_layer_select.item_selected.connect(func(i: int): _show_layer(_layer_select.get_item_text(i)))
	header.add_child(_layer_select)
	for button_def in [["Reset", _reset_layer], ["Print", _print_layer]]:
		var button := Button.new()
		button.text = button_def[0]
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(button_def[1])
		header.add_child(button)
	box.add_child(_rows)

	var names: PackedStringArray = effect.get_tunable_layers()
	for layer_name in names:
		_layer_select.add_item(layer_name)
	var start := names.find("Shockwave")
	_layer_select.select(maxi(start, 0))
	_show_layer(names[maxi(start, 0)])


func _show_layer(layer_name: String) -> void:
	_layer = layer_name
	for child in _rows.get_children():
		child.queue_free()
	var target: Object = effect.get_tunable(layer_name)
	if not target:
		return
	var properties := _tunable_properties(target)
	if not _defaults.has(layer_name):
		var values := {}
		for p in properties:
			values[p.name] = target.get(p.name)
		_defaults[layer_name] = values
	for p in properties:
		_rows.add_child(_make_row(target, p))


## Script-exported int/float properties with a range hint.
func _tunable_properties(target: Object) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in target.get_property_list():
		var exported: bool = p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and p.usage & PROPERTY_USAGE_EDITOR
		if exported and p.type in [TYPE_FLOAT, TYPE_INT] and p.hint == PROPERTY_HINT_RANGE:
			result.append(p)
	return result


func _make_row(target: Object, p: Dictionary) -> Control:
	var parts: PackedStringArray = p.hint_string.split(",")
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = p.name
	label.custom_minimum_size.x = 150
	label.add_theme_font_size_override("font_size", 13)
	var slider := HSlider.new()
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.min_value = float(parts[0])
	slider.max_value = float(parts[1])
	slider.step = float(parts[2]) if parts.size() > 2 and parts[2].is_valid_float() else 0.001
	slider.value = target.get(p.name)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 52
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.text = _format(slider.value, p.type)
	var property: String = p.name
	var type: int = p.type
	slider.value_changed.connect(func(v: float):
		value_label.text = _format(v, type)
		effect.set_tuning(_layer, property, int(v) if type == TYPE_INT else v))
	slider.drag_ended.connect(func(_changed: bool): committed.emit())
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	return row


func _reset_layer() -> void:
	var values: Dictionary = _defaults.get(_layer, {})
	for property in values:
		effect.set_tuning(_layer, property, values[property])
	_show_layer(_layer)
	committed.emit()


## Prints the values that differ from the scene's, as lines to paste under the layer's node.
func _print_layer() -> void:
	var target: Object = effect.get_tunable(_layer)
	var lines := PackedStringArray(["[%s] tuned values:" % _layer])
	var values: Dictionary = _defaults.get(_layer, {})
	for property in values:
		var v = target.get(property)
		if not is_equal_approx(float(v), float(values[property])):
			lines.append("%s = %s" % [property, var_to_str(v)])
	if lines.size() == 1:
		lines.append("(no changes)")
	print("\n".join(lines))


func _format(v: float, type: int) -> String:
	return str(int(v)) if type == TYPE_INT else "%.3f" % v
