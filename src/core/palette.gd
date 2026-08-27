class_name PinPanPalette
extends RefCounted
## Единая палитра PIN&PAN: цвета мира, ролей и пресеты для нарушений цветовосприятия.
## Цвет — не единственный канал: роли дублируются символом (settings.symbols) и звуком.

const VOID := Color("0a0a0e")
const DEEP := Color("15151d")
const LOOM := Color("292832")
const FABRIC := Color("37333e")
const LINEN := Color("90785c")
const LINEN_LIGHT := Color("d2b98c")
const WOOL := Color("384354")
const WOOL_LIGHT := Color("68758c")
const WARM := Color("e3c69a")
const UI := Color("e8e4da")
const MUTED := Color("8a8790")
const FOCUS := Color("f4d7a1")
const DANGER := Color("bf6571")

const _PRESETS := {
	"BASE": {"pin": Color("d95555"), "pan": Color("5e8fd8")},
	"PROTANOPIA": {"pin": Color("e39b3d"), "pan": Color("5e9fd8")},
	"DEUTERANOPIA": {"pin": Color("f2c14e"), "pan": Color("8b8bd8")},
	"TRITANOPIA": {"pin": Color("d95570"), "pan": Color("3fb8b0")},
}


## Возвращает пару ролей: pin / pin_deep / pin_glow, pan / pan_deep / pan_glow.
static func role_pair(preset: String) -> Dictionary:
	var base: Dictionary = _PRESETS.get(preset, _PRESETS["BASE"])
	var pin: Color = base["pin"]
	var pan: Color = base["pan"]
	return {
		"pin": pin,
		"pin_deep": pin.darkened(0.55),
		"pin_glow": pin.lerp(Color("ffe0c0"), 0.45),
		"pan": pan,
		"pan_deep": pan.darkened(0.55),
		"pan_glow": pan.lerp(Color("d8ecff"), 0.45),
	}
