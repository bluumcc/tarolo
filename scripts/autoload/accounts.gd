extends Node
## A conta do jogador (nome, convidado ou cadastrada). Fachada fina sobre `AccountService`: o
## resto do jogo só usa isto. Hoje o backend é local (teste); trocar pelo servidor é mudar a linha
## de `service` abaixo. Ver docs/CONTAS.md.

signal changed

var service: AccountService


func _ready() -> void:
	await use_backend(LocalAccountBackend.new())


## Liga o jogo a um backend de contas (o local de teste hoje; o servidor depois) e reabre a sessão.
func use_backend(backend: AccountBackend) -> void:
	service = AccountService.new(backend)
	service.changed.connect(_on_changed)
	await service.start(str(SaveManager.section("profile").get("name", "")))


## Nome mostrado nas mesas. Até a conta carregar, vale o nome do save antigo.
func display_name() -> String:
	if service != null and service.has_account():
		return service.display_name()
	return str(SaveManager.section("profile")["name"])


func username() -> String:
	return service.username()


func is_guest() -> bool:
	return service.is_guest()


func is_registered() -> bool:
	return service.is_registered()


func create_account(username_in: String, password: String) -> Dictionary:
	return await service.create_account(username_in, password)


func sign_in(username_in: String, password: String) -> Dictionary:
	return await service.sign_in(username_in, password)


func sign_out() -> void:
	await service.sign_out()


func rename(new_name: String) -> Dictionary:
	return await service.rename(new_name)


## O nome também fica no save, pra não perder o nome de quem já jogava antes das contas.
func _on_changed() -> void:
	SaveManager.section("profile")["name"] = service.display_name()
	SaveManager.save_game()
	changed.emit()
