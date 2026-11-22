class_name GameRules
extends Resource
## Regras gerais do protótipo (troca, reanimação, feedback).

@export_group("Câmera")
## Giro em torno do eixo vertical (45 = isométrica clássica, 0 = de frente).
@export var camera_yaw_degrees: float = 0.0
## Inclinação para baixo (mais perto de 0 = câmera mais baixa).
@export var camera_pitch_degrees: float = 22.0
## Falso = ortográfica; verdadeiro = perspectiva (dá mais profundidade).
@export var camera_perspective: bool = true
@export var camera_fov: float = 35.0
## Altura (em metros) do quadro visível.
@export var camera_view_height: float = 15.0

@export_group("Cenário em corte (diorama)")
## Paredes e estrutura do lado da câmera ficam cortadas nesta altura.
@export var cutaway_height: float = 0.5
## Margem extra (m) da faixa cortada além do que a parede alta esconderia.
@export var cutaway_margin: float = 1.5
## Altura da estrutura do fundo (parede de 3 m + estrutura acima), para
## não aparecer vazio acima das paredes com a câmera baixa.
@export var backdrop_height: float = 6.0

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
@export var hitstop_seconds: float = 0.045

@export_group("Fase")
@export var cell_unlock_time: float = 60.0
@export var fall_damage: float = 10.0
