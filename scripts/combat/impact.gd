class_name Impact
extends RefCounted
## Força dos golpes (seção 3.6 da especificação de mecânicas).
## Cada golpe passa "strength" no dicionário info de take_damage().

const WEAK := 0
const STRONG := 1
const SPECIAL := 2

## Pausa no acerto, em quadros (60 por segundo).
const HITSTOP_FRAMES := [0, 3, 6]
const KILL_HITSTOP_FRAMES := 4
## Empurrão do inimigo, em metros.
const PUSH_METERS := [0.2, 0.5, 1.0]
## Tremor de câmera: [força, duração em s].
const SHAKE := [[0.0, 0.0], [0.06, 0.12], [0.16, 0.25]]
## Reação do inimigo: forte interrompe, especial derruba.
const STUN_STRONG := 0.4
const KNOCKDOWN_SPECIAL := 1.0
## Herói atingido por ataque forte fica interrompido (o dash cancela).
const HERO_STUN_STRONG := 0.3
## Herói atingido por golpe comum só dá um tranquinho.
const HERO_JOLT_METERS := 0.15


static func strength_of(info: Dictionary) -> int:
	if info.has("strength"):
		return int(info["strength"])
	return STRONG if info.get("heavy", false) else WEAK


## Velocidade inicial para o empurrão percorrer "meters" (o recuo
## desacelera a 30 m/s², ver Actor.apply_knockback).
static func push_speed(meters: float) -> float:
	return sqrt(maxf(meters, 0.0) * 2.0 * 30.0)


## O golpe veio do herói que o jogador controla?
static func from_player(source: Node) -> bool:
	return source != null and is_instance_valid(source) and source is Hero and (source as Hero).controlled
