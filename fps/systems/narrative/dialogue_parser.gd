class_name DialogueParser
extends RefCounted
## Lê arquivos de fala (.dlg), escritos no mesmo formato do roteiro:
##
##   # comentário
##   [id_da_cena]                   sequência fixa (cena, ordem, conversa)
##   MILLER: Confiram as armas.
##   REED, PELO RÁDIO: A posição continua ativa!
##   @pausa 1.5                     silêncio extra (segundos)
##   @evento nome                   avisa o jogo (EventBus.narrative_event) neste ponto
##   @camera nome / @tremer 0.5 ...  comandos de cutscene (repassados ao Cutscenes)
##
##   [!id_do_grupo]                 falas contextuais: uma é sorteada por vez, sem repetir
##   MILLER: Não fique parado na areia! Procure cobertura!
##
## Linhas sem "NOME:" em maiúsculas são direções de cena e são ignoradas — dá para
## colar trechos do roteiro direto.
##
## Resultado: { id: { "bark": bool, "items": [ {type, ...} ] } }
## Cada fala recebe um id estável "<cena>_<nº>" (ex.: praia_desembarque_02), usado para
## achar a dublagem em assets/audio/voz/<id>.ogg quando existir.

static var _speaker_regex: RegEx


static func parse_file(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Não consegui abrir o arquivo de falas: %s" % path)
		return {}
	return parse_text(file.get_as_text(), path)


static func parse_text(text: String, source := "") -> Dictionary:
	if _speaker_regex == null:
		_speaker_regex = RegEx.create_from_string("^([A-ZÀ-ÖØ-Ý][A-ZÀ-ÖØ-Ý ]*?)(?:,\\s*([^:]+))?:\\s*(.+)$")
	var result := {}
	var current: Dictionary = {}
	var current_id := ""
	var line_count := 0
	var number := 0
	for raw in text.split("\n"):
		number += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			var header := line.substr(1, line.length() - 2).strip_edges()
			var bark := header.begins_with("!")
			current_id = header.trim_prefix("!").strip_edges()
			if result.has(current_id):
				push_warning("%s:%d — id repetido '%s'" % [source, number, current_id])
			current = {"bark": bark, "items": []}
			result[current_id] = current
			line_count = 0
			continue
		if current_id.is_empty():
			continue
		if line.begins_with("@"):
			var parts := line.substr(1).split(" ", false, 1)
			match parts[0]:
				"pausa":
					current.items.append({"type": "pause", "seconds": float(parts[1]) if parts.size() > 1 else 1.0})
				"evento":
					current.items.append({"type": "event", "name": parts[1].strip_edges() if parts.size() > 1 else ""})
				_:
					var args := parts[1].split(" ", false) if parts.size() > 1 else PackedStringArray()
					current.items.append({"type": "command", "name": parts[0], "args": args})
			continue
		var m := _speaker_regex.search(line)
		if m == null:
			continue  # direção de cena
		line_count += 1
		current.items.append({
			"type": "line",
			"id": "%s_%02d" % [current_id, line_count],
			"speaker": m.get_string(1).strip_edges(),
			"tag": m.get_string(2).strip_edges(),
			"text": m.get_string(3).strip_edges(),
		})
	return result
