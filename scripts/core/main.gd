extends Node3D
## Cena principal: monta a escola (hub) ou a fase, o grupo, a câmera e o HUD.
## Game.mode escolhe qual; trocar de modo recarrega a cena.

const FENIX_STATS: FenixStats = preload("res://data/fenix.tres")
const FEIXE_STATS: FeixeStats = preload("res://data/feixe.tres")

var level: PostoVigia
var party: Party
var rig: CameraRig
var hud: HUD
var fenix: Fenix
var feixe: Feixe
var _rescued_this_run: bool = false
var _card: MissionCard


func _ready() -> void:
	Game.reset_run()
	get_tree().paused = false
	Game.world_root = self
	OptionsScreen.apply_saved()

	var in_hub := Game.mode == "hub"
	if in_hub:
		level = Escola.new()
		level.name = "Escola"
	else:
		level = PostoVigia.new()
		level.name = "PostoVigia01"
	add_child(level)
	level.build()

	party = Party.new()
	party.name = "Grupo"
	add_child(party)
	Game.party = party

	fenix = Fenix.new()
	fenix.name = "Fenix"
	fenix.stats = FENIX_STATS
	fenix.position = level.player_spawn
	add_child(fenix)

	party.add_hero(fenix)

	# Na escola o Feixe só aparece depois de resgatado, já no grupo.
	if not in_hub or Game.progress["feixe"]:
		feixe = Feixe.new()
		feixe.name = "Feixe"
		feixe.stats = FEIXE_STATS
		feixe.position = level.feixe_cell_position
		feixe.in_party = in_hub
		# Já resgatado antes: na fase ele começa no grupo, ao lado do Fênix.
		if not in_hub and Game.progress["feixe"]:
			feixe.position = level.player_spawn + Vector3(1.2, 0, 0.8)
			feixe.in_party = true
		add_child(feixe)
		party.add_hero(feixe)

	rig = CameraRig.new()
	rig.name = "Camera"
	add_child(rig)
	party.camera_rig = rig

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.setup(party, level)
	Game.hud = hud

	party.switch_to(0, true)

	if in_hub:
		(level as Escola).mission_requested.connect(_on_mission_requested)
	else:
		level.feixe_rescued.connect(_on_feixe_rescued)
		level.run_completed.connect(_on_run_completed)
	party.defeated.connect(_on_defeated)
	hud.restart_requested.connect(restart)

	# Menu inicial: uma vez por sessão, por cima da frente da escola.
	if in_hub and not MainMenu.shown:
		var menu := MainMenu.new()
		hud.set_hidden(true)
		menu.closed.connect(func() -> void: hud.set_hidden(false))
		add_child(menu)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_rescue") and feixe != null and not feixe.in_party and Game.mode == "fase":
		# Atalho de teste: solta o Feixe e o traz para perto.
		feixe.global_position = party.point_behind_leader()
		level.open_cell()
		Game.message("(teste) Feixe solto com F3.", 2.0)


func _on_feixe_rescued() -> void:
	party.rescue(feixe)
	Game.progress["feixe"] = true
	_rescued_this_run = true


## A mesa do mapa abre o cartão da missão; "Partir" leva à fase.
func _on_mission_requested() -> void:
	if _card != null:
		return
	_card = MissionCard.new()
	_card.party = party
	hud.set_hidden(true)
	_card.depart.connect(func() -> void:
		Game.mode = "fase"
		restart())
	_card.closed.connect(func() -> void:
		_card = null
		hud.set_hidden(false))
	add_child(_card)


func _on_run_completed() -> void:
	if Game.run_finished:
		return
	Game.run_finished = true
	Game.progress["runs"] = int(Game.progress["runs"]) + 1
	var best: float = Game.progress.get("best_time", -1.0)
	var new_record := best < 0.0 or Game.run_time < best
	if new_record:
		Game.progress["best_time"] = Game.run_time
	Game.progress["best_chests"] = maxi(int(Game.progress.get("best_chests", 0)), Game.chests_opened)
	# Depois da tela de resultado (Enter), o grupo volta para a escola.
	Game.mode = "hub"
	get_tree().paused = true
	hud.show_results("Feixe" if _rescued_this_run else "", new_record and best >= 0.0)


func _on_defeated() -> void:
	if Game.run_finished:
		return
	Game.run_finished = true
	hud.show_defeat()
	# Derrota: volta para a escola (o resgate só conta se a fase for concluída).
	Game.mode = "hub"
	await get_tree().create_timer(3.0, true, false, true).timeout
	restart()


func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
