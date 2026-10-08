class_name LocalAccountBackend
extends AccountBackend
## Backend de TESTE: guarda as contas só neste aparelho, em `user://tarolo_accounts.json`.
## Não sincroniza entre aparelhos e não protege nada de quem tem acesso ao arquivo: serve pra
## desenvolver telas e fluxo. Vai ser substituído por um backend de servidor (ver docs/CONTAS.md).

const HASH_ROUNDS := 5000

## Desliga a escrita em disco (testes).
var persist := true
var path := "user://tarolo_accounts.json"

var _db := {"accounts": {}, "session": ""}
var _loaded := false


func restore_session() -> Dictionary:
	_ensure_loaded()
	var acc = _db["accounts"].get(_db["session"], null)
	if acc == null:
		return fail("no_session")
	return ok(_public(acc))


func create_guest(display_name: String) -> Dictionary:
	_ensure_loaded()
	var err := AccountRules.validate_display_name(display_name)
	if err != "":
		return fail(err)
	var acc := {"id": _new_id(), "kind": "guest", "username": "", "display_name": AccountRules.clean_name(display_name),
		"created_at": int(Time.get_unix_time_from_system()), "salt": "", "hash": ""}
	return _activate(acc)


func sign_up(username: String, password: String, display_name: String) -> Dictionary:
	_ensure_loaded()
	var err := _validate_credentials(username, password)
	if err == "":
		err = AccountRules.validate_display_name(display_name)
	if err != "":
		return fail(err)
	if _find_by_username(username) != null:
		return fail("user_taken")
	var acc := {"id": _new_id(), "kind": "registered", "username": AccountRules.normalize_username(username),
		"display_name": AccountRules.clean_name(display_name), "created_at": int(Time.get_unix_time_from_system()), "salt": "", "hash": ""}
	_set_password(acc, password)
	return _activate(acc)


func sign_in(username: String, password: String) -> Dictionary:
	_ensure_loaded()
	var acc = _find_by_username(username)
	if acc == null or str(acc["hash"]) != _hash(password, str(acc["salt"])):
		return fail("bad_login")
	_db["session"] = acc["id"]
	_save()
	return ok(_public(acc))


func link_guest(username: String, password: String) -> Dictionary:
	_ensure_loaded()
	var acc = _db["accounts"].get(_db["session"], null)
	if acc == null:
		return fail("no_session")
	if str(acc["kind"]) != "guest":
		return fail("not_guest")
	var err := _validate_credentials(username, password)
	if err != "":
		return fail(err)
	if _find_by_username(username) != null:
		return fail("user_taken")
	acc["kind"] = "registered"
	acc["username"] = AccountRules.normalize_username(username)
	_set_password(acc, password)
	_save()
	return ok(_public(acc))


func update_display_name(display_name: String) -> Dictionary:
	_ensure_loaded()
	var acc = _db["accounts"].get(_db["session"], null)
	if acc == null:
		return fail("no_session")
	var err := AccountRules.validate_display_name(display_name)
	if err != "":
		return fail(err)
	acc["display_name"] = AccountRules.clean_name(display_name)
	_save()
	return ok(_public(acc))


func sign_out() -> Dictionary:
	_ensure_loaded()
	_db["session"] = ""
	_save()
	return ok({})


# ------------------------------------------------------------------ internos

func _validate_credentials(username: String, password: String) -> String:
	var err := AccountRules.validate_username(username)
	if err == "":
		err = AccountRules.validate_password(password, username)
	return err


func _activate(acc: Dictionary) -> Dictionary:
	_db["accounts"][acc["id"]] = acc
	_db["session"] = acc["id"]
	_save()
	return ok(_public(acc))


func _find_by_username(username: String):
	var u := AccountRules.normalize_username(username)
	for id in _db["accounts"]:
		if str(_db["accounts"][id]["username"]) == u and u != "":
			return _db["accounts"][id]
	return null


func _public(acc: Dictionary) -> Dictionary:
	return AccountBackend.make_account(str(acc["id"]), str(acc["kind"]), str(acc["username"]), str(acc["display_name"]), int(acc["created_at"]))


func _new_id() -> String:
	return "acc_" + Crypto.new().generate_random_bytes(8).hex_encode()


func _set_password(acc: Dictionary, password: String) -> void:
	acc["salt"] = Crypto.new().generate_random_bytes(16).hex_encode()
	acc["hash"] = _hash(password, str(acc["salt"]))


## SHA-256 iterado com sal. Suficiente pra não guardar senha em texto puro no arquivo de teste.
func _hash(password: String, salt: String) -> String:
	var data := (salt + password).to_utf8_buffer()
	for _i in range(HASH_ROUNDS):
		var ctx := HashingContext.new()
		ctx.start(HashingContext.HASH_SHA256)
		ctx.update(data)
		data = ctx.finish()
	return data.hex_encode()


func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	if not persist or not FileAccess.file_exists(path):
		return
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("accounts")) == TYPE_DICTIONARY:
		_db["accounts"] = parsed["accounts"]
		_db["session"] = str(parsed.get("session", ""))


func _save() -> void:
	if not persist:
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Tarolo: não foi possível salvar as contas (%s)" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(_db))
