@tool
class_name FontPreset
extends Resource

const VARIANT_REGULAR: String = "regular"
const VARIANT_BOLD: String = "bold"
const VARIANT_ITALIC: String = "italic"
const VARIANT_BOLD_ITALIC: String = "bold_italic"
const VARIANT_MONO: String = "mono"

@export var id: String = ""
@export var display_name: String = ""
@export var font: Font = null
@export var bold_font: Font = null
@export var italic_font: Font = null
@export var bold_italic_font: Font = null
@export var mono_font: Font = null


func font_for_variant(variant: String) -> Font:
	match variant:
		VARIANT_BOLD:
			return bold_font
		VARIANT_ITALIC:
			return italic_font
		VARIANT_BOLD_ITALIC:
			return bold_italic_font
		VARIANT_MONO:
			return mono_font
		_:
			return font


func has_variant(variant: String) -> bool:
	return font_for_variant(variant) != null
