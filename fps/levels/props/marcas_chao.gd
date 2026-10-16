extends Node3D
## Marcas no chão (decals), com texturas geradas ao carregar (sem arquivos):
##  - "oleo": mancha escura e brilhante (perto de destroços e do tanque);
##  - "sangue": mancha vermelho-escura (junto aos corpos);
##  - "fuligem": anel escuro em volta das crateras;
##  - "esteira": rastro de lagarta de tanque (faixa com sulcos transversais);
##  - "pegadas": trilha de pegadas na areia molhada.
## Só pintam o terreno e objetos do mundo (camada visual 1), nunca personagens.

##  - "tiros": marcas de bala (lascas de concreto) — em paredes;
##  - "mapa": mapa militar de papel (parede do bunker).
## Cada marca: [tipo, x, z, giro (graus), tamanho (x, z) em metros] para o chão, ou
## [tipo, x, z, giro, tamanho, altura y] para uma parede: projeta na horizontal, na
## direção -Z do giro (a parede fica atrás da marca).
@export var marks: Array = []
@export var terrain: BeachTerrain

var _textures := {}


func _ready() -> void:
	for mark: Array in marks:
		_add_mark(mark[0], mark[1], mark[2], mark[3], mark[4], mark[5] if mark.size() > 5 else INF)


func _add_mark(kind: String, x: float, z: float, yaw: float, size: Vector2, wall_y := INF) -> void:
	var decal := Decal.new()
	decal.texture_albedo = _texture(kind)
	decal.size = Vector3(size.x, 3.0, size.y)
	decal.cull_mask = 1
	decal.upper_fade = 0.3
	decal.lower_fade = 0.3
	decal.distance_fade_enabled = true
	decal.distance_fade_begin = 60.0
	decal.distance_fade_length = 15.0
	match kind:
		"oleo":
			decal.modulate = Color(1, 1, 1, 0.85)
		"tiros":
			decal.modulate = Color(1, 1, 1, 0.8)
		"esteira", "pegadas":
			decal.modulate = Color(1, 1, 1, 0.7)
	if wall_y != INF:
		decal.size = Vector3(size.x, 1.2, size.y)
		decal.position = Vector3(x, wall_y, z)
		decal.rotation = Vector3(deg_to_rad(90.0), deg_to_rad(yaw), 0.0)
		decal.cull_mask = 1
		decal.normal_fade = 0.6  # só a face de frente (não o chão ao pé da parede)
		add_child(decal)
		return
	var y := terrain.height_at(x, z) if terrain else 0.0
	decal.position = Vector3(x, y, z)
	decal.rotation.y = deg_to_rad(yaw)
	add_child(decal)


func _texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var image: Image
	match kind:
		"oleo": image = _blob(Color(0.03, 0.03, 0.025), 0.9, 11)
		"sangue": image = _blob(Color(0.22, 0.02, 0.015), 0.85, 23)
		"fuligem": image = _ring(Color(0.05, 0.045, 0.04))
		"esteira": image = _tracks()
		"pegadas": image = _footprints()
		"tiros": image = _bullet_marks()
		"mapa": image = _map()
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	_textures[kind] = texture
	return texture


## Mancha irregular: círculo deformado por ruído, bordas suaves, respingos em volta.
func _blob(color: Color, opacity: float, seed: int) -> Image:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 0.05
	for y in size:
		for x in size:
			var p := Vector2(x, y) / size - Vector2(0.5, 0.5)
			var r := p.length() * 2.0 + noise.get_noise_2d(x, y) * 0.45
			var a := 1.0 - smoothstep(0.55, 0.75, r)
			# Respingos: pontos soltos fora da mancha.
			if a < 0.05 and noise.get_noise_2d(x * 4.0, y * 4.0) > 0.55 and r < 1.2:
				a = 0.8
			image.set_pixel(x, y, Color(color, a * opacity))
	return image


## Anel de fuligem (mais escuro na borda da cratera, some para fora e para dentro).
func _ring(color: Color) -> Image:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.06
	for y in size:
		for x in size:
			var r := (Vector2(x, y) / size - Vector2(0.5, 0.5)).length() * 2.0 + noise.get_noise_2d(x, y) * 0.25
			var a := smoothstep(0.25, 0.55, r) * (1.0 - smoothstep(0.65, 1.0, r))
			image.set_pixel(x, y, Color(color, a * 0.75))
	return image


