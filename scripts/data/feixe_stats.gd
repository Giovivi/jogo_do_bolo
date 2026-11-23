class_name FeixeStats
extends HeroStats
## Kit do Feixe (seção 3.5 da especificação; raio laser da prancha
## feixe-laser-drone-v2).

@export_group("Raio Laser (básico)")
@export var shot_damage: float = 8.0
@export var shot_range: float = 15.0
@export var shot_interval: float = 0.25
## Largura que o raio acerta (m), além do corpo do inimigo.
@export var shot_width: float = 0.3

@export_group("Raio Forte (Q)")
@export var laser_dps: float = 12.0
@export var laser_range: float = 15.0
@export var laser_max_time: float = 3.0
@export var laser_move_multiplier: float = 0.35
@export var laser_width: float = 1.2

@export_group("Cone de Raios (E)")
@export var pulse_damage: float = 15.0
@export var pulse_range: float = 6.0
@export var pulse_arc_degrees: float = 90.0
## Empurrão do cone, em metros (mais que o forte comum: é a função dele).
@export var pulse_push_meters: float = 2.5

@export_group("Suprema em Círculo (R)")
@export var blast_damage: float = 120.0
## Raio do círculo: 14 m pega a sala toda, mesmo nas grandes.
@export var blast_radius: float = 14.0
