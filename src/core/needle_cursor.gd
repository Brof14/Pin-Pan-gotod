class_name NeedleCursor
extends RefCounted
## Курсор-игла: пружинная точка с хвостом-ниткой.
## Пружина: response 15 с⁻¹, демпфирование 0.30, максимум 1800 px/с, snap 18 px —
## при замедлении курсор «пришивается» к реальной позиции мыши.

const RESPONSE := 15.0
const DAMPING := 0.30
const MAX_SPEED := 1800.0
const SNAP_DISTANCE := 18.0
const BASE_RADIUS := 6.0

var position := Vector2.ZERO
var target := Vector2.ZERO
var hovered := false
var role_symbol := "" # "pin" / "pan" — маркер режима «символы»

var _velocity := Vector2.ZERO
var _hover_t := 0.0
var _pulse := -1.0
var _trail: Array[Vector2] = []


func reset(p: Vector2) -> void:
	position = p
	target = p
	_velocity = Vector2.ZERO
	_trail = [p]


func trigger_select() -> void:
	_pulse = 0.0


func process(delta: float) -> void:
	var accel := RESPONSE * RESPONSE * (target - position) - 2.0 * DAMPING * RESPONSE * _velocity
	_velocity += accel * delta
	if _velocity.length() > MAX_SPEED:
		_velocity = _velocity.normalized() * MAX_SPEED
	position += _velocity * delta
	if position.distance_to(target) < SNAP_DISTANCE and _velocity.length() < 500.0:
		position = position.lerp(target, minf(1.0, delta * 30.0))
	_hover_t = move_toward(_hover_t, 1.0 if hovered else 0.0, delta / 0.12)
	if _pulse >= 0.0:
		_pulse += delta
		if _pulse > 0.2:
			_pulse = -1.0
	_trail.push_front(position)
	if _trail.size() > 16:
		_trail.pop_back()


func radius() -> float:
	var r := BASE_RADIUS + _hover_t * 1.0
	if _pulse >= 0.0:
		r += sin(clampf(_pulse / 0.2, 0.0, 1.0) * PI) * 4.0
	return r


func tail_length() -> float:
	return lerpf(40.0, 70.0, _hover_t)


func draw_on(canvas: CanvasItem, color: Color, high_contrast: bool) -> void:
	var tail_count := clampi(int(tail_length() / 6.0), 4, _trail.size())
	for i in range(tail_count - 1):
		var k := float(i) / float(tail_count)
		var alpha := 0.55 * (1.0 - k)
		var width := 3.2 - 2.2 * k
		canvas.draw_line(_trail[i], _trail[i + 1], Color(color, alpha), width)
	var r := radius()
	canvas.draw_circle(position, r + 6.0, Color(color, 0.16))
	var core := color if not high_contrast else Color("ffffff")
	canvas.draw_circle(position, r, core)
	if role_symbol == "pin":
		canvas.draw_polyline(PackedVector2Array([
			position + Vector2(0, -r - 12), position + Vector2(-6, -r - 4), position + Vector2(6, -r - 4),
			position + Vector2(0, -r - 12),
		]), core, 1.6)
	elif role_symbol == "pan":
		canvas.draw_arc(position + Vector2(0, -r - 8), 5.0, 0.0, TAU, 10, core, 1.6)
