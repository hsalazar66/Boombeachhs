class_name IslandBoard
extends Control
signal cell_selected(x: int, y: int)
signal battle_tapped(pos: Vector2)
var game: IslandGame
var battle: IslandBattle
var mode := "base"
var zoom := 1.0
var pan := Vector2.ZERO
var drag_origin := Vector2.ZERO
var dragging := false
var touches: Dictionary = {}
var selected := ""
var font = ThemeDB.fallback_font
const COLORS = {"central":Color("f3c366"),"aserradero":Color("65c291"),"mina":Color("e7be59"),"cantera":Color("a4b6c9"),"lancha":Color("54bad0"),"almacen":Color("b78c69"),"radar":Color("91bde3"),"armeria":Color("cc9882"),"canon":Color("d18068"),"mortero":Color("d9a875"),"torre":Color("c5b499"),"ralentizador":Color("8bcada")}

func _ready():
	custom_minimum_size = Vector2(540,420)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

func base_origin() -> Vector2:
	return Vector2(size.x/2,85) + pan

func iso(x: float, y: float) -> Vector2:
	return base_origin() + Vector2((x-y)*24,(x+y)*13)*zoom

func battle_offset() -> Vector2:
	return (size-Vector2(768,480)*battle_scale())/2

func battle_scale() -> float:
	return minf(size.x/768,size.y/480)

func _gui_input(event):
	if event is InputEventMagnifyGesture:
		zoom = clampf(zoom * event.factor,0.65,1.5)
		queue_redraw()
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
		else:
			touches.erase(event.index)
	if event is InputEventScreenDrag and touches.has(event.index):
		if touches.size() == 2:
			var keys = touches.keys()
			var old = touches[keys[0]].distance_to(touches[keys[1]])
			touches[event.index] = event.position
			var current = touches[keys[0]].distance_to(touches[keys[1]])
			if old > 1:
				zoom = clampf(zoom*current/old,0.65,1.5)
		else:
			pan += event.relative
		queue_redraw()
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = minf(1.5,zoom+0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = maxf(0.65,zoom-0.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				drag_origin = event.position
				dragging = false
			elif not dragging:
				if mode == "base":
					var local = (event.position-base_origin())/zoom
					cell_selected.emit(int(floor((local.x/24+local.y/13)/2)), int(floor((local.y/13-local.x/24)/2)))
				else:
					battle_tapped.emit((event.position-battle_offset())/battle_scale())
		queue_redraw()
	if event is InputEventMouseMotion and event.button_mask == MOUSE_BUTTON_MASK_LEFT:
		if event.position.distance_to(drag_origin) > 8:
			dragging = true
		if dragging and mode == "base":
			pan += event.relative
			queue_redraw()

func _draw():
	draw_rect(Rect2(Vector2.ZERO,size),Color("0b303e"))
	# Procedural ocean; no licensed game assets.
	for y in range(18):
		for x in range(24):
			var point = Vector2(x*48+((y%2)*20),y*36+10)
			draw_line(point,point+Vector2(16,0),Color(0.2,0.52,0.61,0.16),1)
	if mode == "base":
		draw_base()
	elif battle != null:
		draw_battle()

func draw_base():
	for y in range(12):
		for x in range(12):
			var points = PackedVector2Array([iso(x,y),iso(x+1,y),iso(x+1,y+1),iso(x,y+1)])
			draw_colored_polygon(points,Color("a5b47a") if y > 9 else Color("527d60"))
			draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),Color(0.6,0.8,0.6,0.12),1)
	if game == null or game.profile().is_empty():
		return
	var sorted = game.profile().buildings.duplicate()
	sorted.sort_custom(func(a,b): return a.x+a.y < b.x+b.y)
	for b in sorted:
		var config = game.rules.buildings[b.kind]
		var s = float(config.size)
		var a = iso(b.x,b.y)
		var right = iso(b.x+s,b.y)
		var bottom = iso(b.x+s,b.y+s)
		var left = iso(b.x,b.y+s)
		var height = Vector2(0,(30+int(b.level)*5)*zoom)
		var color = COLORS[b.kind]
		draw_colored_polygon(PackedVector2Array([left,bottom,bottom-height,left-height]),color.darkened(0.35))
		draw_colored_polygon(PackedVector2Array([right,bottom,bottom-height,right-height]),color.darkened(0.2))
		draw_colored_polygon(PackedVector2Array([a-height,right-height,bottom-height,left-height]),color)
		var center = iso(b.x+s/2,b.y+s/2)-height
		draw_circle(center,7*zoom,Color("203442"))
		draw_string(font,center+Vector2(-4,5),str(int(b.level)),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
		if b.id == selected:
			draw_arc(center,26*zoom,0,TAU,40,Color("fff2ab"),3)
		if int(b.finish) > 0:
			draw_string(font,center+Vector2(-30,-24),str(maxi(0,int(b.finish)-game.now()))+" s",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("fff2ab"))
	draw_string(font,Vector2(18,size.y-24),"Toca un edificio · arrastra para explorar · pellizca para ampliar",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("c0d9d6"))

func draw_battle():
	var offset = battle_offset()
	var s = battle_scale()
	var land = Rect2(offset+Vector2(40,20)*s,Vector2(688,390)*s)
	draw_style_box(island_style(),land)
	draw_rect(Rect2(offset+Vector2(40,390)*s,Vector2(688,80)*s),Color("d6c897"))
	draw_string(font,offset+Vector2(220,450)*s,"PLAYA · TOCA PARA DESEMBARCAR",HORIZONTAL_ALIGNMENT_LEFT,-1,int(16*s),Color("405545"))
	for b in battle.buildings:
		var point = offset+b.pos*s
		if b.hp <= 0:
			draw_circle(point,18*s,Color("696b5c"))
			continue
		var color = COLORS[b.kind]
		draw_rect(Rect2(point-Vector2(22,22)*s,Vector2(44,44)*s),color.darkened(0.2))
		draw_rect(Rect2(point-Vector2(18,28)*s,Vector2(36,36)*s),color)
		draw_string(font,point+Vector2(-24,-40)*s,"CG" if b.kind == "central" else game.rules.buildings[b.kind].name,HORIZONTAL_ALIGNMENT_LEFT,-1,int(13*s),Color.WHITE)
		health(point+Vector2(-24,28)*s,48*s,b.hp/b.max_hp)
	for t in battle.troops:
		if t.hp <= 0:
			continue
		var point = offset+t.pos*s
		var color = Color("d8f0cf") if t.kind == "infanteria" else Color("78d6ee")
		draw_circle(point,8*s,color)
		draw_circle(point+Vector2(0,-6)*s,4*s,Color("304c65"))
		health(point+Vector2(-10,13)*s,20*s,t.hp/t.max_hp)
	for shot in battle.shots:
		draw_line(offset+shot.from*s,offset+shot.to*s,Color("ffe9a5"),2)
		if shot.radius > 0:
			draw_arc(offset+shot.to*s,shot.radius*s,0,TAU,32,Color("ffe9a5"),2)
	if battle.elapsed < battle.flare_until:
		draw_circle(offset+battle.flare*s,12*s,Color("e88a6a"))

func health(pos: Vector2,width: float,ratio: float):
	draw_rect(Rect2(pos,Vector2(width,4)),Color("273b40"))
	draw_rect(Rect2(pos,Vector2(width*clampf(ratio,0,1),4)),Color("8bd4a1"))

func island_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("527d60")
	style.set_corner_radius_all(60)
	return style
