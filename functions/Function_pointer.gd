"res://addons/vr-common/functions/Function_pointer.tscn"extends Spatial

var target = null
var last_collided_at = Vector3(0, 0, 0)
var laser_y = -0.00
onready var ws = ARVRServer.world_scale

func set_enabled(p_enabled):
	$Laser.visible = p_enabled
	$Laser/RayCast.enabled = p_enabled

func _on_button_pressed(p_button):
	if p_button == 15 and $Laser/RayCast.enabled:
		if $Laser/RayCast.is_colliding():
			target = $Laser/RayCast.get_collider()
			last_collided_at = $Laser/RayCast.get_collision_point()
			print("Button pressed on " + target.get_name() + " at " + str(last_collided_at))
			if target.has_method("_on_pointer_pressed"):
				target._on_pointer_pressed(last_collided_at)

func _on_button_release(p_button):
	if p_button == 15 and target:
		# let object know button was released
		print("Button released on " + target.get_name())
		if target.has_method("_on_pointer_release"):
			target._on_pointer_release(last_collided_at)

		target = null
		last_collided_at = Vector3(0, 0, 0)

func _ready():
	# Get button press feedback from our parent (should be an ARVRController)
	get_parent().connect("button_pressed", self, "_on_button_pressed")
	get_parent().connect("button_release", self, "_on_button_release")

	# apply our world scale to our laser position
	$Laser.translation.y = laser_y * ws

func _process(delta):
	var new_ws = ARVRServer.world_scale
	if (ws != new_ws):
		ws = new_ws
	$Laser.translation.y = laser_y * ws

	if $Laser/RayCast.enabled and $Laser/RayCast.is_colliding():
		var new_at = $Laser/RayCast.get_collision_point()
		var new_target = $Laser/RayCast.get_collider()

		var color = interactive_color(new_target)
		$Laser.mesh.material.emission = color
		$Laser.mesh.material.albedo_color = color

		if new_at == last_collided_at:
			pass
		elif target:
			# if target is set our mouse must be down, we keep sending events to our target
			if target.has_method("_on_pointer_moved"):
				target._on_pointer_moved(new_at, last_collided_at)
		else:
			if new_target.has_method("_on_pointer_moved"):
				new_target._on_pointer_moved(new_at, last_collided_at)

		if new_target.has_method("_on_pointer_pressed"):
			# Cut the visible laser to where it intersects with target
			print("Pointer moved over interactable: " + new_target.get_name())
			var tgt_dist = $Laser.global_transform.origin.distance_to(new_at)
			$Laser.transform.origin.z = -tgt_dist * 0.5
			# Overlap in order to keep colliding with target
			var overlap = 0.01
			$Laser.mesh.size = Vector3(0.002, 0.002, tgt_dist + overlap)
			last_collided_at = new_at
			$Laser.visible = true
	else:
		$Laser.visible = false


static func interactive_color(target_):
	if target_:
		var can_point = target_.has_method("_on_pointer_moved")
		var can_use = target_.has_method("_on_use_pressed")
		var can_grab = target_.has_method("_on_grab_pressed")

		var silver = Color(0.7, 0.7, 0.7)
		var cyan = Color(0.2, 0.7, 0.7)
		var blue = Color(0.2, 0.2, 0.7)
		var green = Color(0.2, 0.7, 0.2)
		var red = Color(0.7, 0.2, 0.2)
		var dim_grey = Color(0.2, 0.2, 0.2)

		match [ can_point, can_use, can_grab ]:
			[ false, false, false ]: return red
			[ true , _    , _     ]: return silver
			[ _    , true , false ]: return blue
			[ _    , false, true  ]: return green
			[ _    , true , true  ]: return cyan
			# For completeness sake (shouldn't happen):
			_                      : return dim_grey


