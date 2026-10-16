# Configuração global (autoload "Config"): modo de jogo, dificuldade, filtro e teclas.
extends Node

# modo: "versus" (você x CPU), "dois" (2 jogadores), "treino", "demo" (CPU x CPU)
var modo := "versus"
var dificuldade := 1                 # 0 fácil, 1 normal, 2 difícil
var filtro_ps2 := true
var rounds_para_vencer := 2
var volume_musica := 4               # 0 (mudo) a 10
var _musica: AudioStreamPlayer
var _faixas: Array = []
const NOMES_DIFICULDADE := ["FÁCIL", "NORMAL", "DIFÍCIL"]

# Teclas físicas. Botões no formato losango do Tekken:
#   P1:  U I      P2 (teclado numérico): 4 5     ou   O P
#        J K                             1 2          L Ç
const TECLAS := {
	"p1_esquerda": [KEY_A], "p1_direita": [KEY_D], "p1_cima": [KEY_W], "p1_baixo": [KEY_S],
	"p1_1": [KEY_U], "p1_2": [KEY_I], "p1_3": [KEY_J], "p1_4": [KEY_K],
	"p2_esquerda": [KEY_LEFT], "p2_direita": [KEY_RIGHT], "p2_cima": [KEY_UP], "p2_baixo": [KEY_DOWN],
	"p2_1": [KEY_KP_4, KEY_O], "p2_2": [KEY_KP_5, KEY_P], "p2_3": [KEY_KP_1, KEY_L], "p2_4": [KEY_KP_2, KEY_SEMICOLON],
	"pausa": [KEY_ESCAPE, KEY_BACKSPACE],
	"depurar": [KEY_F1], "alternar_filtro": [KEY_F3], "treino_boneco": [KEY_F5], "treino_reset": [KEY_F6],
	"menu_cima": [KEY_W, KEY_UP], "menu_baixo": [KEY_S, KEY_DOWN],
	"menu_esquerda": [KEY_A, KEY_LEFT], "menu_direita": [KEY_D, KEY_RIGHT],
	"menu_ok": [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_U],
}


func _ready() -> void:
	for acao in TECLAS:
		if not InputMap.has_action(acao):
			InputMap.add_action(acao)
		for tecla in TECLAS[acao]:
			var ev := InputEventKey.new()
			ev.physical_keycode = tecla
			InputMap.action_add_event(acao, ev)
	process_mode = Node.PROCESS_MODE_ALWAYS
	aplicar_filtro()
	_musica = AudioStreamPlayer.new()
	_musica.finished.connect(_proxima_faixa)
	add_child(_musica)
	_procurar_faixas()
	_proxima_faixa()


# Música: arquivos seus em central/musica/ (.mp3, .ogg, .wav) tocam em sequência
# aleatória; sem nenhum, toca o rock gerado por ferramentas/gerar_rock.py.
func _procurar_faixas() -> void:
	var pasta := ProjectSettings.globalize_path("res://").path_join("../musica").simplify_path()
	var d := DirAccess.open(pasta)
	if d:
		for nome in d.get_files():
			if nome.get_extension().to_lower() in ["mp3", "ogg", "wav"]:
				_faixas.append(pasta.path_join(nome))
	_faixas.shuffle()


func _proxima_faixa() -> void:
	var stream: AudioStream = null
	if not _faixas.is_empty():
		var arq: String = _faixas.pop_front()
		_faixas.append(arq)
		match arq.get_extension().to_lower():
			"mp3": stream = AudioStreamMP3.load_from_file(arq)
			"ogg": stream = AudioStreamOggVorbis.load_from_file(arq)
			"wav": stream = AudioStreamWAV.load_from_file(arq)
	if stream == null and ResourceLoader.exists("res://assets/sons/musica_luta.wav"):
		stream = load("res://assets/sons/musica_luta.wav")
	_musica.stream = stream
	aplicar_volume()
	_musica.play()


func aplicar_volume() -> void:
	_musica.volume_db = -80.0 if volume_musica == 0 else linear_to_db(volume_musica / 10.0) - 12.0


# Filtro de PS2: só o 3D é desenhado em resolução baixa (50%, ~640x360) e ampliado; a interface
# continua nítida. A ampliação suave lembra a saída de vídeo do PS2 na TV.
func aplicar_filtro() -> void:
	var janela := get_tree().root
	janela.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	janela.content_scale_size = Vector2i(1280, 720)
	janela.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	janela.scaling_3d_scale = 0.5 if filtro_ps2 else 1.0
	janela.msaa_3d = Viewport.MSAA_DISABLED if filtro_ps2 else Viewport.MSAA_2X


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("alternar_filtro"):
		filtro_ps2 = not filtro_ps2
		aplicar_filtro()
