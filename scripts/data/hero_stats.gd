class_name HeroStats
extends Resource
## Valores comuns a todos os heróis. Ajuste nos arquivos .tres em res://data/.

@export var display_name: String = "Herói"
@export var color: Color = Color.WHITE
@export var max_health: float = 100.0
@export var move_speed: float = 6.0

@export_group("Pulo")
## Altura máxima do pulo (m). 1,3 m sobe um degrau de 1 m.
@export var jump_height: float = 1.3
## Velocidade horizontal no ar (fração da normal). Com 0,8 o pulo
## com corrida cobre cerca de 2,4 m: passa vão de 2 m, não o de 4 m.
@export var air_speed_multiplier: float = 0.8

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
