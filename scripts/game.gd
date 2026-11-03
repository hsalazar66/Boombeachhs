class_name IslandGame
extends RefCounted

const VERSION = 1
var rules: Dictionary
var state: Dictionary = {}
var error := ""
var save_path: String
var admin_until := 0
var committed: Dictionary = {}

func _init(path := "user://archipelago.json"):
	save_path = path
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	state = {"version": VERSION, "active": "", "profiles": [], "admin": {}, "audit": []}
	committed = state.duplicate(true)

func now() -> int:
	return int(Time.get_unix_time_from_system())

func fail(message: String) -> bool:
	error = message
	return false

func profile() -> Dictionary:
	for p in state.profiles:
		if p.id == state.active:
			return p
	return {}

func create_profile(display_name: String) -> bool:
	if state.profiles.size() >= int(rules.max_profiles):
		return fail("Máximo de cinco perfiles")
	if display_name.strip_edges().is_empty() or display_name.length() > 24:
		return fail("Escribe un nombre de 1 a 24 caracteres")
	if not state.profiles.is_empty() and not is_admin():
		return fail("Desbloquea la administración para crear perfiles")
	var id = Crypto.new().generate_random_bytes(12).hex_encode()
	var p = {"id":id, "name":display_name.strip_edges(), "created":now(), "enabled":true,
		"resources":{"oro":400,"madera":400,"piedra":200}, "last_tick":now(),
		"buildings":[{"id":"hq","kind":"central","x":5,"y":3,"level":1,"finish":0},
		{"id":"mill","kind":"aserradero","x":2,"y":5,"level":1,"finish":0},
		{"id":"gold","kind":"mina","x":8,"y":5,"level":1,"finish":0},
		{"id":"boat","kind":"lancha","x":4,"y":8,"level":1,"finish":0}],
		"army":{"infanteria":6,"pesado":0,"tirador":0,"vehiculo":0}, "troop_levels":{},
		"completed":[], "battle":{}, "difficulty":"normal", "tutorial":0,
		"stats":{"wins":0,"losses":0,"seconds":0},
		"settings":{"audio":true,"vibration":true,"graphics":"normal","ui_scale":1.0}}
	state.profiles.append(p)
	state.active = id
	return save()

func select_profile(id: String) -> bool:
	for p in state.profiles:
		if p.id == id and p.enabled:
			state.active = id
			tick(now())
			return save()
	return fail("Perfil no disponible")

func hq_level() -> int:
	for b in profile().get("buildings", []):
		if b.kind == "central":
			return int(b.level)
	return 1

func capacity() -> int:
	var total = 800
	for b in profile().get("buildings", []):
		if b.kind == "almacen":
			total += 600 * int(b.level)
	return total

func transport() -> int:
	var total = 0
	for b in profile().get("buildings", []):
		if b.kind == "lancha":
			total += 10 * int(b.level)
	return total

func occupied_transport() -> int:
	var total = 0
	for kind in profile().get("army", {}):
		total += int(profile().army[kind]) * int(rules.troops[kind].space)
	return total

func pay(cost: Dictionary) -> bool:
	var p = profile()
	for resource in cost:
		if p.resources[resource] < cost[resource]:
			return fail("Falta " + resource)
	for resource in cost:
		p.resources[resource] -= cost[resource]
	return true

func tick(timestamp: int) -> void:
	var p = profile()
	if p.is_empty():
		return
	var elapsed = clampi(timestamp - int(p.last_tick), 0, int(rules.offline_cap_seconds))
	for b in p.buildings:
		var config = rules.buildings[b.kind]
		if config.has("production"):
			var r = config.production
			p.resources[r] = mini(capacity(), int(p.resources[r]) + int(elapsed * float(config.rate) * int(b.level)))
		if int(b.finish) > 0 and timestamp >= int(b.finish):
			b.level += 1
			b.finish = 0
	# Never move the clock backwards; also prevents repeatedly farming a clock rollback.
	p.last_tick = maxi(timestamp, int(p.last_tick))

func can_place(kind: String, x: int, y: int, ignored_id := "") -> bool:
	if not rules.buildings.has(kind):
		return false
	var size = int(rules.buildings[kind].size)
	var area = Rect2i(x,y,size,size)
	if x < 0 or y < 0 or x + size > int(rules.grid) or y + size > int(rules.grid):
		return false
	for b in profile().buildings:
		if b.id != ignored_id and area.intersects(Rect2i(int(b.x),int(b.y),int(rules.buildings[b.kind].size),int(rules.buildings[b.kind].size))):
			return false
	return true

func build(kind: String, x: int, y: int) -> bool:
	if kind == "central" or not rules.buildings.has(kind):
		return fail("Edificio no disponible")
	if int(rules.buildings[kind].unlock) > hq_level() or not can_place(kind,x,y):
		return fail("Posición ocupada, fuera del terreno o nivel insuficiente")
	if not pay(rules.buildings[kind].cost):
		return false
	profile().buildings.append({"id":Crypto.new().generate_random_bytes(8).hex_encode(),"kind":kind,"x":x,"y":y,"level":1,"finish":0})
	return save()

