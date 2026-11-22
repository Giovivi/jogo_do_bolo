class_name HeroStats
extends Resource
## Valores comuns a todos os heróis. Ajuste nos arquivos .tres em res://data/.

@export var display_name: String = "Herói"
@export var color: Color = Color.WHITE
@export var max_health: float = 100.0
@export var move_speed: float = 6.0

@export_group("Dash")
@export var dash_distance: float = 4.0
@export var dash_time: float = 0.15
@export var dash_cooldown: float = 1.5

@export_group("Barra do especial")
@export var special_max: float = 300.0
@export var special_per_damage_dealt: float = 1.0
@export var special_per_damage_taken: float = 0.5

@export_group("Recargas")
@export var q_cooldown: float = 6.0
@export var e_cooldown: float = 12.0
