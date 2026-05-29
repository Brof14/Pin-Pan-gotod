extends Control

@onready var blue_character = $CharacterLayer/BlueCharacter
@onready var red_character = $CharacterLayer/RedCharacter
@onready var blue_mesh = $CharacterLayer/BlueCharacter/BlueCharacterBody/BlueCharacterMesh
@onready var red_mesh = $CharacterLayer/RedCharacter/RedCharacterBody/RedCharacterMesh
@onready var thread1 = $EffectsLayer/ThreadConnections/Thread1
@onready var thread2 = $EffectsLayer/ThreadConnections/Thread2
@onready var particles = $EffectsLayer/ParticleEffect
@onready var bloom_effect = $EffectsLayer/BloomEffect
@onready var background_texture = $BackgroundLayer/BackgroundTexture
@onready var atmosphere_fog = $BackgroundLayer/AtmosphereFog
@onready var logo = $UILayer/LogoContainer/Logo
@onready var continue_button = $UILayer/MenuButtons/MenuButtonsContainer/ContinueButton
@onready var new_game_button = $UILayer/MenuButtons/MenuButtonsContainer/NewGameButton
@onready var settings_button = $UILayer/MenuButtons/MenuButtonsContainer/SettingsButton
@onready var achievements_button = $UILayer/MenuButtons/MenuButtonsContainer/AchievementsButton
@onready var exit_button = $UILayer/MenuButtons/MenuButtonsContainer/ExitButton
@onready var gamepad_icon = $UILayer/TopRightIcons/GamepadIcon
@onready var settings_icon = $UILayer/TopRightIcons/SettingsIcon
@onready var language_icon = $UILayer/TopRightIcons/LanguageIcon

var time = 0.0
var mouse_pos = Vector2.ZERO
var parallax_strength = 0.02

func _ready():
	setup_background()
	setup_characters()
	setup_threads()
	setup_particles()
	setup_lighting()
	setup_buttons()
	setup_icons()
	setup_animations()

func _process(delta):
	time += delta
	update_parallax()
	update_character_animation()
	update_thread_animation()
	update_particles()
	update_bloom()
	update_logo()

func setup_background():
	# Dark textile cave background
	background_texture.texture = create_textile_texture()
	atmosphere_fog.color = Color(0, 0, 0, 0.3)

func create_textile_texture():
	var img = Image.create(1024, 1024, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.05, 0.05, 0.08))

	# Add textile pattern
	for x in range(0, 1024, 32):
		for y in range(0, 1024, 32):
			var noise = randf() * 0.1 - 0.05
			img.fill_rect(Rect2(x, y, 32, 32), Color(0.05 + noise, 0.05 + noise, 0.08 + noise))

	var texture = ImageTexture.create_from_image(img)
	return texture

func setup_characters():
	# Create irregular yarn meshes
	var blue_texture = create_yarn_texture(Color(0.3, 0.4, 0.9))
	var red_texture = create_yarn_texture(Color(0.9, 0.3, 0.3))

	blue_mesh.texture = blue_texture
	red_mesh.texture = red_texture

	# Add some randomness to make them look handmade
	blue_character.scale = Vector2(1.0 + randf() * 0.1, 1.0 + randf() * 0.1)
	red_character.scale = Vector2(1.0 + randf() * 0.1, 1.0 + randf() * 0.1)

func create_yarn_texture(base_color):
	var img = Image.create(128, 128, false, Image.FORMAT_RGBA8)

	# Create irregular yarn ball
	var center = Vector2(64, 64)
	for x in range(0, 128):
		for y in range(0, 128):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 60:
				# Create irregular texture with noise
				var noise1 = sin(x * 0.1) * cos(y * 0.1)
				var noise2 = sin(x * 0.05 + y * 0.05) * sin(time * 0.5)
				var noise3 = randf() * 0.3 - 0.15
				var noise = (noise1 * 0.3 + noise2 * 0.2 + noise3 + 1.0) * 0.5
				var color = base_color * (noise * 0.7 + 0.3)
				var alpha = (1.0 - dist / 60) * 0.9
				img.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))

	var texture = ImageTexture.create_from_image(img)
	return texture