## Rastro de lagarta: duas faixas com sulcos transversais (a textura vai ao longo de Y).
func _tracks() -> Image:
	var w := 64
	var h := 256
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in h:
		for x in w:
			var u := float(x) / w
			var band := (u > 0.05 and u < 0.3) or (u > 0.7 and u < 0.95)
			var groove := fmod(float(y), 10.0) < 4.0
			var a := 0.0
			if band:
				a = 0.55 if groove else 0.3
			image.set_pixel(x, y, Color(0.18, 0.15, 0.12, a))
	return image


## Trilha de pegadas alternadas (esquerda/direita), ao longo de Y.
func _footprints() -> Image:
	var w := 64
	var h := 256
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var step := 32
	for i in h / step:
		var cx := 22 if i % 2 == 0 else 42
		var cy := i * step + step / 2
		for y in range(cy - 9, cy + 9):
			for x in range(cx - 5, cx + 5):
				if y < 0 or y >= h:
					continue
				var d := Vector2((x - cx) / 4.5, (y - cy) / 8.5).length()
				if d < 1.0:
					image.set_pixel(x, y, Color(0.12, 0.1, 0.08, 0.55 * (1.0 - d * d * 0.5)))
	return image


## Marcas de bala em concreto: lascas claras com centro escuro, em grupos.
func _bullet_marks() -> Image:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 70:
		var c := Vector2(rng.randf_range(10, size - 10), rng.randf_range(10, size - 10))
		var r := rng.randf_range(2.5, 7.0)
		for y in range(int(c.y - r * 1.6), int(c.y + r * 1.6)):
			for x in range(int(c.x - r * 1.6), int(c.x + r * 1.6)):
				if x < 0 or y < 0 or x >= size or y >= size:
					continue
				var d := Vector2(x, y).distance_to(c) / r
				if d < 0.45:
					image.set_pixel(x, y, Color(0.08, 0.08, 0.075, 0.95))
				elif d < 1.5:
					var old := image.get_pixel(x, y)
					var chip := Color(0.48, 0.47, 0.43, 0.55 * (1.0 - smoothstep(0.9, 1.5, d)))
					if chip.a > old.a:
						image.set_pixel(x, y, chip)
	return image


## Mapa militar: papel amarelado, grade, linha da costa, setas e marcações.
func _map() -> Image:
	var w := 256
	var h := 192
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 4
	noise.frequency = 0.04
	for y in h:
		for x in w:
			var paper := 0.6 + noise.get_noise_2d(x, y) * 0.06
			var color := Color(paper, paper * 0.95, paper * 0.78)
			if x % 32 == 0 or y % 32 == 0:
				color = color.darkened(0.25)
			# Costa: curva; mar com hachuras azuladas abaixo dela.
			var coast := 120.0 + sin(x * 0.05) * 14.0 + sin(x * 0.13) * 5.0
			if y > coast:
				color = color.lerp(Color(0.55, 0.65, 0.7), 0.45 if (x + y) % 6 < 2 else 0.25)
			if absf(y - coast) < 1.5:
				color = Color(0.2, 0.25, 0.3)
			# Borda do papel um pouco escurecida.
			var edge := minf(minf(x, w - 1 - x), minf(y, h - 1 - y))
			if edge < 6:
				color = color.darkened(0.3 * (1.0 - edge / 6.0))
			image.set_pixel(x, y, color)
	# Setas vermelhas (desembarque) e marcas azuis (posições).
	for k in 4:
		var x0 := 40 + k * 50
		for t in 30:
			for dx in range(-1, 2):
				image.set_pixel(clampi(x0 + dx, 0, w - 1), clampi(170 - t * 2, 0, h - 1), Color(0.6, 0.08, 0.06))
		for t in 6:
			image.set_pixel(clampi(x0 - t, 0, w - 1), clampi(112 + t, 0, h - 1), Color(0.6, 0.08, 0.06))
			image.set_pixel(clampi(x0 + t, 0, w - 1), clampi(112 + t, 0, h - 1), Color(0.6, 0.08, 0.06))
	for k in 6:
		var cx := 30 + k * 38
		var cy := 80 + (k % 3) * 9
		for y in range(cy - 4, cy + 5):
			for x in range(cx - 6, cx + 7):
				if absi(y - cy) == 4 or absi(x - cx) == 6:
					image.set_pixel(x, y, Color(0.12, 0.18, 0.45))
	return image

