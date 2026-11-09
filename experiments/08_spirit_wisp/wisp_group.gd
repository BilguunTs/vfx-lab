extends Node3D
## A group of spirit wisps that acts as one layer: forwards pulses, strength, variation, debug
## and reset to every child wisp. Lets the drum strike treat "the spirits" as one layer (one
## mute key) while each wisp keeps its own temperament (exported settings per child).

func add_push(source: Node3D) -> void:
	for wisp in _wisps():
		wisp.add_push(source)


func set_strength(value: float) -> void:
	for wisp in _wisps():
		wisp.set_strength(value)


func set_variation(index: int) -> void:
	for wisp in _wisps():
		wisp.set_variation(index)


func set_debug(enabled: bool) -> void:
	for wisp in _wisps():
		wisp.set_debug(enabled)


func reset() -> void:
	for wisp in _wisps():
		wisp.reset()


func is_active() -> bool:
	return true


func get_debug_text() -> String:
	var lines := PackedStringArray()
	for wisp in _wisps():
		lines.append(wisp.get_debug_text())
	return "\n".join(lines)


func _wisps() -> Array[Node]:
	return get_children().filter(func(child: Node) -> bool: return child.has_method("startle"))
