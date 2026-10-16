# Projétil (shuriken): anda em linha reta, gira, some ao acertar ou depois de um tempo.
# Linha reta no plano: um passo lateral desvia dele.
class_name Projetil
extends Node3D

var dono: Lutador
var golpe: Dictionary
var direcao := Vector3.FORWARD
var velocidade := 9.0
var vida := 70


func _init(lutador: Lutador, g: Dictionary, origem: Vector3, dir: Vector3) -> void:
	dono = lutador
	golpe = g
	direcao = dir.normalized()
	velocidade = float(g["projetil"].get("velocidade", 9.0))
	vida = int(g["projetil"].get("vida", 70))
	position = origem
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.78, 0.82)
	m.metallic = 1.0
	m.roughness = 0.25
	m.emission_enabled = true
	m.emission = Color(0.4, 0.5, 0.7)
	m.emission_energy_multiplier = 0.6
	for i in 2:  # estrela de 4 pontas: duas lâminas cruzadas
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.24, 0.012, 0.05)
		mi.mesh = b
		mi.material_override = m
		mi.rotation.y = i * PI / 2
		add_child(mi)


func passo() -> bool:
	position += direcao * velocidade / 60.0
	rotation.y += 0.6
	vida -= 1
	return vida > 0
