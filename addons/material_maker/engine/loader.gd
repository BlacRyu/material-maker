tool
extends Node

const STD_GENDEF_PATH = "res://addons/material_maker/nodes"

var predefined_generators = {}

func _ready()-> void:
	update_predefined_generators()

func update_predefined_generators()-> void:
	predefined_generators = {}
	for path in [ STD_GENDEF_PATH, OS.get_executable_path().get_base_dir()+"/generators" ]:
		var dir = Directory.new()
		if dir.open(path) == OK:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if !dir.current_is_dir() and file_name.get_extension() == "mmg":
					var file : File = File.new()
					if file.open(path+"/"+file_name, File.READ) == OK:
						predefined_generators[file_name.get_basename()] = parse_json(file.get_as_text())
						file.close()
				file_name = dir.get_next()

func generator_name_from_path(path : String) -> String:
	for p in [ STD_GENDEF_PATH, OS.get_executable_path().get_base_dir()+"/generators" ]:
		print(p)
	print(path.get_base_dir())
	return path.get_basename().get_file()

func load_gen(filename: String) -> MMGenBase:
	var file = File.new()
	if file.open(filename, File.READ) == OK:
		var data = parse_json(file.get_as_text())
		return create_gen(data)
	return null

func add_to_gen_graph(gen_graph, generators, connections) -> Dictionary:
	var rv = { generators=[], connections=[] }
	var gennames = {}
	for n in generators:
		var g = create_gen(n)
		if g != null:
			var orig_name = g.name
			if gen_graph.add_generator(g):
				rv.generators.append(g)
			gennames[orig_name] = g.name
	for c in connections:
		if gennames.has(c.from) and gennames.has(c.to):
			c.from = gennames[c.from]
			c.to = gennames[c.to]
			if gen_graph.connect_children(gen_graph.get_node(c.from), c.from_port, gen_graph.get_node(c.to), c.to_port):
				rv.connections.append(c)
	return rv

func create_gen(data) -> MMGenBase:
	var guess = [
		{ keyword="connections", type=MMGenGraph },
		{ keyword="nodes", type=MMGenGraph },
		{ keyword="shader_model", type=MMGenShader },
		{ keyword="convolution_params", type=MMGenConvolution },
		{ keyword="model_data", type=MMGenShader },
		{ keyword="convolution_params", type=MMGenConvolution },
		{ keyword="widgets", type=MMGenRemote }
	]
	var types = {
		material = MMGenMaterial,
		buffer = MMGenBuffer,
		image = MMGenImage,
		ios = MMGenIOs,
		switch = MMGenSwitch,
		export = MMGenExport,
		comment = MMGenComment,
		debug = MMGenDebug,
		audio = MMGenAudio
	}
	var generator = null
	for g in guess:
		if data.has(g.keyword):
			generator = g.type.new()
			break
	if generator == null and data.has("type"):
		if types.has(data.type):
			generator = types[data.type].new()
		elif predefined_generators.has(data.type):
			generator = create_gen(predefined_generators[data.type])
			if generator == null:
				print("Cannot find description for "+data.type)
			else:
				generator.model = data.type
		if generator != null:
			generator.name = data.type
	if generator == null:
		print("LOADER: data not supported:"+str(data))
	if generator != null:
		generator.deserialize(data)
	return generator

func get_generator_list() -> Array:
	var rv = []
	var dir : Directory = Directory.new()
	for p in [ STD_GENDEF_PATH, OS.get_executable_path().get_base_dir()+"/generators" ]:
		dir.open(p)
		dir.list_dir_begin(true)
		while true:
			var f = dir.get_next()
			if f == "":
				break
			if f.right(f.length()-4) == ".mmg":
				var n = f.left(f.length()-4)
				if rv.find(n) == -1:
					rv.push_back(n)
	rv.sort()
	return rv