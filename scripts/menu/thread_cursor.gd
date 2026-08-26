class_name ThreadCursor
extends RefCounted

const DOT_RADIUS := 6.0
const GLOW_RADIUS := 12.0
const TAIL_BASE := 40.0
const TAIL_HOVER := 70.0
const RESPONSE := 15.0
const DAMPING := 0.30
const MAX_SPEED := 1800.0
const SNAP_DISTANCE := 18.0

var position := Vector2(960.0, 540.0)
var velocity := Vector2.ZERO
var target := Vector2(960.0, 540.0)
var tail_length := TAIL_BASE
var tail_target := TAIL_BASE
var select_pulse := 0.0
var hover_amount := 0.0
var trail: Array[Vector2] = []
var is_pin_contour := false

func reset(at: Vector2) -> void:
	position = at
	target = at
	velocity = Vector2.ZERO
	trail.clear()

func set_target(p: Vector2) -> void:
	target = p

func set_hover(active: bool) -> void:
	tail_target = TAIL_HOVER if active else TAIL_BASE

func trigger_select() -> void:
	select_pulse = 1.0

func update(delta: float, snap_anchor: Vector2 = Vector2.INF) -> void:
	var effective_target := target
	if snap_anchor != Vector2.INF and position.distance_to(snap_anchor) < SNAP_DISTANCE:
		effective_target = snap_anchor
	var delta_pos := effective_target - position
	var spring := delta_pos * RESPONSE
	var damping := velocity * (2.0 * sqrt(RESPONSE) * DAMPING)
	var accel := spring - damping
	velocity += accel * delta
	if velocity.length() > MAX_SPEED:
		velocity = velocity.normalized() * MAX_SPEED
	position += velocity * delta
	tail_length = lerpf(tail_length, tail_target, minf(1.0, delta * 8.0))
	hover_amount = lerpf(hover_amount, 1.0 if tail_target > TAIL_BASE + 1.0 else 0.0, minf(1.0, delta * 10.0))
	select_pulse = maxf(0.0, select_pulse - delta * 5.0)
	trail.push_front(position)
	var max_trail := int(tail_length / 8.0) + 2
	while trail.size() > max_trail:
		trail.pop_back()

func dot_radius() -> float:
	return lerpf(DOT_RADIUS, 10.0, select_pulse)

func draw_on(node: Node2D, color: Color) -> void:
	if trail.size() > 1:
		for i in range(trail.size() - 1):
			var t := float(i) / float(trail.size())
			var alpha := lerpf(0.55, 0.05, t)
			var width := lerpf(2.5, 1.0, t)
			node.draw_line(trail[i], trail[i + 1], Color(color, alpha), width)
	var radius := dot_radius()
	node.draw_circle(position, radius, color)
	node.draw_circle(position, GLOW_RADIUS, Color(color, 0.18 + hover_amount * 0.17))
