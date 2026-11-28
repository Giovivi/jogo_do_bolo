class_name MistralStats
extends HeroStats
## Kit da Mistral (documento "Mistral, a senhora dos céus" da Vivi):
## controle de área com eletricidade e vento; gelo só na suprema.

@export_group("Descarga Relampejante (básico)")
@export var bolt_damage: float = 10.0
@export var bolt_range: float = 12.0
@export var bolt_interval: float = 0.4
## Salto para um segundo inimigo próximo, com dano reduzido.
@export var chain_radius: float = 4.0
@export var chain_damage_fraction: float = 0.5
## Saltos extras com a Carga Atmosférica completa (ramificação adicional).
@export var chain_jumps: int = 1
@export var chain_jumps_charged: int = 2

@export_group("Carga Atmosférica (passiva)")
## Cargas para fortalecer o próximo ataque (cada habilidade usada dá 1).
@export var charges_needed: int = 3

@export_group("Olho do Furacão (Q)")
@export var storm_dps: float = 8.0
@export var storm_radius: float = 2.5
@export var storm_duration: float = 3.0
@export var storm_cast_range: float = 10.0
## Velocidade com que puxa para o centro (m/s); a atração alcança um pouco
## além do raio de dano (storm_pull_reach x raio).
@export var storm_pull_speed: float = 3.2
@export var storm_pull_reach: float = 1.6
## Inimigos grandes (com escudo) sofrem só esta fração da atração.
@export var storm_heavy_pull: float = 0.4
## Com Carga: raio e força de atração multiplicados.
@export var storm_charged_radius: float = 1.4
@export var storm_charged_pull: float = 1.6

@export_group("Investida de Vendaval (E)")
@export var gust_damage: float = 18.0
@export var gust_range: float = 7.0
@export var gust_arc_degrees: float = 100.0
@export var gust_push_meters: float = 3.0
## Com Carga: empurrão e dano maiores.
@export var gust_charged_push: float = 4.5
@export var gust_charged_damage: float = 24.0

@export_group("Geada Absoluta (R)")
@export var frost_damage: float = 100.0
@export var frost_radius: float = 12.0
@export var frost_freeze_time: float = 3.0
## Execução total: braços erguidos, gelo correndo pelo chão, cristais.
@export var frost_cast_time: float = 1.5
## Parte da execução antes de o gelo começar a se espalhar.
@export var frost_charge_time: float = 0.5
## Inimigos resistentes (com escudo) ficam congelados só esta fração.
@export var frost_heavy_fraction: float = 0.66
