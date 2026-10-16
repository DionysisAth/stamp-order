class_name InkSplat
extends CPUParticles2D
## One-shot burst of ink droplets when a stamp lands.


func setup(col: Color, extent: float) -> void:
	one_shot = true
	explosiveness = 0.95
	amount = 16
	lifetime = 0.45
	emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	emission_sphere_radius = extent * 0.35
	direction = Vector2.UP
	spread = 180.0
	gravity = Vector2.ZERO
	initial_velocity_min = extent * 0.6
	initial_velocity_max = extent * 1.4
	damping_min = extent * 2.0
	damping_max = extent * 3.0
	scale_amount_min = maxf(2.0, extent * 0.03)
	scale_amount_max = maxf(4.0, extent * 0.07)
	color = col.darkened(0.05)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	color_ramp = fade
	finished.connect(queue_free)
	emitting = true