func move_building(id: String, x: int, y: int) -> bool:
	for b in profile().buildings:
		if b.id == id and can_place(b.kind,x,y,id):
			b.x = x
			b.y = y
			return save()
	return fail("Posición no válida")

func upgrade_cost(b: Dictionary) -> Dictionary:
	var cost = rules.buildings[b.kind].cost.duplicate()
	for r in cost:
		cost[r] *= int(b.level) + 1
	return cost

func upgrade(id: String) -> bool:
	for b in profile().buildings:
		if b.id != id:
			continue
		if int(b.finish) > 0 or int(b.level) >= 5 or (b.kind != "central" and int(b.level) >= hq_level()):
			return fail("Mejora pendiente o límite de nivel")
		if not pay(upgrade_cost(b)):
			return false
		b.finish = now() + int(rules.buildings[b.kind].seconds) * int(b.level)
		return save()
	return false

func train(kind: String) -> bool:
	if not rules.troops.has(kind):
		return false
	var t = rules.troops[kind]
	if hq_level() < int(t.unlock) or occupied_transport() + int(t.space) > transport():
		return fail("Nivel insuficiente o lancha llena")
	if not pay(t.cost):
		return false
	profile().army[kind] += 1
	return save()

func unlocked(mission: int) -> bool:
	return mission >= 1 and mission <= rules.missions.size() and (mission == 1 or profile().completed.has(mission-1))

func start_battle(mission: int) -> bool:
	if not unlocked(mission) or not profile().battle.is_empty() or occupied_transport() == 0:
		return fail("Necesitas tropas, una misión disponible y ninguna batalla pendiente")
	if not pay({"oro":rules.missions[mission-1].attack_cost}):
		return false
	profile().battle = {"id":Crypto.new().generate_random_bytes(12).hex_encode(),"mission":mission,"army":profile().army.duplicate()}
	for kind in profile().army:
		profile().army[kind] = 0
	return save()

func finish_battle(victory: bool, survivors: Dictionary) -> bool:
	var p = profile()
	if p.battle.is_empty():
		return fail("Resultado ya registrado")
	var mission = int(p.battle.mission)
	for kind in rules.troops:
		p.army[kind] = clampi(int(survivors.get(kind,0)),0,int(p.battle.army.get(kind,0)))
	if victory:
		p.stats.wins += 1
		if not p.completed.has(mission):
			p.completed.append(mission)
			for r in rules.resources:
				p.resources[r] = mini(capacity(), int(p.resources[r]) + int(rules.missions[mission-1].reward[r]))
	else:
		p.stats.losses += 1
	p.battle = {}
	return save()

func save_failure(message: String) -> bool:
	state = committed.duplicate(true)
	return fail(message)

func save() -> bool:
	var temp = save_path + ".tmp"
	var f = FileAccess.open(temp,FileAccess.WRITE)
	if f == null:
		return save_failure("No se pudo escribir el guardado")
	f.store_string(JSON.stringify(state))
	f.flush()
	f.close()
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path,save_path + ".bak")
	if DirAccess.rename_absolute(temp,save_path) != OK:
		return save_failure("No se pudo confirmar el guardado")
	committed = state.duplicate(true)
	error = ""
	return true

func valid(data: Variant) -> bool:
	if not data is Dictionary or data.get("version") != VERSION or not data.get("profiles") is Array:
		return false
	if data.profiles.size() > 5 or not data.get("active") is String or not data.get("admin") is Dictionary or not data.get("audit") is Array:
		return false
	var ids = []
	for p in data.profiles:
		if not p is Dictionary:
			return false
		for key in ["id","name","created","enabled","resources","last_tick","buildings","army","troop_levels","completed","battle","difficulty","tutorial","stats","settings"]:
			if not p.has(key):
				return false
		if not p.id is String or ids.has(p.id) or not p.name is String or p.name.length() > 24 or not p.enabled is bool:
			return false
		ids.append(p.id)
		if not p.resources is Dictionary or not p.army is Dictionary or not p.buildings is Array or not p.completed is Array or not p.battle is Dictionary:
			return false
		for r in rules.resources:
			if not numeric(p.resources.get(r),0,10000000):
				return false
		for kind in rules.troops:
			if not numeric(p.army.get(kind),0,1000):
				return false
		if not numeric(p.last_tick,0,99999999999) or not p.stats is Dictionary or not p.settings is Dictionary or not numeric(p.tutorial,0,4):
			return false
		for key in ["wins","losses","seconds"]:
			if not numeric(p.stats.get(key),0,1000000000):
				return false
		if not p.settings.get("audio") is bool or not p.settings.get("vibration") is bool or not numeric(p.settings.get("ui_scale"),0.8,1.5) or not p.settings.get("graphics") in ["normal","bajo"]:
			return false
		if not p.difficulty in ["facil","normal","dificil"] or p.buildings.size() > 144:
			return false
		var rects = []
		var building_ids = []
		var headquarters = 0
		for b in p.buildings:
			if not b is Dictionary or not b.get("id") is String or building_ids.has(b.id) or not rules.buildings.has(b.get("kind")):
				return false
			building_ids.append(b.id)
			for k in ["x","y","level","finish"]:
				if not numeric(b.get(k),0,99999999999):
					return false
			if b.level < 1 or b.level > 5:
				return false
			headquarters += int(b.kind == "central")
			var size = int(rules.buildings[b.kind].size)
			var rect = Rect2i(int(b.x),int(b.y),size,size)
			if rect.end.x > 12 or rect.end.y > 12:
				return false
			for other in rects:
				if rect.intersects(other):
					return false
			rects.append(rect)
		if headquarters != 1:
			return false
		for m in p.completed:
			if not numeric(m,1,20):
				return false
		if not p.battle.is_empty():
			if not p.battle.get("id") is String or not numeric(p.battle.get("mission"),1,20) or not p.battle.get("army") is Dictionary:
				return false
			for kind in rules.troops:
				if not numeric(p.battle.army.get(kind),0,1000):
					return false
	return data.active.is_empty() or ids.has(data.active)

