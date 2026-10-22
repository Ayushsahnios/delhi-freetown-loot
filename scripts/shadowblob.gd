extends RefCounted
## Contact shadows: one shared radial-gradient blob quad per actor (player,
## legends, pedestrians, drivable vehicles) grounds them on the street even
## when the sun sits low or its shadow map is disabled in settings.

static var _tex: GradientTexture2D = null


## Dark soft disc under `parent` at ground level. Cheap: one shared 64px
## texture, one unshaded alpha quad, never casts shadows itself.
static func attach(parent: Node3D, radius: float, y := 0.05) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _texture()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.render_priority = -1
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.position = Vector3(0.0, y, 0.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func _texture() -> GradientTexture2D:
	if _tex == null:
		var grad := Gradient.new()
		grad.set_color(0, Color(0.0, 0.0, 0.0, 0.45))
		grad.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
		_tex = GradientTexture2D.new()
		_tex.fill = GradientTexture2D.FILL_RADIAL
		_tex.fill_from = Vector2(0.5, 0.5)
		_tex.fill_to = Vector2(1.0, 0.5)
		_tex.gradient = grad
		_tex.width = 64
		_tex.height = 64
	return _tex
