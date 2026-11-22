class_name GameRules
extends Resource
## Regras gerais do protótipo (troca, reanimação, feedback).

@export_group("Troca de personagem")
@export var switch_cooldown: float = 3.0
@export var camera_slide_time: float = 0.25

@export_group("Queda e reanimação")
@export var revive_radius: float = 1.5
@export var revive_time: float = 3.0
@export var revive_health_fraction: float = 0.4

@export_group("IA dos aliados")
@export var ai_follow_min: float = 2.0
@export var ai_follow_max: float = 4.0
@export var ai_engage_radius: float = 8.0
@export var ai_leash_radius: float = 12.0
@export var ai_revive_safe_radius: float = 4.0
@export var ai_regroup_distance: float = 20.0

@export_group("Feedback")
@export var damage_numbers: bool = true
@export var hitstop_seconds: float = 0.045

@export_group("Fase")
@export var cell_unlock_time: float = 60.0
@export var fall_damage: float = 10.0
