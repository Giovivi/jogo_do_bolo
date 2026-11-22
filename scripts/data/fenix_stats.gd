class_name FenixStats
extends HeroStats
## Kit do Fênix (seção 3.4 da especificação).

@export_group("Garras (básico)")
@export var combo_damage: PackedFloat32Array = PackedFloat32Array([10.0, 10.0, 18.0])
@export var combo_interval: float = 0.32
@export var combo_reset_time: float = 0.8
@export var claw_range: float = 2.3
@export var claw_arc_degrees: float = 110.0
@export var finisher_knockback: float = 7.0

@export_group("Asas de Fogo (Q)")
@export var wings_damage: float = 25.0
@export var wings_range: float = 6.0
@export var wings_arc_degrees: float = 70.0

@export_group("Chama Azul (E)")
@export var heal_amount: float = 30.0
@export var heal_pick_radius: float = 3.0

@export_group("Mergulho da Ave (R)")
@export var dive_max_distance: float = 10.0
@export var dive_time: float = 0.45
@export var dive_damage: float = 80.0
@export var dive_radius: float = 4.0

@export_group("Renascer (passiva)")
@export var rebirth_health_fraction: float = 0.5
@export var rebirth_damage: float = 40.0
@export var rebirth_radius: float = 4.0

@export_group("Regeneração (passiva)")
@export var regen_delay: float = 4.0
@export var regen_per_second: float = 3.0

@export_group("Planar (exploração): segurar Espaço no ar")
## Pulo + planar cobre cerca de 5 m: passa o vão de 4 m, não o de 6 m.
@export var glide_max_distance: float = 4.0
@export var glide_speed: float = 6.5
@export var glide_fall_speed: float = 1.2