func setup_threads():
	# Create thread connections between characters
	thread1.points = PackedVector2Array([
		Vector2(-250, 150),
		Vector2(0, 250),
		Vector2(250, 150)
	])

	thread2.points = PackedVector2Array([
		Vector2(-200, 200),
		Vector2(0, 300),
		Vector2(200, 200)
	])

	# Apply glow shader
	var thread_shader = load("res://shaders/thread_glow.gdshader")
	thread1.material = ShaderMaterial.new()
	thread1.material.shader = thread_shader
	thread2.material = ShaderMaterial.new()
	thread2.material.shader = thread_shader

func setup_particles():
	# Warm orange glowing particles
	var material = particles.process_material
	material.emission = Color(1.0, 0.6, 0.2, 1.0)
	material.emission_energy_multiplier = 2.0
	particles.amount = 50
	particles.lifetime = 3.0

func setup_lighting():
	# Blue ambient lighting
	background_texture.modulate = Color(0.8, 0.9, 1.2, 1.0)

	# Add subtle vignette
	bloom_effect.color = Color(0, 0, 0, 0.1)

func setup_buttons():
	# Custom button styling using theme overrides
	var theme = Theme.new()

	# Create base style for all buttons
	var base_stylebox = StyleBoxFlat.new()
	base_stylebox.bg_color = Color(0, 0, 0, 0.6)
	base_stylebox.corner_radius_top_left = 10
	base_stylebox.corner_radius_top_right = 10
	base_stylebox.corner_radius_bottom_left = 10
	base_stylebox.corner_radius_bottom_right = 10
	base_stylebox.content_margin_left = 20
	base_stylebox.content_margin_right = 20
	base_stylebox.content_margin_top = 10
	base_stylebox.content_margin_bottom = 10

	# Add styles to theme
	theme.add_stylebox("normal", "Button", base_stylebox)
	theme.add_stylebox("hover", "Button", base_stylebox)
	theme.add_stylebox("pressed", "Button", base_stylebox)

	# Set font size
	theme.add_font_size("font_size", "Button", 24)

	# Apply theme to buttons
	continue_button.add_theme_color("font_color", Color(1, 1, 1, 1))
	new_game_button.add_theme_color("font_color", Color(1, 1, 1, 1))
	settings_button.add_theme_color("font_color", Color(1, 1, 1, 1))
	achievements_button.add_theme_color("font_color", Color(1, 1, 1, 1))
	exit_button.add_theme_color("font_color", Color(1, 1, 1, 1))

	# Connect button signals
	continue_button.mouse_entered.connect(_on_button_hover.bind(continue_button))
	continue_button.mouse_exited.connect(_on_button_leave.bind(continue_button))
	new_game_button.mouse_entered.connect(_on_button_hover.bind(new_game_button))
	new_game_button.mouse_exited.connect(_on_button_leave.bind(new_game_button))
	settings_button.mouse_entered.connect(_on_button_hover.bind(settings_button))
	settings_button.mouse_exited.connect(_on_button_leave.bind(settings_button))
	achievements_button.mouse_entered.connect(_on_button_hover.bind(achievements_button))
	achievements_button.mouse_exited.connect(_on_button_leave.bind(achievements_button))
	exit_button.mouse_entered.connect(_on_button_hover.bind(exit_button))
	exit_button.mouse_exited.connect(_on_button_leave.bind(exit_button))

func setup_icons():
	# Create glowing circular icons
	gamepad_icon.texture = create_icon_texture()
	settings_icon.texture = create_icon_texture()
	language_icon.texture = create_icon_texture()

func create_icon_texture():
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# Create circular glow
	var center = Vector2(16, 16)
	for x in range(0, 32):
		for y in range(0, 32):
			var dist = Vector2(x, y).distance_to(center)
			if dist < 15:
				var alpha = (1.0 - dist / 15) * 0.8
				img.set_pixel(x, y, Color(0.8, 0.8, 1.0, alpha))

	var texture = ImageTexture.create_from_image(img)
	return texture

func setup_animations():
	# Start particle animation
	particles.emitting = true

