class_name FenixStats
extends HeroStats
## Kit do Fênix (seção 3.4 da especificação).

@export_group("Garras (básico)")
@export var combo_damage: PackedFloat32Array = PackedFloat32Array([10.0, 10.0, 18.0])
@export var combo_interval: float = 0.32
@export var combo_reset_time: float = 0.8
@export var claw_range: float = 2.3
@export var claw_arc_degrees: float = 110.0

@export_group("Asas de Fogo (Q)")
@export var wings_damage: float = 25.0
@export var wings_range: float = 6.0
@export var wings_arc_degrees: float = 70.0

@export_group("Chama Azul (E)")
@export var heal_amount: float = 30.0
@export var heal_pick_radius: float = 3.0

@export_group("Mergulho da Ave (R)")
@export var dive_max_distance: float = 12.0
@export var dive_time: float = 0.5
@export var dive_damage: float = 80.0
@export var dive_radius: float = 6.0

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

@export_group("Forma Fênix (suprema): começa ao pousar o Mergulho da Ave")
@export var form_duration: float = 15.0
@export var form_move_speed: float = 7.5

@export_group("Forma Fênix: Dança das Brasas (básico)")
## 1. Corte Incandescente, 2. Giro Flamejante, 3. Mergulho da Fênix.
@export var form_combo_damage: PackedFloat32Array = PackedFloat32Array([14.0, 14.0, 22.0])
@export var form_combo_interval: float = 0.3
@export var form_slash_range: float = 2.7
@export var form_slash_arc_degrees: float = 160.0
@export var form_spin_radius: float = 2.4
@export var form_dive_distance: float = 4.5
@export var form_dive_time: float = 0.18
@export var form_dive_burst_damage: float = 12.0
@export var form_dive_burst_radius: float = 2.0
## Fogo que o Corte deixa no chão.
@export var form_slash_burn_dps: float = 3.0
@export var form_slash_burn_time: float = 2.0

@export_group("Forma Fênix: Brasa")
@export var ember_max_stacks: int = 3
@export var ember_duration: float = 5.0

@export_group("Forma Fênix: Tempestade de Penas (Q)")
@export var feather_cooldown: float = 5.0
@export var feather_count: int = 9
@export var feather_arc_degrees: float = 70.0
@export var feather_range: float = 8.0
@export var feather_damage: float = 6.0
## Inimigo atingido por esta quantidade de penas ou mais leva o bônus.
@export var feather_multi_hits: int = 3
@export var feather_multi_bonus: float = 10.0
@export var feather_burn_dps: float = 4.0
@export var feather_burn_time: float = 2.5
## Estouro de cada Brasa consumida, em volta do inimigo.
@export var ember_pop_damage: float = 12.0
@export var ember_pop_radius: float = 1.5

@export_group("Forma Fênix: Investida Solar (E)")
@export var rush_cooldown: float = 7.0
@export var rush_distance: float = 9.0
@export var rush_time: float = 0.3
@export var rush_pass_damage: float = 15.0
@export var rush_burn_dps: float = 4.0
@export var rush_burn_time: float = 2.5
@export var rush_blast_damage: float = 35.0
@export var rush_blast_radius: float = 4.0
## Dano extra na explosão por Brasa dos inimigos atravessados (sem consumir).
@export var rush_bonus_per_ember: float = 10.0
@export var rush_bonus_max: float = 60.0
