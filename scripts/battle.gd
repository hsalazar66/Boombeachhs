class_name IslandBattle
extends RefCounted

var rules: Dictionary
var buildings: Array = []
var troops: Array = []
var reserve: Dictionary
var initial: Dictionary
var energy := 12
var elapsed := 0.0
var deployment := 0.0
var phase := "deployment"
var result := ""
var flare := Vector2(-1,-1)
var flare_until := 0.0
var shots: Array = []
var difficulty := 1.0
var astar := AStarGrid2D.new()
const CELL = 24
const BOARD = Vector2(768,480)

func _init(config: Dictionary, mission: Dictionary, army: Dictionary, mode := "normal", levels: Dictionary = {}):
	rules = config
	reserve = army.duplicate()
	initial = army.duplicate()
	difficulty = {"facil":0.75,"normal":1.0,"dificil":1.3}[mode]
	astar.region = Rect2i(0,0,32,20)
	astar.cell_size = Vector2(CELL,CELL)
	astar.offset = Vector2(CELL/2.0,CELL/2.0)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	add_building("central",Vector2(384,100),float(mission.hq))
	var spots = [Vector2(230,210),Vector2(530,210),Vector2(380,275),Vector2(140,120),Vector2(620,120),Vector2(170,300),Vector2(590,300),Vector2(385,200)]
	var kinds = ["canon","torre","mortero","ralentizador"]
	for i in range(int(mission.defenses)):
		add_building(kinds[i % 4], spots[i], 1.0 + (float(mission.id)-1)*0.10)
	for kind in reserve:
		# Store configured levels without coupling rendering to progression.
		if not levels.has(kind):
			levels[kind] = 1

func add_building(kind: String, pos: Vector2, level: float):
	var config = rules.buildings[kind]
	var hp = float(config.hp) * level * difficulty
	buildings.append({"kind":kind,"pos":pos,"hp":hp,"max_hp":hp,"cooldown":0.0,"level":level})
	set_obstacle(pos,true)

func set_obstacle(pos: Vector2, solid: bool):
	var center = Vector2i(pos / CELL)
	for x in range(center.x-1,center.x+2):
		for y in range(center.y-1,center.y+2):
			if astar.is_in_boundsv(Vector2i(x,y)):
				astar.set_point_solid(Vector2i(x,y),solid)

func deploy(kind: String, pos: Vector2) -> bool:
	if not result.is_empty() or not reserve.has(kind) or reserve[kind] <= 0 or pos.y < 390 or pos.y > 470 or pos.x < 24 or pos.x > 744:
		return false
	var config = rules.troops[kind]
	troops.append({"kind":kind,"pos":pos,"hp":float(config.hp),"max_hp":float(config.hp),"cooldown":0.0,"slow_until":0.0})
	reserve[kind] -= 1
	# First landing starts the four-minute battle.
	phase = "battle"
	return true

func ability(kind: String, pos: Vector2) -> bool:
	if phase != "battle" or not result.is_empty() or not rules.abilities.has(kind):
		return false
	var config = rules.abilities[kind]
	if energy < int(config.energy):
		return false
	energy -= int(config.energy)
	match kind:
		"artilleria":
			for b in buildings:
				if b.hp > 0 and b.pos.distance_to(pos) < float(config.radius):
					b.hp -= float(config.damage)
			shots.append({"from":pos,"to":pos,"ttl":0.6,"radius":float(config.radius)})
		"curacion":
			for t in troops:
				if t.hp > 0 and t.pos.distance_to(pos) < float(config.radius):
					t.hp = minf(t.max_hp,t.hp + float(config.heal))
		"bengala":
			var cell = Vector2i(pos / CELL)
			if not astar.is_in_boundsv(cell) or astar.is_point_solid(cell):
				energy += int(config.energy)
				return false
			flare = pos
			flare_until = elapsed + float(config.seconds)
	cleanup()
	return true

func step(delta: float):
	if not result.is_empty():
		return
	# Fixed small steps prevent tunneling and frame-dependent attack bursts.
	var remaining = minf(delta,0.25)
	while remaining > 0:
		var dt = minf(remaining,0.05)
		update_step(dt)
		remaining -= dt
		if not result.is_empty():
			break

