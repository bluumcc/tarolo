# Contas de jogador

Base para chat, emojis, ranking e PvP: todo jogador tem uma **conta** com id, nome de exibição e,
opcionalmente, usuário e senha. Hoje tudo roda **dentro do jogo, sem servidor** (versão de teste).

## Como o jogador entra
- **Convidado primeiro:** ao abrir o jogo pela primeira vez, ele já tem uma conta de convidado com um
  nome sorteado (ex.: `Arcanista4821`), sem cadastro. Se o save antigo tinha um nome próprio, esse
  nome é aproveitado.
- **Criar conta:** o convidado vira conta registrada (usuário + senha), **mantendo o mesmo id e o
  mesmo nome**. Não há email ainda.
- **Entrar / sair:** entrar numa conta existente troca a conta ativa; sair devolve um convidado
  novo (o jogador nunca fica sem identidade).
- **Onde fica:** CONFIG → **CONTA** (e em Configurações → Gerenciar conta).

## Camadas (`scripts/core/` e `scripts/autoload/`)
| Peça | Papel |
|---|---|
| `AccountRules` | Regras puras: nome (3–16, letras/números/espaço/_/-), usuário (3–16, `a-z0-9_`), senha (8–64), textos de erro |
| `AccountBackend` | **Contrato** de quem guarda as contas: `restore_session`, `create_guest`, `sign_up`, `sign_in`, `link_guest`, `update_display_name`, `sign_out` |
| `LocalAccountBackend` | Implementação de **teste**: arquivo `user://tarolo_accounts.json` neste aparelho |
| `AccountService` | Conta ativa e fluxos (convidado → cadastrada → sair). Sem autoload, por isso é testável |
| `Accounts` (autoload) | Fachada usada pelo jogo; `GameState.player_name()` vem daqui. `use_backend()` troca o backend |
| `AccountForms` (`scripts/ui/`) | Telas: perfil, entrar, criar conta, trocar nome (dentro do modal do menu) |

Todo método do backend devolve `{ok, error, account}` e pode ser `await`ado, pensando no servidor.

## Limites do backend local (importante)
- **Não é seguro e não sincroniza:** a conta só existe neste aparelho; quem tem o arquivo mexe nele.
  A senha é guardada com sal e SHA-256 iterado só para não ficar em texto puro.
- **Não há recuperação de senha** (sem email) nem verificação de nada.
- O save de progresso (fichas, elo) continua **por aparelho**, separado da conta.

## Caminho para o servidor
1. Escolher o servidor (opções discutidas: Nakama no VPS, que já traz contas, chat, presença e
   matchmaking; ou Supabase).
2. Implementar um `AccountBackend` que fale com ele e trocar a linha em `Accounts._ready()`
   (`use_backend(...)`). Telas, `AccountService` e testes não mudam.
3. Servidor repete as regras de `AccountRules`, aplica limite de tentativas e guarda a senha com
   hash forte (argon2/bcrypt). Decidir email (recuperação de senha, LGPD) e política de privacidade.
4. Só então: chat e emojis (identidade = `account.id` + `display_name`), com moderação (denunciar,
   bloquear, filtro de nomes), exigência das lojas para conteúdo gerado por usuários.

## Testes
- Lógica: `godot --headless --path . -s res://tests/test_runner.gd` (`_test_accounts`).
- Telas (navega pelos modais e preenche os formulários):
  `godot --headless --path . res://tests/AccountUiTest.tscn`.
