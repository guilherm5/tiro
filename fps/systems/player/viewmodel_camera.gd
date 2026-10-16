extends Camera3D
## Câmera da arma em primeira pessoa. Copia a câmera principal, mas desenha só a
## camada visual 2 (o modelo da arma), por cima do mundo. Assim a arma nunca
## atravessa paredes, e qualquer modelo importado funciona sem shader especial.
##
## IMPORTANTE: luzes também obedecem à camada. Para uma luz iluminar a arma, ela
## precisa estar nas camadas 1 e 2 (ex.: o sol de cada fase: Layers = 1 e 2).

@export var source: Camera3D
## Luz ambiente da arma (aproxima a cor do céu da fase).
@export var ambient_color := Color(0.7, 0.66, 0.6)
@export var ambient_energy := 1.35


func _ready() -> void:
	# Roda depois da câmera principal ter aplicado recuo e tremor neste quadro.
	process_priority = 100
	_copy_world_lighting()


## Usa a mesma luz ambiente, reflexos e cor da cena (o metal reflete o céu), mas
## com fundo transparente e sem efeitos de tela que só fazem sentido no mundo.
func _copy_world_lighting() -> void:
	var world_env := source.get_world_3d().environment
	if world_env == null:
		return
	var env: Environment = world_env.duplicate()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.fog_enabled = false
	env.volumetric_fog_enabled = false
	env.ssao_enabled = false
	env.ssr_enabled = false
	env.glow_enabled = false
	# Sem fundo de céu o Godot não calcula a luz ambiente do céu; usa uma cor fixa.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	# Menos dessaturação na arma: a madeira escura não deve virar cinza.
	env.adjustment_saturation = maxf(env.adjustment_saturation, 0.85)
	environment = env


func _process(_delta: float) -> void:
	global_transform = source.global_transform
	fov = source.fov
