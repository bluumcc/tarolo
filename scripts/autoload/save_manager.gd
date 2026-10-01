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
		"profile": {"name": "Arcanista", "gems": 0, "matches": 0, "wins": 0, "fichas": 1500, "blitz_levels": 0, "cash_balance": 0},
		"tournaments": {"titles": [], "trophies": 0, "history": []},
		"ranked": {"season": 1, "points": 0, "mmr": Ranked.BASE_MMR, "peak_points": 0, "wins": 0, "losses": 0, "history": []},
		"tips": {},
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
	_migrate_fragments_to_gems(parsed)


## Save antigo guardava a moeda cosmética como "fragments"; migra pra "gems" (chave atual) uma
## única vez, sem perder saldo de quem já jogava antes da troca de nome.
func _migrate_fragments_to_gems(parsed) -> void:
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var incoming_profile = parsed.get("profile", {})
	if typeof(incoming_profile) != TYPE_DICTIONARY or not incoming_profile.has("fragments"):
		return
	var profile: Dictionary = data["profile"]
	profile["gems"] = int(profile.get("gems", 0)) + int(incoming_profile["fragments"])
	profile.erase("fragments")


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
