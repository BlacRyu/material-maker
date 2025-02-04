extends Node

var item_types : Array = []
var item_ids : Dictionary = {}

func _ready():
	item_types.clear()
	item_ids.clear()
	create_item_list()

func create_item_list(parent : Node = self):
	for c in parent.get_children():
		if c.get("item_type") == null:
			create_item_list(c)
		else:
			item_ids[c.item_type] = item_types.size()
			item_types.push_back(c)

func get_items_menu(category : String, target : Object, method : String, binds : Array = [], filter : Array = [], parent : Node = self) -> PopupMenu:
	var menu : PopupMenu = PopupMenu.new()
	for c in parent.get_children():
		if c.get("item_type") == null:
			var submenu : PopupMenu = get_items_menu(category, target, method, binds, filter, c)
			if submenu.get_item_count() > 0:
				submenu.name = c.name
				menu.add_child(submenu)
				menu.add_submenu_item(c.name, c.name)
			else:
				submenu.free()
		elif c.item_category in filter:
			var icon : Texture = c.get("icon")
			if icon != null:
				menu.add_icon_item(icon, c.name, item_ids[c.item_type])
			else:
				menu.add_item(c.name, item_ids[c.item_type])
	menu.connect("id_pressed", target, method, binds)
	return menu

func get_shape_names() -> Array:
	var names = []
	for c in get_children():
		names.push_back(c.name)
	return names

func get_includes(scene : Dictionary) -> Array:
	if scene.has("hidden") and scene.hidden:
		return []
	var includes : Array = []
	var type = item_types[item_ids[scene.type]]
	if type.has_method("get_includes"):
		for i in type.get_includes():
			if !includes.has(i):
				includes.push_back(i)
	if scene.has("children"):
		for c in scene.children:
			for i in get_includes(c):
				if !includes.has(i):
					includes.push_back(i)
	return includes

func add_parameters(scene : Dictionary, data : Dictionary, parameter_defs : Array):
	pass

func scene_get_type(scene : Dictionary):
	return item_types[item_ids[scene.type]]

func scene_to_shader_model(scene : Dictionary, uv : String = "$uv", editor = false) -> Dictionary:
	if scene.has("hidden") and scene.hidden:
		return {}
	var scene_node = scene_get_type(scene)
	var shader_model = scene_node.scene_to_shader_model(scene, uv, editor)
	if editor:
		for p in scene_node.get_parameter_defs():
			p = p.duplicate(true)
			if scene.parameters.has(p.name):
				p.default = scene.parameters[p.name]
			var new_name = "n%d_%s" % [ scene.index, p.name ]
			shader_model.code = shader_model.code.replace("$"+p.name, "$"+new_name)
			p.name = new_name
			shader_model.parameters.push_back(p)
	else:
		for p in scene_node.get_parameter_defs():
			match p.type:
				"boolean":
					shader_model.code = shader_model.code.replace("$"+p.name, "true" if scene.parameters[p.name] else "false")
				"enum":
					shader_model.code = shader_model.code.replace("$"+p.name, p.values[scene.parameters[p.name]].value)
				"float":
					shader_model.code = shader_model.code.replace("$"+p.name, "%.09f" % scene.parameters[p.name])
				_:
					print("Unsupported parameter %s of type %s" % [ p.name, p.type ])
					return {}
	shader_model.includes = get_includes(scene)
	return shader_model

func generate_rotate_3d(variable, _scene) -> String:
	var rv : String = ""
	rv += "%s.zx = rotate(%s.zx, radians($angle_y));\n" % [ variable, variable ]
	rv += "%s.yz = rotate(%s.yz, radians($angle_x));\n" % [ variable, variable ]
	rv += "%s.xy = rotate(%s.xy, radians($angle_z));\n" % [ variable, variable ]
	return rv
