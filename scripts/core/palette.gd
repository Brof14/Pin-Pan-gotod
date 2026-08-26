class_name PinPanPalette
extends RefCounted

const VOID := Color("0a0a0e")
const VOID_LIFTED := Color("15151d")
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
const ERROR := Color("d77a70")
const DANGER := Color("bf6571")

const PIN_BASE := Color("d95555")
const PIN_DEEP := Color("7d252f")
const PIN_GLOW := Color("ff8a72")
const PAN_BASE := Color("5e8fd8")
const PAN_DEEP := Color("263f78")
const PAN_GLOW := Color("90c8ff")

const PRESETS := {
	"BASE": {"pin": Color("d95555"), "pan": Color("5e8fd8")},
	"PROTANOPIA": {"pin": Color("b66a42"), "pan": Color("287bb5")},
	"DEUTERANOPIA": {"pin": Color("c05a3d"), "pan": Color("347ebb")},
	"TRITANOPIA": {"pin": Color("c94787"), "pan": Color("278c78")},
}

static func pin_color(preset: String) -> Color:
	return PRESETS.get(preset, PRESETS.BASE).pin

static func pan_color(preset: String) -> Color:
	return PRESETS.get(preset, PRESETS.BASE).pan
