extends Node3D
## Experiment 05 — Drum Strike: overlapping, layered strikes.
##
## Every play() spawns a new *voice* (an instance of voice_scene holding the short-lived
## layers: rings, dust, seal, motes) and lets it run to the end, so rapid strikes stack
## instead of cutting each other off. A voice frees itself once all its layers are idle.
##
## Persistent layers are this node's own children (the debris field): they exist once,
## and every new voice's pulse is handed to them with add_push().
##
## Strength, variation, muting and debug are kept here and applied to each new voice.
##
## Live tuning: voices are fresh instances, so a tweak to one would be lost on the next strike.
## Tweaks go through set_tuning() instead: they are recorded and applied to every new voice.
## get_tunable() returns a template instance (out of the tree) that shows the current values.

## How hard the drum is struck. 1 = as authored, 0.3 = a gentle tap, 2 = a violent blow.
## Each layer decides what strength means for it (see their set_strength()).
@export_range(0.1, 2.0, 0.05) var strength := 1.0
## Shifts every layer's random seed: the same strike with different details.
@export var variation := 0
## Scene with the per-strike layers. Its PulseRing (if present) is what pushes persistent layers.
@export var voice_scene: PackedScene

var _voices: Array[Node3D] = []
var _voice_layer_names := PackedStringArray()
var _muted := {} # voice layer name -> true
var _debug := false
var _template: Node3D              # voice instance kept out of the tree, holds tuned values
var _tuning := {}                  # voice layer name -> {property: value}


func _ready() -> void:
	_template = voice_scene.instantiate()
	var prototype := voice_scene.instantiate()
	for child in prototype.get_children():
		_voice_layer_names.append(child.name)
	# Keep the prototype in the tree for a couple of frames (all layers idle, nothing visible)
	# so the layers' shaders compile at load time instead of stalling the first strike.
	add_child(prototype)
	await get_tree().process_frame
	await get_tree().process_frame
	prototype.queue_free()


func _exit_tree() -> void:
	if _template:
		_template.free()
		_template = null


func play() -> void:
	var voice: Node3D = voice_scene.instantiate()
	add_child(voice)
	for layer in voice.get_children():
		if _muted.has(layer.name):
			layer.visible = false
			continue
		for property in _tuning.get(layer.name, {}):
			layer.set(property, _tuning[layer.name][property])
		_configure(layer)
		layer.play()
	_voices.append(voice)

	var pulse := voice.get_node_or_null("PulseRing")
	for layer in _persistent_layers():
		if not layer.visible:
			continue
		_configure(layer)
		layer.add_push(pulse if pulse and pulse.visible else null)


func reset() -> void:
	for voice in _voices:
		voice.queue_free()
	_voices.clear()
	for layer in _persistent_layers():
		layer.reset()


func set_debug(enabled: bool) -> void:
	_debug = enabled
	for voice in _voices:
		for layer in voice.get_children():
			layer.set_debug(enabled)
	for layer in _persistent_layers():
		layer.set_debug(enabled)


func get_debug_text() -> String:
	var lines := PackedStringArray(["voices playing: %d" % _voices.size()])
	if not _voices.is_empty():
		for layer in _voices.back().get_children():
			if layer.visible:
				lines.append("  newest " + layer.get_debug_text())
	for layer in _persistent_layers():
		lines.append(layer.get_debug_text())
	return "\n".join(lines)


func get_layer_status() -> String:
	var parts := PackedStringArray()
	var names := _all_layer_names()
	for i in names.size():
		parts.append("[%d] %s %s" % [i + 1, names[i], "MUTED" if _is_muted(i) else "on"])
	return "   ".join(parts)


## Muting a voice layer affects the next strikes; strikes already playing finish as they are.
func toggle_layer(index: int) -> void:
	if index < 0:
		return
	if index < _voice_layer_names.size():
		var layer_name := _voice_layer_names[index]
		if _muted.has(layer_name):
			_muted.erase(layer_name)
		else:
			_muted[layer_name] = true
		return
	var persistent := _persistent_layers()
	index -= _voice_layer_names.size()
	if index < persistent.size():
		persistent[index].visible = not persistent[index].visible
		persistent[index].reset()


## Layer names that can be tuned live (voice layers, then persistent ones). A persistent layer
## that groups others (e.g. Spirits) also lists its members as "Group/Member".
func get_tunable_layers() -> PackedStringArray:
	var names := _all_layer_names()
	for layer in _persistent_layers():
		for child in layer.get_children():
			if child.has_method("add_push"):
				names.append("%s/%s" % [layer.name, child.name])
	return names


## The object whose exported values the tuning panel shows: the template for a voice layer,
## the live node for a persistent one.
func get_tunable(layer_name: String) -> Object:
	if _voice_layer_names.has(layer_name):
		return _template.get_node(layer_name)
	var node := get_node_or_null(NodePath(layer_name))
	if node and node is Node3D and (node.has_method("add_push") or _persistent_layers().has(node)):
		return node
	return null


## Voice layers: applies from the next strike. Persistent layers: applies immediately.
func set_tuning(layer_name: String, property: String, value: Variant) -> void:
	var target := get_tunable(layer_name)
	if not target:
		return
	target.set(property, value)
	if _voice_layer_names.has(layer_name):
		if not _tuning.has(layer_name):
			_tuning[layer_name] = {}
		_tuning[layer_name][property] = value


func _process(_delta: float) -> void:
	# Free voices whose layers have all finished.
	for voice in _voices.duplicate():
		var active := false
		for layer in voice.get_children():
			if layer.visible and layer.is_active():
				active = true
				break
		if not active:
			_voices.erase(voice)
			voice.queue_free()


func _configure(layer: Node) -> void:
	if layer.has_method("set_strength"):
		layer.set_strength(strength)
	if layer.has_method("set_variation"):
		layer.set_variation(variation)
	if layer.has_method("set_debug"):
		layer.set_debug(_debug)


func _persistent_layers() -> Array[Node3D]:
	var layers: Array[Node3D] = []
	for child in get_children():
		if child is Node3D and child.has_method("add_push"):
			layers.append(child)
	return layers


func _all_layer_names() -> PackedStringArray:
	var names := _voice_layer_names.duplicate()
	for layer in _persistent_layers():
		names.append(layer.name)
	return names


func _is_muted(index: int) -> bool:
	if index < _voice_layer_names.size():
		return _muted.has(_voice_layer_names[index])
	return not _persistent_layers()[index - _voice_layer_names.size()].visible
