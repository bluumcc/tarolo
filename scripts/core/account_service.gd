class_name AccountService
extends RefCounted
## Estado e regras da conta ativa, por cima de um `AccountBackend`. Sem autoload e sem disco do
## jogo (por isso é testável); o autoload `Accounts` só liga isto ao resto do jogo.

signal changed

var backend: AccountBackend
var current: Dictionary = {}


func _init(b: AccountBackend) -> void:
	backend = b


func has_account() -> bool:
	return not current.is_empty()


func id() -> String:
	return str(current.get("id", ""))


func display_name() -> String:
	return str(current.get("display_name", ""))


func username() -> String:
	return str(current.get("username", ""))


func is_guest() -> bool:
	return str(current.get("kind", "")) == "guest"


func is_registered() -> bool:
	return str(current.get("kind", "")) == "registered"


## Reabre a sessão anterior; sem sessão, entra como convidado com o nome preferido (se for um nome
## válido e não o genérico) ou com um nome sorteado.
func start(preferred_name: String = "", rng: RandomNumberGenerator = null) -> void:
	var r: Dictionary = await backend.restore_session()
	if bool(r["ok"]):
		_activate(r["account"])
		return
	await _new_guest(preferred_name, rng)


## Criar conta: o convidado ativo é promovido (mantém id e nome); sem convidado, cria uma nova.
func create_account(username_in: String, password: String) -> Dictionary:
	var r: Dictionary
	if is_guest():
		r = await backend.link_guest(username_in, password)
	else:
		var nm := display_name() if has_account() else AccountRules.guest_name()
		r = await backend.sign_up(username_in, password, nm)
	return _apply(r)


func sign_in(username_in: String, password: String) -> Dictionary:
	return _apply(await backend.sign_in(username_in, password))


## Sair da conta devolve o jogador a um convidado novo (nunca fica sem identidade).
func sign_out() -> void:
	await backend.sign_out()
	current = {}
	await _new_guest("", null)


func rename(new_name: String) -> Dictionary:
	return _apply(await backend.update_display_name(new_name))


# ------------------------------------------------------------------ internos

func _new_guest(preferred_name: String, rng: RandomNumberGenerator) -> void:
	var nm := AccountRules.clean_name(preferred_name)
	if nm == AccountRules.GUEST_BASE or AccountRules.validate_display_name(nm) != "":
		nm = AccountRules.guest_name(rng)
	var r: Dictionary = await backend.create_guest(nm)
	if bool(r["ok"]):
		_activate(r["account"])


func _apply(r: Dictionary) -> Dictionary:
	if bool(r["ok"]):
		_activate(r["account"])
	return r


func _activate(account: Dictionary) -> void:
	current = account
	changed.emit()
