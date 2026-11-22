class_name Party
extends Node
## Grupo de heróis: troca de personagem (1 a 4 / Tab), interação (F),
## trilha de pegadas para a IA e derrota quando todos caem.

signal controlled_changed(hero: Hero)
signal defeated

const MAX_SLOTS := 4
const CRUMB_SPACING := 1.0
const MAX_CRUMBS := 80

var heroes: Array[Hero] = []
var controlled_hero: Hero = null
var switch_cooldown: float = 0.0
var breadcrumbs: Array[Vector3] = []
var current_interactable: Interactable = null
var camera_rig: CameraRig = null


func add_hero(h: Hero) -> void:
	h.party_index = heroes.size()
	heroes.append(h)
	h.downed.connect(_on_hero_downed)


func living_heroes() -> Array[Hero]:
	var out: Array[Hero] = []
	for h in heroes:
		if h.in_party and not h.is_dead:
			out.append(h)
	return out


func _physics_process(delta: float) -> void:
	switch_cooldown = maxf(0.0, switch_cooldown - delta)
	if controlled_hero == null or Game.run_finished:
		return
	for i in MAX_SLOTS:
		if Input.is_action_just_pressed("switch_%d" % (i + 1)):
			request_switch(i)
	if Input.is_action_just_pressed("switch_next"):
		_switch_next()
	_record_crumb()
	_update_interactable()
	if current_interactable != null and Input.is_action_just_pressed("interact"):
		current_interactable.interact(controlled_hero)


func request_switch(index: int) -> void:
	if index >= heroes.size():
		Game.message("Espaço %d vazio: resgate mais mutantes para formar o grupo." % (index + 1), 1.5)
		return
	var h := heroes[index]
	if h == controlled_hero:
		return
	if not h.in_party:
		Game.message("%s ainda não está no grupo." % h.stats.display_name, 1.5)
		return
	if h.is_dead:
		Game.message("%s está caído. Reanime antes de trocar." % h.stats.display_name, 1.5)
		return
	if switch_cooldown > 0.0:
		Game.message("Troca recarregando (%.1f s)" % switch_cooldown, 1.0)
		return
	switch_to(index, false)


func _switch_next() -> void:
	if heroes.is_empty() or controlled_hero == null:
		return
	for step in range(1, heroes.size()):
		var idx := (controlled_hero.party_index + step) % heroes.size()
		var h := heroes[idx]
		if h.in_party and not h.is_dead:
			request_switch(idx)
			return


## forced = troca automática (herói controlado caiu): ignora a recarga.
func switch_to(index: int, forced: bool) -> void:
	var h := heroes[index]
	var slide := controlled_hero != null
	if controlled_hero != null:
		controlled_hero.set_controlled(false)
	controlled_hero = h
	h.set_controlled(true)
	breadcrumbs.clear()
	breadcrumbs.append(h.global_position)
	if not forced:
		switch_cooldown = Game.rules.switch_cooldown
	if camera_rig != null:
		camera_rig.follow(h, slide)
	controlled_changed.emit(h)


func _on_hero_downed(h: Hero) -> void:
	var alive := living_heroes()
	if alive.is_empty():
		defeated.emit()
		return
	if h == controlled_hero:
		var best: Hero = alive[0]
		var best_d := INF
		for other in alive:
			var d := other.global_position.distance_to(h.global_position)
			if d < best_d:
				best_d = d
				best = other
		Game.message("%s caiu! Você agora controla %s." % [h.stats.display_name, best.stats.display_name], 2.5)
		switch_to(best.party_index, true)


func rescue(h: Hero) -> void:
	h.in_party = true
	h.revive(1.0)
	Game.message("%s entrou no grupo! Aperte %d (ou Tab) para trocar." % [h.stats.display_name, h.party_index + 1], 4.0)


## Aliado caído mais perto de "helper" sem inimigos por perto.
func downed_ally_to_revive(helper: Hero) -> Hero:
	var best: Hero = null
	var best_d := INF
	for h in heroes:
		if h == helper or not h.in_party or not h.is_dead:
			continue
		var safe := true
		for e in Game.living_enemies():
			var enemy := e as Enemy
			if enemy != null and enemy.active and Game.flat_distance(enemy.global_position, h.global_position) < Game.rules.ai_revive_safe_radius:
				safe = false
				break
		if not safe:
			continue
		var d := helper.global_position.distance_to(h.global_position)
		if d < best_d:
			best_d = d
			best = h
	return best


func point_behind_leader() -> Vector3:
	if controlled_hero == null:
		return Vector3.ZERO
	for i in range(breadcrumbs.size() - 1, -1, -1):
		var c := breadcrumbs[i]
		if c.distance_to(controlled_hero.global_position) >= 2.0:
			return c
	return controlled_hero.last_safe_position


func _record_crumb() -> void:
	var p := controlled_hero.global_position
	if Game.is_over_gap(p):
		return
	if breadcrumbs.is_empty() or breadcrumbs[breadcrumbs.size() - 1].distance_to(p) >= CRUMB_SPACING:
		breadcrumbs.append(p)
		if breadcrumbs.size() > MAX_CRUMBS:
			breadcrumbs.remove_at(0)


func _update_interactable() -> void:
	current_interactable = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("interactables"):
		var it := n as Interactable
		if it == null or not it.can_interact(controlled_hero):
			continue
		var d := Game.flat_distance(it.global_position, controlled_hero.global_position)
		if d <= it.interact_range and d < best_d:
			best_d = d
			current_interactable = it
