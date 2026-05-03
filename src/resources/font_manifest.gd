@tool
class_name FontManifest
extends Resource

@export var presets: Array[Resource] = []


func font_presets() -> Array[FontPreset]:
	var out: Array[FontPreset] = []
	for entry: Resource in presets:
		if entry is FontPreset:
			out.append(entry as FontPreset)
	return out


func find_by_id(preset_id: String) -> FontPreset:
	if preset_id == "":
		return null
	for entry: Resource in presets:
		if entry is FontPreset and (entry as FontPreset).id == preset_id:
			return entry as FontPreset
	return null


func default_preset() -> FontPreset:
	var list: Array[FontPreset] = font_presets()
	if list.is_empty():
		return null
	return list[0]
