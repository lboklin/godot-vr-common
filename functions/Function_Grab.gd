extends Spatial

export (NodePath) var equipped_item
var grabbed_item = null setget set_grabbed_item
var grabbable_items = [] setget set_grabbable_items,get_grabbable_items


func set_grabbed_item(item):
	if item:
		item.is_held = true
		grabbed_item = item

		excl_from_tp(grabbed_item)

		return item
	else:
		# Remove exclusion from collision if teleport is enabled
		var tp = get_parent().find_node("Function_Teleport")
		if tp:
			var rid = grabbed_item.get_rid()
			tp.excluded_colliders.erase(rid)

		grabbed_item.is_held = false
		grabbed_item = null
		return null

func get_grabbable_items():
	return grabbable_items if grabbable_items else []

func set_grabbable_items(items):
	if grabbable_items:
		for item in items:
			grabbable_items.push_front(item)
	else:
		grabbable_items = items


func _ready():
	# Get button press feedback from our parent (should be an ARVRController)
	get_parent().connect("button_pressed", self, "_on_button_pressed")
	get_parent().connect("button_release", self, "_on_button_release")

	excl_from_tp(self)

	if equipped_item:
		var e_i = get_node(equipped_item)
		_on_RigidBody_body_entered(e_i)
		_on_button_pressed(2, e_i)

	set_process(true)

func _process(delta):
	var controller = self.get_parent()
	controller.find_node("Controller_mesh").visible = !grabbed_item

	if grabbed_item:
		align_with_controller(controller, grabbed_item, 1, delta)


# Exclude from collision if teleport is enabled
func excl_from_tp(item):
	var tp = get_parent().find_node("Function_Teleport")
	if tp:
		var rid = item.get_rid()
		var excls = tp.excluded_colliders
		if not excls.empty():
			tp.excluded_colliders.append(rid)
		else:
			tp.excluded_colliders = [ rid ]


static func align_with_controller(controller, item, value, delta):
		var c_tf = controller.global_transform.orthonormalized()
		var gi_tf = item.global_transform

		var tgt_x = c_tf.basis.x
		var tgt_y = -c_tf.basis.z
		var tgt_z = c_tf.basis.y
		var tgt_basis = Basis(tgt_x, tgt_y, tgt_z)

		var is_snap_dist = true # c_tf.origin.distance_to(gi_tf.origin) < 0.05
		var factor = 3
		var value_ = 1 if is_snap_dist else value + (delta * factor) if value + value <= 1 else 0
		var rot_quat = Quat(gi_tf.basis).slerp(tgt_basis, value_)
		var new_origin = gi_tf.origin.linear_interpolate(c_tf.origin, value_)
		var new_tf = Transform(rot_quat, new_origin)

		var gi_scale = item.scale # Workaround for someone who doesn't get transforms
		item.transform = new_tf
		item.scale = gi_scale

		return value_


func _on_button_pressed(button, on_item=null):
	match button:
		2: # Grip buttons
			if not grabbed_item and not grabbable_items.empty():
				self.grabbed_item = grabbable_items[0]
#            var item = $RayCast.get_collider() if $RayCast.is_colliding() else on_item if on_item else null
#            if !grabbed_item and item and item.has_method("set_is_held"):
#                self.grabbed_item = item
			elif grabbed_item:
				self.grabbed_item = null
		15: # Trigger
			if grabbed_item and grabbed_item.has_method("_on_use_pressed"):
				grabbed_item._on_use_pressed()


func _on_button_release(button):
	match button:
		15: # Trigger
			if grabbed_item and grabbed_item.has_method("_on_use_release"):
				grabbed_item._on_use_release()


func _on_Function_Grab_body_entered(body):
#	print("RigidBody entered: ", body.name)
	if not grabbed_item and body.has_method("_on_grab_pressed"):
		self.grabbable_items = [ body ]


func _on_Function_Grab_body_exited(body):
#	print("RigidBody exited: ", body.name)
	var items = self.grabbable_items
	items.erase(body)
	self.grabbable_items = items
