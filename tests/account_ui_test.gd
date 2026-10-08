extends Node
## Teste de interface da conta: abre o menu, navega pelos modais (perfil, trocar nome, criar conta,
## sair, entrar) preenchendo os formulários de verdade, e confere o estado da conta.
## Uso: godot --headless --path . res://tests/AccountUiTest.tscn

const MENU := preload("res://scenes/MainMenu.tscn")

var failures := 0
var menu: Node
var finished := false


func _ready() -> void:
	SaveManager.persist = false
	SaveManager.data = SaveManager.defaults()
	var be := LocalAccountBackend.new()
	be.persist = false
	await Accounts.use_backend(be)
	menu = MENU.instantiate()
	add_child(menu)
	await _frames()
	await _run()
	check(finished, "o teste chegou ao fim (um erro de script interrompe o fluxo)")
	print("ACCOUNT UI: %s" % ("OK" if failures == 0 else "%d falhas" % failures))
	get_tree().quit(1 if failures > 0 else 0)


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		printerr("FALHA: " + msg)


func _frames() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame


## Só olha dentro do modal aberto (o menu tem outros botões com o mesmo texto, como ENTRAR nos torneios).
func _root() -> Node:
	return menu._overlay


func _button(text: String) -> Button:
	for b in _root().find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Button).is_visible_in_tree():
			return b
	return null


func _edit(placeholder: String, secret_index := -1) -> LineEdit:
	var secrets := 0
	for e in _root().find_children("*", "LineEdit", true, false):
		var le := e as LineEdit
		if not le.is_visible_in_tree() or le.placeholder_text != placeholder:
			continue
		if secret_index < 0 or secrets == secret_index:
			return le
		secrets += 1
	return null


func _type(placeholder: String, text: String, secret_index := -1) -> void:
	var e := _edit(placeholder, secret_index)
	check(e != null, "campo '%s' (%d) existe na tela" % [placeholder, secret_index])
	if e != null:
		e.text = text


func _press(text: String) -> void:
	var b := _button(text)
	check(b != null, "botão '%s' existe na tela" % text)
	if b != null:
		b.pressed.emit()
	await _frames()


func _error_text() -> String:
	for l in _root().find_children("*", "Label", true, false):
		var lb := l as Label
		if lb.is_visible_in_tree() and lb.get_theme_color("font_color") == UIKit.LOSS and not lb.text.is_empty():
			return lb.text
	return ""


func _run() -> void:
	check(Accounts.is_guest() and Accounts.display_name().begins_with("Arcanista"), "o jogador começa como convidado com nome sorteado")

	menu._open_account()
	await _frames()
	check(_button("CRIAR CONTA") != null and _button("ENTRAR") != null and _button("SAIR DA CONTA") == null, "perfil de convidado oferece criar conta e entrar, sem sair")

	# Trocar nome
	await _press("TROCAR NOME")
	await _type("Arcanista", "a")
	await _press("SALVAR")
	check("pelo menos" in _error_text(), "nome curto mostra o erro na tela")
	await _type("Arcanista", "Maria")
	await _press("SALVAR")
	check(Accounts.display_name() == "Maria", "nome novo vale na conta")
	check(str(SaveManager.section("profile")["name"]) == "Maria" and GameState.player_name() == "Maria", "o nome chega ao save e às mesas")

	# Criar conta (promove o convidado)
	await _press("CRIAR CONTA")
	await _type("ex.: ana_01", "maria_01")
	await _type("sua senha", "senha1234", 0)
	await _type("sua senha", "diferente1", 1)
	await _press("CRIAR CONTA")
	check("iguais" in _error_text() and Accounts.is_guest(), "senhas diferentes são recusadas na tela")
	await _type("sua senha", "senha1234", 1)
	await _press("CRIAR CONTA")
	check(Accounts.is_registered() and Accounts.username() == "maria_01" and Accounts.display_name() == "Maria", "criar conta registra o convidado mantendo o nome")
	check(_button("SAIR DA CONTA") != null and _button("CRIAR CONTA") == null, "perfil de conta oferece sair, sem criar")

	# Sair e entrar de volta
	await _press("SAIR DA CONTA")
	check(Accounts.is_guest() and Accounts.display_name() != "Maria", "sair devolve um convidado novo")
	await _press("ENTRAR")
	await _type("seu_usuario", "maria_01")
	await _type("sua senha", "errada1234")
	await _press("ENTRAR")
	check("incorretos" in _error_text() and Accounts.is_guest(), "senha errada é recusada na tela")
	await _type("sua senha", "senha1234")
	await _press("ENTRAR")
	check(Accounts.is_registered() and Accounts.display_name() == "Maria", "entrar recupera a conta e o nome")

	# Atalho nas configurações
	await _press("FECHAR")
	menu._open_settings()
	await _frames()
	check(_button("GERENCIAR CONTA") != null, "as configurações têm o atalho da conta")
	finished = true
