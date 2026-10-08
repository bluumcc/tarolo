class_name AccountBackend
extends RefCounted
## Contrato do backend de contas. O jogo e as telas só falam com `Accounts`/`AccountService`;
## quem guarda as contas de verdade é uma implementação deste contrato:
##   - `LocalAccountBackend`: teste, vale só neste aparelho.
##   - (futuro) um backend de servidor, trocando só quem é instanciado em `Accounts`.
##
## Todo método devolve {"ok": bool, "error": String, "account": Dictionary} e pode ser usado com
## `await` (um backend de rede responde depois). Conta = {id, kind: "guest"|"registered",
## username ("" no convidado), display_name, created_at}.


static func make_account(id: String, kind: String, username: String, display_name: String, created_at: int) -> Dictionary:
	return {"id": id, "kind": kind, "username": username, "display_name": display_name, "created_at": created_at}


static func ok(account: Dictionary) -> Dictionary:
	return {"ok": true, "error": "", "account": account}


static func fail(code: String) -> Dictionary:
	return {"ok": false, "error": code, "account": {}}


## Reabre a conta da sessão anterior (erro "no_session" se não houver).
func restore_session() -> Dictionary:
	return fail("not_implemented")


## Cria e ativa uma conta de convidado (só nome, sem senha).
func create_guest(_display_name: String) -> Dictionary:
	return fail("not_implemented")


## Cria e ativa uma conta nova com usuário e senha.
func sign_up(_username: String, _password: String, _display_name: String) -> Dictionary:
	return fail("not_implemented")


func sign_in(_username: String, _password: String) -> Dictionary:
	return fail("not_implemented")


## Promove o convidado ativo a conta com usuário e senha, mantendo o mesmo id e o mesmo nome.
func link_guest(_username: String, _password: String) -> Dictionary:
	return fail("not_implemented")


func update_display_name(_display_name: String) -> Dictionary:
	return fail("not_implemented")


## Encerra a sessão ativa (a conta continua existindo).
func sign_out() -> Dictionary:
	return fail("not_implemented")
