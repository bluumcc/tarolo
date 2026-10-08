class_name AccountRules
extends RefCounted
## Regras puras de conta (sem rede e sem disco): validação de nome, usuário e senha, e os
## textos de erro mostrados nas telas. O servidor real deve repetir estas mesmas regras.

const NAME_MIN := 3
const NAME_MAX := 16
const USER_MIN := 3
const USER_MAX := 16
const PASS_MIN := 8
const PASS_MAX := 64
const GUEST_BASE := "Arcanista"

static var _name_rx := RegEx.create_from_string("^[\\p{L}\\p{N}_-]+( [\\p{L}\\p{N}_-]+)*$")
static var _user_rx := RegEx.create_from_string("^[a-z0-9_]+$")


## Nome de exibição limpo: sem espaços nas pontas e sem espaços repetidos.
static func clean_name(raw: String) -> String:
	return " ".join(raw.strip_edges().split(" ", false))


## Usuário de login: minúsculo e sem espaços nas pontas (quem digita "Ana_01 " entra como "ana_01").
static func normalize_username(raw: String) -> String:
	return raw.strip_edges().to_lower()


## "" = válido; senão o código do erro (ver `error_text`).
static func validate_display_name(raw: String) -> String:
	var n := clean_name(raw)
	if n.length() < NAME_MIN:
		return "name_short"
	if n.length() > NAME_MAX:
		return "name_long"
	if _name_rx.search(n) == null:
		return "name_chars"
	return ""


static func validate_username(raw: String) -> String:
	var u := normalize_username(raw)
	if u.length() < USER_MIN:
		return "user_short"
	if u.length() > USER_MAX:
		return "user_long"
	if _user_rx.search(u) == null:
		return "user_chars"
	return ""


static func validate_password(password: String, username: String = "") -> String:
	if password.length() < PASS_MIN:
		return "pass_short"
	if password.length() > PASS_MAX:
		return "pass_long"
	if not username.is_empty() and password.to_lower() == normalize_username(username):
		return "pass_same_as_user"
	return ""


## Nome automático de convidado (ex.: Arcanista4821), único o bastante pra mesa e pro chat.
static func guest_name(rng: RandomNumberGenerator = null) -> String:
	var r := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	return "%s%04d" % [GUEST_BASE, r.randi_range(0, 9999)]


static func error_text(code: String) -> String:
	match code:
		"name_short": return "O nome precisa de pelo menos %d letras." % NAME_MIN
		"name_long": return "O nome pode ter no máximo %d caracteres." % NAME_MAX
		"name_chars": return "Use só letras, números, espaço, _ e -."
		"user_short": return "O usuário precisa de pelo menos %d caracteres." % USER_MIN
		"user_long": return "O usuário pode ter no máximo %d caracteres." % USER_MAX
		"user_chars": return "No usuário use só letras sem acento, números e _."
		"pass_short": return "A senha precisa de pelo menos %d caracteres." % PASS_MIN
		"pass_long": return "A senha pode ter no máximo %d caracteres." % PASS_MAX
		"pass_same_as_user": return "A senha não pode ser igual ao usuário."
		"pass_mismatch": return "As senhas não são iguais."
		"user_taken": return "Esse usuário já existe."
		"bad_login": return "Usuário ou senha incorretos."
		"not_guest": return "Você já tem uma conta."
		"no_session": return "Nenhuma conta ativa."
		"backend_error": return "Não deu certo agora. Tente de novo."
		_: return "Algo deu errado (%s)." % code
