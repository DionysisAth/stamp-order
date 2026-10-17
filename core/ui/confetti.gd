class_name Confetti
extends CPUParticles2D
## One-shot shower of bright confetti tumbling down from the top.

const COLORS := ["ff3d7f", "ffc61a", "2ee6a6", "4dabff", "b14dff", "ff8a00", "38d1ff", "a3e635"]


func _init(width: float = 720.0) -> void:
	one_shot = true
	amount = 140
	lifetime = 3.2
	explosiveness = 0.85
	emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	emission_rect_extents = Vector2(width * 0.5, 10)
	direction = Vector2.DOWN
	spread = 35.0
	gravity = Vector2(0, 520)
	initial_velocity_min = 150.0
	initial_velocity_max = 520.0
	damping_min = 10.0
	damping_max = 60.0
	angle_min = 0.0
	angle_max = 360.0
	angular_velocity_min = -540.0
	angular_velocity_max = 540.0
	scale_amount_min = 9.0
	scale_amount_max = 17.0
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	ramp.offsets = PackedFloat32Array()
	ramp.colors = PackedColorArray()
	for i in COLORS.size():
		ramp.add_point(float(i) / COLORS.size(), Color(COLORS[i]))
	color_initial_ramp = ramp
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	color_ramp = fade
	finished.connect(queue_free)


func burst() -> void:
	emitting = true
