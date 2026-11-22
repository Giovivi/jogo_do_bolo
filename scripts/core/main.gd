extends Node3D
## Cena principal: monta a fase, o grupo, a câmera e o HUD.

const FENIX_STATS: FenixStats = preload("res://data/fenix.tres")
const FEIXE_STATS: FeixeStats = preload("res://data/feixe.tres")

var level: PostoVigia
var party: Party
var rig: CameraRig
var hud: HUD
var fenix: Fenix
var feixe: Feixe


func _ready() -> void:
	Game.reset_run()
	get_tree().paused = false
	Game.world_root = self

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

	feixe = Feixe.new()
	feixe.name = "Feixe"
	feixe.stats = FEIXE_STATS
	feixe.position = level.feixe_cell_position
	feixe.in_party = false
	add_child(feixe)

	party.add_hero(fenix)
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

	level.feixe_rescued.connect(_on_feixe_rescued)
	level.run_completed.connect(_on_run_completed)
	party.defeated.connect(_on_defeated)
	hud.restart_requested.connect(restart)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("debug_rescue") and not feixe.in_party:
		# Atalho de teste: solta o Feixe e o traz para perto.
		feixe.global_position = party.point_behind_leader()
		level.open_cell()
		Game.message("(teste) Feixe solto com F3.", 2.0)


func _on_feixe_rescued() -> void:
	party.rescue(feixe)


func _on_run_completed() -> void:
	if Game.run_finished:
		return
	Game.run_finished = true
	get_tree().paused = true
	hud.show_results()


func _on_defeated() -> void:
	if Game.run_finished:
		return
	Game.run_finished = true
	hud.show_defeat()
	await get_tree().create_timer(3.0, true, false, true).timeout
	restart()


func restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