func update_parallax():
	# Mouse-based parallax
	var parallax_offset = (mouse_pos - Vector2(get_viewport().size.x / 2, get_viewport().size.y / 2)) * parallax_strength

	# Background parallax
	background_texture.position = parallax_offset * 0.3

	# Character parallax
	blue_character.position = Vector2(-300, 100) + parallax_offset * 0.5
	red_character.position = Vector2(300, 100) + parallax_offset * 0.5

	# Thread parallax
	thread1.points = PackedVector2Array([
		Vector2(-250, 150) + parallax_offset * 0.3,
		Vector2(0, 250) + parallax_offset * 0.4,
		Vector2(250, 150) + parallax_offset * 0.3
	])

	thread2.points = PackedVector2Array([
		Vector2(-200, 200) + parallax_offset * 0.3,
		Vector2(0, 300) + parallax_offset * 0.4,
		Vector2(200, 200) + parallax_offset * 0.3
	])

func update_character_animation():
	# Subtle breathing animation
	var breath_scale = 1.0 + sin(time * 2.0) * 0.02

	blue_character.scale = Vector2(breath_scale, breath_scale)
	red_character.scale = Vector2(breath_scale, breath_scale)

	# Slight sway
	var sway_offset = sin(time * 1.5) * 5.0
	blue_character.rotation = deg_to_rad(sway_offset)
	red_character.rotation = deg_to_rad(-sway_offset)

func update_thread_animation():
	# Subtle thread animation
	var wave_offset = sin(time * 3.0) * 10.0

	thread1.points[1] = Vector2(0, 250 + wave_offset)
	thread2.points[1] = Vector2(0, 300 + wave_offset)

	# Update shader uniforms
	if thread1.material and thread1.material.shader:
		thread1.material.material.set_shader_parameter("time", time)
		thread1.material.material.set_shader_parameter("glow_intensity", 0.5)
	if thread2.material and thread2.material.shader:
		thread2.material.material.set_shader_parameter("time", time)
		thread2.material.material.set_shader_parameter("glow_intensity", 0.5)

func update_particles():
	# Particle drift
	var material = particles.process_material
	material.direction = Vector2(sin(time * 0.5), cos(time * 0.3)) * 50

func update_bloom():
	# Subtle bloom pulse
	var bloom_intensity = 0.05 + sin(time * 1.2) * 0.02
	bloom_effect.color = Color(0, 0, 0, bloom_intensity)

func update_logo():
	# Create glowing thread effect on logo
	var glow_intensity = (sin(time * 2.0) + 1.0) * 0.5
	var theme = Theme.new()

	# Create gradient effect for PIN
	var pin_color = Color(1.0, 0.3, 0.3, 1.0)
	pin_color = pin_color.lerp(Color(1.0, 0.6, 0.6, 1.0), glow_intensity * 0.3)

	# Create gradient effect for PAN
	var pan_color = Color(0.3, 0.3, 1.0, 1.0)
	pan_color = pan_color.lerp(Color(0.6, 0.6, 1.0, 1.0), glow_intensity * 0.3)

	# Update label with colored text effect
	# Note: Godot Label doesn't support per-character coloring, so we'll use a simple glow effect
	logo.modulate = Color(1.0 + glow_intensity * 0.2, 1.0 + glow_intensity * 0.2, 1.0 + glow_intensity * 0.2, 1.0)

func _on_button_hover(button):
	# Button hover effect
	button.modulate = Color(1.2, 1.2, 1.4, 1.0)

func _on_button_leave(button):
	# Button normal effect
	button.modulate = Color(1.0, 1.0, 1.0, 1.0)

func _input(event):
	if event is InputEventMouseMotion:
		mouse_pos = event.position
	elif event is InputEventKey:
		if event.pressed and event.keycode == KEY_E:
			# Handle E key press
			print("E key pressed")

func _notification(what):
	if what == NOTIFICATION_READY:
		get_viewport().connect("size_changed", Callable(self, "_on_viewport_size_changed"))

func _on_viewport_size_changed():
	# Update UI for new viewport size
	pass