func update_step(dt: float):
	for shot in shots:
		shot.ttl -= dt
	shots = shots.filter(func(s): return s.ttl > 0)
	if phase == "deployment":
		deployment += dt
		if deployment >= float(rules.deployment_seconds):
			result = "defeat"
		return
	elapsed += dt
	for t in troops:
		if t.hp <= 0:
			continue
		t.cooldown = maxf(0,t.cooldown-dt)
		var target = nearest_building(t.pos)
		if target.is_empty():
			continue
		var config = rules.troops[t.kind]
		var directing = elapsed < flare_until and t.pos.distance_to(flare) > 15
		if not directing and t.pos.distance_to(target.pos) <= float(config.range) + 28:
			if t.cooldown <= 0:
				target.hp -= float(config.damage)
				t.cooldown = float(config.cooldown)
				shots.append({"from":t.pos,"to":target.pos,"ttl":0.12,"radius":0.0})
		else:
			var goal = flare if directing else reachable_edge(t.pos,target.pos)
			var start = Vector2i(t.pos / CELL)
			var end = Vector2i(goal / CELL)
			if astar.is_in_boundsv(start) and astar.is_in_boundsv(end) and not astar.is_point_solid(start) and not astar.is_point_solid(end):
				var path = astar.get_point_path(start,end)
				if path.size() > 1:
					var speed = float(config.speed) * (0.45 if elapsed < t.slow_until else 1.0)
					t.pos = t.pos.move_toward(path[1],speed*dt)
	for b in buildings:
		if b.hp <= 0 or b.kind == "central":
			continue
		b.cooldown = maxf(0,b.cooldown-dt)
		var config = rules.buildings[b.kind]
		var target = nearest_troop(b.pos,float(config.range))
		if not target.is_empty() and b.cooldown <= 0:
			b.cooldown = float(config.cooldown)
			shots.append({"from":b.pos,"to":target.pos,"ttl":0.18,"radius":float(config.get("splash",0))})
			for t in troops:
				if t.hp > 0 and (t == target or (config.has("splash") and t.pos.distance_to(target.pos) < float(config.splash))):
					t.hp -= float(config.damage) * difficulty
					if config.get("slow",false):
						t.slow_until = elapsed + 2
	cleanup()
	if result.is_empty() and (elapsed >= float(rules.battle_seconds) or (alive_count() == 0 and reserve_count() == 0)):
		result = "defeat"

func reachable_edge(from: Vector2, target: Vector2) -> Vector2:
	var center = Vector2i(target / CELL)
	var best = from
	var distance = INF
	for x in range(center.x-2,center.x+3):
		for y in range(center.y-2,center.y+3):
			var cell = Vector2i(x,y)
			if astar.is_in_boundsv(cell) and not astar.is_point_solid(cell):
				var pos = Vector2(cell)*CELL + Vector2.ONE*CELL/2.0
				if from.distance_squared_to(pos) < distance:
					distance = from.distance_squared_to(pos)
					best = pos
	return best

func nearest_building(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var distance = INF
	for b in buildings:
		if b.hp > 0 and pos.distance_squared_to(b.pos) < distance:
			distance = pos.distance_squared_to(b.pos)
			best = b
	return best

func nearest_troop(pos: Vector2, radius: float) -> Dictionary:
	var best: Dictionary = {}
	var distance = radius*radius
	for t in troops:
		if t.hp > 0 and pos.distance_squared_to(t.pos) < distance:
			distance = pos.distance_squared_to(t.pos)
			best = t
	return best

func cleanup():
	for b in buildings:
		if b.hp <= 0 and not b.get("destroyed",false):
			b.destroyed = true
			energy += 3
			set_obstacle(b.pos,false)
			if b.kind == "central":
				result = "victory"

func alive_count() -> int:
	return troops.filter(func(t): return t.hp > 0).size()

func reserve_count() -> int:
	var count = 0
	for kind in reserve:
		count += int(reserve[kind])
	return count

func survivors() -> Dictionary:
	var counts = reserve.duplicate()
	for t in troops:
		if t.hp > 0:
			counts[t.kind] += 1
	return counts
