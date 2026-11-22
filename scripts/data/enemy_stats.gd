class_name EnemyStats
extends Resource
## Valores de um tipo de inimigo (seção 7 da especificação).

@export var display_name: String = "Soldado"
@export var color: Color = Color(0.75, 0.3, 0.3)
@export var max_health: float = 40.0
@export var move_speed: float = 3.5
@export var aggro_radius: float = 13.0
@export var keep_min_distance: float = 6.0
@export var keep_max_distance: float = 9.0
@export var fire_interval: float = 1.6
@export var fire_windup: float = 0.35
@export var fire_range: float = 12.0
@export var projectile_damage: float = 6.0
@export var projectile_speed: float = 13.0
@export var flying: bool = false
@export var hover_height: float = 0.0
@export var shielded: bool = false
@export var body_radius: float = 0.45
