extends CanvasLayer
## Troca de cena com tela de carregamento (autoload "SceneLoader").
## A fase é carregada em outra thread enquanto a tela mostra "CARREGANDO".

const MENU_SCENE := "res://levels/menu/menu_principal.tscn"

var _target := ""
var _screen: ColorRect
var _label: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_screen = ColorRect.new()
	_screen.color = Color.BLACK
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_label = MenuStyle.caption("CARREGANDO", 18)
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.position -= Vector2(220, 70)
	_screen.add_child(_label)
	add_child(_screen)
	_screen.hide()
	set_process(false)


func change_to(path: String) -> void:
	get_tree().paused = false
	Dialogue.stop_all()
	_target = path
	_screen.modulate.a = 1.0
	_screen.show()
	ResourceLoader.load_threaded_request(path)
	set_process(true)


func go_to_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	change_to(MENU_SCENE)


func _process(_delta: float) -> void:
	var progress := []
	var status := ResourceLoader.load_threaded_get_status(_target, progress)
	match status:
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			_label.text = "CARREGANDO  %d%%" % roundi(progress[0] * 100.0)
		ResourceLoader.THREAD_LOAD_LOADED:
			set_process(false)
			get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(_target))
			# Some depois que a nova cena montou (terreno, navegação...).
			await get_tree().create_timer(0.4).timeout
			var tween := create_tween()
			tween.tween_property(_screen, ^"modulate:a", 0.0, 0.5)
			tween.tween_callback(_screen.hide)
		_:
			set_process(false)
			push_error("Falha ao carregar a cena: %s" % _target)
			_screen.hide()
