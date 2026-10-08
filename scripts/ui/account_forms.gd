class_name AccountForms
extends RefCounted
## Telas da conta dentro do modal do menu: perfil, entrar, criar conta e trocar nome.
## `body` é a área rolável do modal, `footer` é onde ficam os botões, `close` fecha o modal e
## `reopen(mode)` fecha e abre de novo na tela pedida ("", "signin", "signup" ou "rename").


static func title_for(mode: String) -> String:
	match mode:
		"signin": return "ENTRAR"
		"signup": return "CRIAR CONTA"
		"rename": return "TROCAR NOME"
		_: return "CONTA"


static func build(body: VBoxContainer, footer: Node, close: Callable, reopen: Callable, mode: String = "") -> void:
	match mode:
		"signin": _build_signin(body, footer, reopen)
		"signup": _build_signup(body, footer, reopen)
		"rename": _build_rename(body, footer, reopen)
		_: _build_profile(body, footer, close, reopen)


static func _build_profile(body: VBoxContainer, footer: Node, close: Callable, reopen: Callable) -> void:
	var guest: bool = Accounts.is_guest()
	body.add_child(UIKit.label(Accounts.display_name(), 40, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	body.add_child(UIKit.label("CONVIDADO" if guest else "@" + Accounts.username(), 22, UIKit.MUTED if guest else UIKit.BRAND, HORIZONTAL_ALIGNMENT_CENTER))
	if guest:
		body.add_child(_note("Você está jogando como convidado. Crie uma conta para ter um usuário seu e poder entrar de novo depois."))
	body.add_child(_note("Versão de teste: as contas valem só neste aparelho por enquanto."))
	if guest:
		_add_button(footer, "CRIAR CONTA", UIKit.ACTION, func(): reopen.call("signup"))
		_add_button(footer, "ENTRAR", UIKit.MUTED, func(): reopen.call("signin"))
	_add_button(footer, "TROCAR NOME", UIKit.MUTED, func(): reopen.call("rename"))
	if not guest:
		_add_button(footer, "SAIR DA CONTA", UIKit.LOSS, func():
			await Accounts.sign_out()
			reopen.call(""))
	_add_button(footer, "FECHAR", UIKit.MUTED, close)


static func _build_signin(body: VBoxContainer, footer: Node, reopen: Callable) -> void:
	var user := _field(body, "Usuário", "seu_usuario", false, AccountRules.USER_MAX)
	var pw := _field(body, "Senha", "sua senha", true, AccountRules.PASS_MAX)
	var err := _error_label(body)
	var go := _add_button(footer, "ENTRAR", UIKit.ACTION, Callable())
	go.pressed.connect(func():
		await _submit(go, err, func(): return await Accounts.sign_in(user.text, pw.text), func(): reopen.call("")))
	_submit_on_enter([user, pw], go)
	_add_button(footer, "VOLTAR", UIKit.MUTED, func(): reopen.call(""))


static func _build_signup(body: VBoxContainer, footer: Node, reopen: Callable) -> void:
	body.add_child(_note("Seu nome nas mesas continua \"%s\" (dá para trocar depois)." % Accounts.display_name()))
	var user := _field(body, "Usuário (para entrar)", "ex.: ana_01", false, AccountRules.USER_MAX)
	var pw := _field(body, "Senha (mínimo %d caracteres)" % AccountRules.PASS_MIN, "sua senha", true, AccountRules.PASS_MAX)
	var pw2 := _field(body, "Repita a senha", "sua senha", true, AccountRules.PASS_MAX)
	var err := _error_label(body)
	var go := _add_button(footer, "CRIAR CONTA", UIKit.ACTION, Callable())
	go.pressed.connect(func():
		if pw.text != pw2.text:
			err.text = AccountRules.error_text("pass_mismatch")
			return
		await _submit(go, err, func(): return await Accounts.create_account(user.text, pw.text), func(): reopen.call("")))
	_submit_on_enter([user, pw, pw2], go)
	_add_button(footer, "VOLTAR", UIKit.MUTED, func(): reopen.call(""))


static func _build_rename(body: VBoxContainer, footer: Node, reopen: Callable) -> void:
	var nm := _field(body, "Nome nas mesas", "Arcanista", false, AccountRules.NAME_MAX)
	nm.text = Accounts.display_name()
	var err := _error_label(body)
	var go := _add_button(footer, "SALVAR", UIKit.ACTION, Callable())
	go.pressed.connect(func():
		await _submit(go, err, func(): return await Accounts.rename(nm.text), func(): reopen.call("")))
	_submit_on_enter([nm], go)
	_add_button(footer, "VOLTAR", UIKit.MUTED, func(): reopen.call(""))


# ------------------------------------------------------------------ peças

## Roda `action` (que devolve o resultado do backend), trava o botão enquanto espera e, no sucesso,
## chama `on_ok`; no erro, mostra o texto na tela. O modal pode ter sido fechado nesse meio-tempo.
static func _submit(btn: Button, err: Label, action: Callable, on_ok: Callable) -> void:
	btn.disabled = true
	err.text = ""
	var r: Dictionary = await action.call()
	if not is_instance_valid(btn):
		return
	btn.disabled = false
	if bool(r["ok"]):
		on_ok.call()
	else:
		err.text = AccountRules.error_text(str(r["error"]))


static func _field(parent: Control, caption: String, placeholder: String, secret: bool, max_len: int) -> LineEdit:
	parent.add_child(UIKit.label(caption, 20))
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.max_length = max_len
	e.custom_minimum_size = Vector2(0, 48)
	e.add_theme_stylebox_override("normal", UIKit.box(UIKit.PURPLE_DEEP, UIKit.MUTED, 2, 6, 10))
	e.add_theme_stylebox_override("focus", UIKit.box(UIKit.PURPLE_DEEP, UIKit.BRAND, 2, 6, 10))
	e.add_theme_color_override("font_color", UIKit.INK)
	e.add_theme_color_override("font_placeholder_color", UIKit.MUTED)
	parent.add_child(e)
	return e


## Enter no último campo envia; nos outros, vai pro próximo campo.
static func _submit_on_enter(fields: Array, go: Button) -> void:
	for i in range(fields.size()):
		var e: LineEdit = fields[i]
		if i == fields.size() - 1:
			e.text_submitted.connect(func(_t: String): go.pressed.emit())
		else:
			var nxt: LineEdit = fields[i + 1]
			e.text_submitted.connect(func(_t: String): nxt.grab_focus())


static func _error_label(parent: Control) -> Label:
	var l := UIKit.label("", 20, UIKit.LOSS, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


static func _note(text: String) -> Label:
	var l := UIKit.label(text, 20, UIKit.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func _add_button(parent: Node, text: String, accent: Color, on_press: Callable) -> Button:
	var b := UIKit.button(text, accent)
	if on_press.is_valid():
		b.pressed.connect(on_press)
	parent.add_child(b)
	return b
