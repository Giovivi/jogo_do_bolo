class_name FeixeStats
extends HeroStats
## Kit do Feixe (seção 3.5 da especificação).

@export_group("Tiro Óptico (básico)")
@export var shot_damage: float = 8.0
@export var shot_range: float = 15.0
@export var shot_interval: float = 0.25
@export var shot_speed: float = 45.0

@export_group("Laser Contínuo (Q)")
@export var laser_dps: float = 12.0
@export var laser_range: float = 15.0
@export var laser_max_time: float = 3.0
@export var laser_move_multiplier: float = 0.35
@export var laser_width: float = 0.7

@export_group("Pulso de Repulsão (E)")
@export var pulse_damage: float = 15.0
@export var pulse_range: float = 4.0
@export var pulse_arc_degrees: float = 90.0
@export var pulse_knockback: float = 9.0

@export_group("Rajada Máxima (R)")
@export var blast_damage: float = 120.0
@export var blast_length: float = 30.0
@export var blast_width: float = 1.4
