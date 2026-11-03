extends SceneTree
var checks := 0
var failures := 0

func check(condition: bool, text: String):
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: "+text)

func _initialize():
	var game = IslandGame.new("user://test-state.json")
	check(game.create_profile("Ana"),"create first profile")
	check(game.valid(game.state),"new save conforms to schema")
	check(not game.create_profile("Otro"),"additional profile requires administration")
	check(game.set_pin("123456"),"PIN setup")
	check(not JSON.stringify(game.state.admin).contains("123456"),"PIN not persisted in clear")
	game.admin_until = 0
	check(not game.unlock_admin("999999"),"wrong PIN rejected")
	check(game.unlock_admin("123456"),"PBKDF2 PIN verification")
	var first_id = game.state.active
	var before = game.profile().resources.oro
	check(not game.pay({"oro":999999}),"reject unaffordable costs")
	check(game.profile().resources.oro == before,"failed purchase leaves balance")
	check(not game.build("canon",5,3),"overlap rejected")
	check(not game.build("canon",12,0),"out of grid rejected")
	check(game.build("canon",0,0),"valid building placement")
	check(game.profile().resources.oro == before-80,"building charged exactly once")
	check(not game.move_building(game.profile().buildings[-1].id,5,3),"move overlap rejected")
	game.profile().resources.madera = 0
	var last = int(game.profile().last_tick)
	game.tick(last+999999)
	check(game.profile().resources.madera == game.capacity(),"offline production respects storage")
	game.profile().resources.madera = 0
	game.tick(last-100)
	check(game.profile().resources.madera == 0,"clock rollback yields no production")
	game.profile().last_tick = game.now()
	game.admin_action("resources","")
	check(game.upgrade("hq"),"HQ improvement begins")
	check(not game.upgrade("hq"),"cannot double charge pending upgrade")
	game.tick(game.now()+31)
	check(game.hq_level() == 2,"timed improvement completes")
	check(game.train("pesado"),"train unlocked heavy")
	check(not game.train("pesado"),"boat capacity enforced")
	check(not game.start_battle(2),"locked mission rejected")
	check(game.start_battle(1),"mission starts")
	check(game.profile().army.infanteria == 0,"army reserved on start")
	check(not game.start_battle(1),"double battle start rejected")
	check(game.finish_battle(true,{"infanteria":4,"pesado":1}),"victory settled")
	var reward_balance = game.profile().resources.oro
	check(not game.finish_battle(true,{}),"duplicate result rejected")
	check(game.profile().resources.oro == reward_balance,"reward not duplicated")
	check(game.unlocked(2),"next mission unlocked")
	game.profile().resources.oro = 100
	game.start_battle(1)
	game.finish_battle(true,{"infanteria":4})
	check(game.profile().resources.oro == 85,"replay gives no duplicate reward")
	check(game.create_profile("Luis"),"admin creates independent profile")
	check(game.profile().completed.is_empty(),"profile progress isolated")
	check(game.select_profile(first_id),"profile selection")
	check(game.profile().completed.has(1),"first profile preserved")
	check(game.export_backup("user://test-export.json"),"export backup")
	var invalid = game.state.duplicate(true)
	invalid.profiles[0].buildings[0].x = 99
	check(not game.valid(invalid),"malformed placement rejected")
	invalid = game.state.duplicate(true)
	invalid.profiles[0].resources.oro = -1
	check(not game.valid(invalid),"negative resources rejected")
	invalid = game.state.duplicate(true)
	invalid.profiles[0].settings = {}
	check(not game.valid(invalid),"invalid settings rejected")
	check(game.import_backup("user://test-export.json"),"valid backup restores")
	check(not game.is_admin(),"restore requires new authentication")
	game.start_battle(1)
	var restored = IslandGame.new("user://test-state.json")
	check(restored.load_game(),"load durable save")
	check(restored.profile().battle.is_empty(),"interrupted attack resolved")
	check(restored.profile().army.infanteria == 0,"interrupted troops not duplicated")
	var file = FileAccess.open("user://test-state.json",FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	check(restored.load_game(),"corruption recovers backup")
	# Combat logic exercises movement around solid footprints, all abilities, and single outcomes.
	var army = {"infanteria":10,"pesado":0,"tirador":0,"vehiculo":0}
	var mission = game.rules.missions[0].duplicate(true)
	var sim = IslandBattle.new(game.rules,mission,army,"facil")
	check(not sim.deploy("infanteria",Vector2(300,100)),"landing restricted to beach")
	for i in range(10):
		check(sim.deploy("infanteria",Vector2(300+i*10,430)),"landing troops")
	check(sim.ability("curacion",sim.troops[0].pos),"healing ability")
	check(sim.ability("bengala",Vector2(480,330)),"flare order")
	check(sim.ability("artilleria",Vector2(230,210)),"artillery ability")
	var start_pos = sim.troops[0].pos
	for i in range(100):
		sim.step(0.1)
	check(sim.troops[0].pos.distance_to(start_pos) > 20,"troops navigate toward defenses")
	for i in range(2600):
		sim.step(0.1)
		if not sim.result.is_empty():
			break
	check(not sim.result.is_empty(),"battle terminates by objective, elimination or timer")
	var final_result = sim.result
	sim.step(0.1)
	check(sim.result == final_result,"combat result immutable")
	var timeout = IslandBattle.new(game.rules,mission,army)
	for i in range(410):
		timeout.step(0.1)
	check(timeout.result == "defeat","no landing times out")
	var victory = IslandBattle.new(game.rules,mission,army)
	victory.deploy("infanteria",Vector2(380,430))
	victory.energy = 100
	for i in range(10):
		victory.ability("artilleria",Vector2(384,100))
	check(victory.result == "victory","HQ destruction wins")
	check(not victory.ability("artilleria",Vector2(384,100)),"finished battles reject new hits")
	print("TESTS: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
