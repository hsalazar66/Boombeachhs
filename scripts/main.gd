extends Control

var game = IslandGame.new()
var board: IslandBoard
var body: HBoxContainer
var panel: VBoxContainer
var hud: Label
var notice: Label
var screen := "base"
var selected := ""
var build_kind := ""
var moving := false
var mission_id := 1
var battle: IslandBattle
var battle_status: Label
var selected_troop := "infanteria"
var selected_ability := ""
var elapsed_save := 0.0
var result_committed := false
var backup_dialog: FileDialog
var tutorial: Label

func _ready():
	game.load_game()
	setup_theme()
	if not game.profile().is_empty():
		theme.default_font_size = int(17*game.profile().settings.ui_scale)
	show_shell()
	if game.profile().is_empty():
		profiles()
	else:
		base()

func setup_theme():
	var t = Theme.new()
	t.default_font_size = 17
	t.set_color("font_color","Label",Color("e2ede7"))
	for style_name in ["normal","hover","pressed","disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = {"normal":Color("244956"),"hover":Color("326474"),"pressed":Color("3b797b"),"disabled":Color("24353d")}[style_name]
		style.set_corner_radius_all(9)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		t.set_stylebox(style_name,"Button",style)
	t.set_color("font_color","Button",Color("e8eee2"))
	t.set_constant("separation","VBoxContainer",10)
	t.set_constant("separation","HBoxContainer",14)
	theme = t

func clear(node: Node):
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func show_shell():
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,20)
	add_child(margin)
	var root = VBoxContainer.new()
	margin.add_child(root)
	var top = HBoxContainer.new()
	root.add_child(top)
	var brand = Label.new()
	brand.text = "◈  ARCHIPIÉLAGO LIBRE"
	brand.add_theme_font_size_override("font_size",26)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(brand)
	hud = Label.new()
	top.add_child(hud)
	var nav = HBoxContainer.new()
	root.add_child(nav)
	for item in [["Base",base],["Ejército",army],["Campaña",campaign],["Perfiles",profiles],["Administración",admin],["Ajustes",settings]]:
		button(nav,item[0],item[1])
	body = HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)
	notice = Label.new()
	notice.text = "SIN CONEXIÓN  ·  Tu progreso permanece en este dispositivo"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(notice)
	backup_dialog = FileDialog.new()
	backup_dialog.access = FileDialog.ACCESS_FILESYSTEM
	backup_dialog.use_native_dialog = true
	backup_dialog.filters = PackedStringArray(["*.json ; Respaldo de Archipiélago"])
	backup_dialog.file_selected.connect(on_backup_file)
	add_child(backup_dialog)

