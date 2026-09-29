extends Node
## Persistência local em JSON via FileAccess (progresso, fichas, elo, configurações).

const SAVE_PATH := "user://tarolo_save.json"
const SAVE_VERSION := 1

## Desliga a escrita em disco (usado pelos testes headless).
var persist := true
var data: Dictionary = {}


func _ready() -> void:
	load_game()


func defaults() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"settings": {"music_volume": 0.8, "sfx_volume": 0.9, "fullscreen": false, "anim_speed": 1.0, "hand_layout": "row", "difficulty": 1},
		"profile": {"name": "Arcanista", "fragments": 0, "matches": 0, "wins": 0, "fichas": 500},
		"ranked": {"season": 1, "points": 0, "mmr": Ranked.BASE_MMR, "peak_points": 0, "wins": 0, "losses": 0, "history": []},
		"cosmetics": {"owned": ["noite"], "equipped": "noite"},
	}


func load_game() -> void:
	data = defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY:
		_merge(data, parsed)


func save_game() -> void:
	if not persist:
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Tarolo: não foi possível salvar (%s)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))


func reset() -> void:
	data = defaults()
	save_game()


func section(name: String) -> Dictionary:
	return data[name]


## Mescla o save no dicionário padrão, mantendo chaves novas de versões futuras.
func _merge(base: Dictionary, incoming: Dictionary) -> void:
	for k in incoming.keys():
		if base.has(k) and typeof(base[k]) == TYPE_DICTIONARY and typeof(incoming[k]) == TYPE_DICTIONARY:
			_merge(base[k], incoming[k])
		else:
			base[k] = incoming[k]