func numeric(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

func load_game() -> bool:
	for path in [save_path,save_path + ".bak"]:
		if not FileAccess.file_exists(path):
			continue
		var parser = JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK:
			continue
		var data = parser.data
		if valid(data):
			state = data
			committed = state.duplicate(true)
			# Interrupted battles are losses. Army was reserved before the first frame.
			for p in state.profiles:
				if not p.battle.is_empty():
					p.battle = {}
					p.stats.losses += 1
			tick(now())
			return save()
	return false

func export_backup(path: String) -> bool:
	var f = FileAccess.open(path,FileAccess.WRITE)
	if f == null:
		return fail("No se pudo exportar")
	f.store_string(JSON.stringify(state,"\t"))
	return true

func import_backup(path: String) -> bool:
	if not is_admin():
		return fail("Se requiere administración")
	if not FileAccess.file_exists(path) or FileAccess.get_file_as_bytes(path).size() > 2000000:
		return fail("Archivo ausente o demasiado grande")
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return fail("Respaldo JSON inválido")
	var data = parser.data
	if not valid(data):
		return fail("Respaldo inválido: no se modificó tu partida")
	for p in data.profiles:
		if not p.battle.is_empty():
			p.battle = {}
			p.stats.losses += 1
	state = data
	admin_until = 0
	return save()

func derive_pin(pin: String, salt: PackedByteArray) -> String:
	# PBKDF2-HMAC-SHA256, RFC 8018, one 32-byte block.
	var crypto = Crypto.new()
	var key = pin.to_utf8_buffer()
	var message = salt.duplicate()
	message.append_array(PackedByteArray([0,0,0,1]))
	var u = crypto.hmac_digest(HashingContext.HASH_SHA256,key,message)
	var result = u.duplicate()
	for i in range(99999):
		u = crypto.hmac_digest(HashingContext.HASH_SHA256,key,u)
		for j in range(32):
			result[j] = result[j] ^ u[j]
	return result.hex_encode()

func set_pin(pin: String) -> bool:
	if not state.admin.is_empty() and not is_admin():
		return fail("Se requiere el PIN actual")
	if pin.length() < 6 or pin.length() > 12 or not pin.is_valid_int():
		return fail("El PIN debe tener entre 6 y 12 dígitos")
	var salt = Crypto.new().generate_random_bytes(16)
	state.admin = {"salt":salt.hex_encode(),"hash":derive_pin(pin,salt),"attempts":0,"blocked_until":0}
	admin_until = now() + 300
	return save()

func unlock_admin(pin: String) -> bool:
	if state.admin.is_empty():
		return set_pin(pin)
	if now() < int(state.admin.get("blocked_until",0)):
		return fail("Espera 60 segundos tras cinco intentos")
	var actual = derive_pin(pin,String(state.admin.salt).hex_decode()).to_utf8_buffer()
	if Crypto.new().constant_time_compare(actual,String(state.admin.hash).to_utf8_buffer()):
		admin_until = now() + 300
		state.admin.attempts = 0
		return save()
	state.admin.attempts = int(state.admin.get("attempts",0)) + 1
	if state.admin.attempts >= 5:
		state.admin.blocked_until = now()+60
		state.admin.attempts = 0
	save()
	return fail("PIN incorrecto")

func is_admin() -> bool:
	return admin_until > now()

func admin_action(action: String, value: String) -> bool:
	if not is_admin():
		return fail("Administración bloqueada")
	var p = profile()
	match action:
		"difficulty":
			if not value in ["facil","normal","dificil"]:
				return false
			p.difficulty = value
		"resources":
			for r in rules.resources:
				p.resources[r] = capacity()
		"enabled":
			for target in state.profiles:
				if target.id == value and target.id != state.active:
					target.enabled = not target.enabled
		"reset":
			# Reset the selected profile, retaining its identity and settings.
			var identity = p.id
			var display_name = p.name
			state.profiles.erase(p)
			create_profile(display_name)
			profile().id = identity
			state.active = identity
		_:
			return false
	state.audit.append({"time":now(),"action":action,"value":value,"profile":state.active})
	if state.audit.size() > 500:
		state.audit.pop_front()
	return save()