func button(parent: Node,text: String,action: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.pressed.connect(func():
		if battle != null and not battle.result.is_empty() and not result_committed:
			return
		action.call())
	parent.add_child(b)
	return b

func label(parent: Node,text: String,font_size := 17) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size",font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l

func prepare(title: String,show_board := false) -> bool:
	if battle != null and not result_committed:
		message("Finaliza el ataque o retírate antes de cambiar de pantalla")
		return false
	clear(body)
	board = null
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 340 if show_board else 540
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if not show_board:
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	panel = VBoxContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	label(panel,title,27)
	if show_board:
		board = IslandBoard.new()
		board.game = game
		board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		board.size_flags_vertical = Control.SIZE_EXPAND_FILL
		body.add_child(board)
		board.cell_selected.connect(on_cell)
		board.battle_tapped.connect(on_battle_tap)
	return true

func need_profile() -> bool:
	if game.profile().is_empty():
		profiles()
		return false
	return true

func message(text: String):
	notice.text = text

func feedback(ok: bool,success := "Guardado"):
	message(success if ok else game.error)

func cost_text(cost: Dictionary) -> String:
	var parts = []
	for r in cost:
		parts.append(str(int(cost[r]))+" "+r)
	return " · ".join(parts)

func base():
	if not need_profile() or not prepare("Tu isla",true):
		return
	screen = "base"
	build_kind = ""
	moving = false
	label(panel,game.profile().name + " · Cuartel " + str(game.hq_level()))
	label(panel,"Selecciona un edificio para consultar su mejora. Para construir, elige una estructura y toca una celda libre.",15)
	button(panel,"Construir",construction)
	button(panel,"Simular defensa",defense_preview)
	if not selected.is_empty():
		for b in game.profile().buildings:
			if b.id == selected:
				board.selected = selected
				label(panel,game.rules.buildings[b.kind].name+" · Nivel "+str(int(b.level)),22)
				label(panel,"Mejora: "+cost_text(game.upgrade_cost(b))+"\nDuración: "+str(int(game.rules.buildings[b.kind].seconds)*int(b.level))+" s",15)
				button(panel,"Confirmar mejora",func(): feedback(game.upgrade(selected)); base())
				button(panel,"Mover · luego toca el destino",func(): moving = true; message("Selecciona la nueva celda"))
	tutorial = label(panel,"",16)
	update_tutorial()
	if game.profile().tutorial < 3:
		button(panel,"Entendido · siguiente paso",func():
			game.profile().tutorial = mini(3,int(game.profile().tutorial)+1)
			game.save()
			update_tutorial())

func update_tutorial():
	if is_instance_valid(tutorial):
		var steps = ["1 / 3 · Construye una mina o un aserradero para producir recursos.","2 / 3 · Abre Ejército y entrena infantería. Cada lancha aporta capacidad.","3 / 3 · Abre Campaña, explora la primera isla y desembarca en la playa.","Consejo · destruye el cuartel para ganar. Las recompensas de cada isla se reciben una sola vez."]
		tutorial.text = steps[int(game.profile().tutorial)]

func construction():
	if not prepare("Construcción",true):
		return
	screen = "base"
	for kind in game.rules.buildings:
		if kind == "central":
			continue
		var c = game.rules.buildings[kind]
		var b = button(panel,c.name+"\n"+cost_text(c.cost),func(): build_kind = kind; message("Toca una celda libre para construir "+c.name))
		b.disabled = game.hq_level() < int(c.unlock)
	button(panel,"Volver",base)

func on_cell(x: int,y: int):
	if not build_kind.is_empty():
		feedback(game.build(build_kind,x,y),"Edificio construido")
		if game.error.is_empty():
			build_kind = ""
		board.queue_redraw()
		return
	if moving:
		feedback(game.move_building(selected,x,y),"Edificio movido")
		moving = false
		base()
		return
	selected = ""
	for b in game.profile().buildings:
		if Rect2i(int(b.x),int(b.y),int(game.rules.buildings[b.kind].size),int(game.rules.buildings[b.kind].size)).has_point(Vector2i(x,y)):
			selected = b.id
	base()

func army():
	if not need_profile() or not prepare("Ejército y transporte"):
		return
	screen = "army"
	label(panel,"Capacidad: "+str(game.occupied_transport())+" / "+str(game.transport())+" · El entrenamiento es inmediato en esta versión.")
	for kind in game.rules.troops:
		var t = game.rules.troops[kind]
		label(panel,t.name+" · Disponibles: "+str(int(game.profile().army[kind]))+" · Vida "+str(t.hp)+" · Daño "+str(t.damage)+" · Espacio "+str(t.space))
		var b = button(panel,"Entrenar · "+cost_text(t.cost),func(): feedback(game.train(kind),"Tropa entrenada"); army())
		b.disabled = game.hq_level() < int(t.unlock)
	label(panel,"Construye o mejora lanchas para ampliar el ejército. El cuartel desbloquea las tropas.",15)

func campaign():
	if not need_profile() or not prepare("Campaña del archipiélago"):
		return
	screen = "campaign"
	label(panel,"20 islas · Explorar no cuesta recursos · Recompensas únicas")
	for m in game.rules.missions:
		var completed = game.profile().completed.has(m.id)
		var b = button(panel,("✓  " if completed else "◈  ")+m.name+" · "+("Completada" if completed else "Explorar"),func(): mission_id = int(m.id); scout())
		b.disabled = not game.unlocked(int(m.id))

func scout():
	if not prepare("Exploración",true):
		return
	screen = "scout"
	var m = game.rules.missions[mission_id-1]
	board.mode = "scout"
	board.battle = IslandBattle.new(game.rules,m,game.profile().army,game.profile().difficulty)
	label(panel,m.name,22)
	label(panel,"Cuartel enemigo: "+str(int(m.hq))+"\nDefensas: "+str(int(m.defenses)))
	label(panel,"Recompensa: "+("ya cobrada" if game.profile().completed.has(mission_id) else cost_text(m.reward)))
	label(panel,"Costo del ataque: "+str(int(m.attack_cost))+" oro\n40 s para desembarcar · 4 min de batalla. Destruye el CG para ganar. Cerrar la aplicación cuenta como derrota.",16)
	button(panel,"Atacar · confirmar costo",begin_battle)
	button(panel,"Volver al mapa",campaign)

func begin_battle():
	if not game.start_battle(mission_id):
		feedback(false)
		return
	# Prepare the screen before marking a live battle.
	prepare("Desembarco",true)
	battle = IslandBattle.new(game.rules,game.rules.missions[mission_id-1],game.profile().battle.army,game.profile().difficulty)
	result_committed = false
	screen = "battle"
	board.mode = "battle"
	board.battle = battle
	battle_status = label(panel,"",22)
	label(panel,"Selecciona una tropa y toca la playa. Cada toque desembarca una unidad.",15)
	for kind in game.rules.troops:
		button(panel,game.rules.troops[kind].name,func(): selected_troop = kind; selected_ability = ""; message("Desembarca "+game.rules.troops[kind].name))
	for kind in game.rules.abilities:
		var a = game.rules.abilities[kind]
		button(panel,a.name+" · "+str(int(a.energy))+" energía",func(): selected_ability = kind; message("Toca el objetivo de "+a.name))
	button(panel,"Retirada",func(): confirm("¿Retirarte? Regresarán las tropas supervivientes; no habrá recompensa.",func(): battle.result = "defeat"))

func on_battle_tap(pos: Vector2):
	if battle == null or screen != "battle":
		return
	if not selected_ability.is_empty():
		if battle.ability(selected_ability,pos):
			selected_ability = ""
		else:
			message("Energía insuficiente, objetivo inválido o aún no has desembarcado")
	else:
		if not battle.deploy(selected_troop,pos):
			message("Toca la playa y comprueba que quedan tropas de este tipo")

func finish_battle():
	var won = battle.result == "victory"
	var survivors = battle.survivors()
	if not game.finish_battle(won,survivors):
		message(game.error+" · Reintentando guardar el resultado")
		return
	result_committed = true
	var remaining = battle.alive_count()+battle.reserve_count()
	battle = null
	prepare("Victoria" if won else "Derrota")
	screen = "result"
	label(panel,"Isla "+str(mission_id)+" · "+str(remaining)+" supervivientes",24)
	label(panel,"El resultado está guardado. Las islas completadas pueden repetirse para practicar; sus recompensas no se duplican.")
	button(panel,"Volver a la base",base)
	button(panel,"Continuar campaña",campaign)

func profiles():
	if not prepare("Perfiles locales"):
		return
	screen = "profiles"
	label(panel,"Hasta cinco partidas independientes en este dispositivo.")
	for p in game.state.profiles:
		var row = HBoxContainer.new()
		panel.add_child(row)
		var b = button(row,p.name+(" · activo" if p.id == game.state.active else ""),func(): feedback(game.select_profile(p.id)); selected = ""; base())
		b.disabled = not p.enabled
		label(row,"Victorias: "+str(int(p.stats.wins))+" · "+str(int(p.stats.seconds)/60)+" min")
	var name_edit = LineEdit.new()
	name_edit.placeholder_text = "Nombre del nuevo perfil"
	name_edit.max_length = 24
	panel.add_child(name_edit)
	button(panel,"Crear perfil",func(): feedback(game.create_profile(name_edit.text)); if not game.profile().is_empty(): base())
	if not game.state.profiles.is_empty() and not game.is_admin():
		label(panel,"Para crear perfiles adicionales, configura o introduce el PIN en Administración.",15)

func admin():
	if not prepare("Administración local"):
		return
	screen = "admin"
	if not game.is_admin():
		label(panel,"Crea un PIN de 6 a 12 dígitos." if game.state.admin.is_empty() else "Introduce el PIN. La sesión dura cinco minutos.")
		var pin = LineEdit.new()
		pin.secret = true
		pin.max_length = 12
		panel.add_child(pin)
		button(panel,"Desbloquear",func(): feedback(game.unlock_admin(pin.text),"Administración desbloqueada"); admin())
		return
	label(panel,"Administración desbloqueada · Los cambios quedan registrados")
	if not game.profile().is_empty():
		label(panel,"Perfil: "+game.profile().name)
		for difficulty in ["facil","normal","dificil"]:
			button(panel,"Dificultad: "+difficulty,func(): feedback(game.admin_action("difficulty",difficulty)))
		button(panel,"Pruebas · llenar recursos",func(): feedback(game.admin_action("resources","")))
		button(panel,"Reiniciar esta partida",func(): confirm("¿Borrar el progreso de "+game.profile().name+"?",func(): feedback(game.admin_action("reset","")); admin()))
	for p in game.state.profiles:
		if p.id != game.state.active:
			button(panel,("Desactivar " if p.enabled else "Activar ")+p.name,func(): feedback(game.admin_action("enabled",p.id)); admin())
	button(panel,"Exportar respaldo general",func(): open_backup(false))
	button(panel,"Restaurar respaldo",func(): open_backup(true))
	button(panel,"Bloquear administración",func(): game.admin_until = 0; admin())
	label(panel,"Registro de acciones: "+str(game.state.audit.size()),20)
	var recent = game.state.audit.slice(maxi(0,game.state.audit.size()-8))
	recent.reverse()
	for entry in recent:
		label(panel,Time.get_datetime_string_from_unix_time(int(entry.time))+" · "+entry.action+" · "+entry.value,14)

func open_backup(importing: bool):
	backup_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE if importing else FileDialog.FILE_MODE_SAVE_FILE
	backup_dialog.current_file = "archipielago-respaldo.json"
	backup_dialog.set_meta("importing",importing)
	backup_dialog.popup_centered_ratio(0.8)

func on_backup_file(path: String):
	if not game.is_admin():
		feedback(false)
		return
	if backup_dialog.get_meta("importing"):
		confirm("¿Reemplazar todos los perfiles con este respaldo?",func(): feedback(game.import_backup(path),"Respaldo restaurado"); admin())
	else:
		feedback(game.export_backup(path),"Respaldo exportado")

func settings():
	if not need_profile() or not prepare("Ajustes"):
		return
	screen = "settings"
	for key in ["audio","vibration"]:
		var check = CheckButton.new()
		check.text = "Audio" if key == "audio" else "Vibración"
		check.button_pressed = game.profile().settings[key]
		check.toggled.connect(func(on): game.profile().settings[key] = on; game.save())
		panel.add_child(check)
	label(panel,"Interfaz")
	for scale_value in [1.0,1.2,1.4]:
		button(panel,str(int(scale_value*100))+" %",func(): game.profile().settings.ui_scale = scale_value; theme.default_font_size = int(17*scale_value); game.save())
	for quality in ["normal","bajo"]:
		button(panel,"Gráficos: "+quality,func(): game.profile().settings.graphics = quality; game.save())
	label(panel,"Los respaldos se administran desde Administración. No hay publicidad, compras ni conexiones a servidores.")

func defense_preview():
	confirm("Simular una incursión contra tu base. Regla: suma de nivel × daño de defensas frente a 60 × nivel del cuartel. No se pierden recursos.",func():
		var power = 0.0
		for b in game.profile().buildings:
			power += float(game.rules.buildings[b.kind].get("damage",0))*int(b.level)
		message("Defensa superada: "+str(int(power))+" puntos" if power >= 60*game.hq_level() else "Defensa insuficiente: "+str(int(power))+" / "+str(60*game.hq_level())+". Construye más defensas."))

func confirm(text: String,action: Callable):
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = text
	dialog.title = "Confirmar"
	dialog.ok_button_text = "Confirmar"
	dialog.cancel_button_text = "Cancelar"
	dialog.confirmed.connect(func(): action.call(); dialog.queue_free())
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(520,180))

func _process(delta: float):
	if game.profile().is_empty():
		return
	hud.text = "ORO %d   MADERA %d   PIEDRA %d   / %d" % [game.profile().resources.oro,game.profile().resources.madera,game.profile().resources.piedra,game.capacity()]
	elapsed_save += delta
	if elapsed_save >= 1:
		game.tick(game.now())
		game.profile().stats.seconds += 1
		elapsed_save = 0
		game.save()
		if is_instance_valid(board):
			board.queue_redraw()
	if battle != null and screen == "battle":
		battle.step(delta)
		if is_instance_valid(battle_status):
			battle_status.text = ("Desembarco: "+str(maxi(0,40-int(battle.deployment)))+" s" if battle.phase == "deployment" else "Tiempo: "+str(maxi(0,240-int(battle.elapsed)))+" s")+"\nEnergía: "+str(battle.energy)+" · Reserva: "+str(battle.reserve_count())
		if is_instance_valid(board):
			board.queue_redraw()
		if not battle.result.is_empty() and not result_committed:
			finish_battle()

func _notification(what):
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		game.save()
