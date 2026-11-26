class_name FeixeStats
extends HeroStats
## Kit do Feixe (seção 3.5 da especificação), reformulado em nov/2026 pelos
## documentos da Vivi "O Feixe — especificação" e "Direção de arte e VFX"
## (pranchas feixe-reformulado-v1/v2 e feixe-e-cone-v3).

@export_group("Disparo Óptico (básico)")
@export var shot_damage: float = 8.0
@export var shot_range: float = 15.0
@export var shot_interval: float = 0.25
## Largura que o raio acerta (m), além do corpo do inimigo.
@export var shot_width: float = 0.3

@export_group("Foco Óptico (passiva)")
## Acertos seguidos no mesmo inimigo para completar o Foco.
@export var focus_hits: int = 3
## Dano somado ao disparo que consome o Foco completo (8 + 20 = 28).
@export var focus_bonus: float = 20.0

@export_group("Feixe de Contenção (Q)")
## Dano por segundo em cada alvo conforme o tempo que o feixe fica nele:
## laser_dps_start no começo, laser_dps_1s com 1 s e laser_dps_max com
## laser_ramp_time s (linha reta entre os pontos). Sair do alvo zera a conta.
@export var laser_dps_start: float = 16.0
@export var laser_dps_1s: float = 24.0
@export var laser_dps_max: float = 28.0
@export var laser_ramp_time: float = 2.0
@export var laser_range: float = 15.0
@export var laser_max_time: float = 3.0
@export var laser_move_multiplier: float = 0.35
## Largura que acerta (m). A largura visual cresce junto com o dano.
@export var laser_width: float = 1.2
## Recuo enquanto dispara (m/s).
@export var laser_recoil: float = 0.3

@export_group("Ruptura Óptica (E)")
@export var pulse_damage: float = 20.0
@export var pulse_range: float = 7.0
@export var pulse_arc_degrees: float = 110.0
@export var pulse_push_meters: float = 3.5

@export_group("Aniquilação Circular (R)")
@export var blast_damage: float = 120.0
## Raio do círculo: 14 m pega a sala toda, mesmo nas grandes.
@export var blast_radius: float = 14.0
## Preparação (dedos na têmpora e marcação no chão) antes da volta.
@export var blast_charge_time: float = 0.45
## Tempo da volta inteira (sentido horário).
@export var blast_sweep_time: float = 1.2


## Dano por segundo do Q depois de `t` s no mesmo alvo.
func laser_dps_at(t: float) -> float:
	if t <= 1.0:
		return lerpf(laser_dps_start, laser_dps_1s, clampf(t, 0.0, 1.0))
	var k := clampf((t - 1.0) / maxf(laser_ramp_time - 1.0, 0.01), 0.0, 1.0)
	return lerpf(laser_dps_1s, laser_dps_max, k)


## Força do Q de 0 a 1 (0 = 16/s, 1 = 28/s), para a largura e o brilho.
func laser_power_at(t: float) -> float:
	return clampf((laser_dps_at(t) - laser_dps_start) / maxf(laser_dps_max - laser_dps_start, 0.01), 0.0, 1.0)
