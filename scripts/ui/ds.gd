class_name DS
extends RefCounted
## Design system do Tarolo: tokens (tipografia, espaçamento, raios) e os poucos estilos-base que
## todo o resto reaproveita. Uma única família tipográfica (Lilita One, a do título TAROLO) e uma única
## linguagem de componentes: superfície escura, borda clara translúcida e brilho suave na cor da função.
## Regra: nenhuma tela inventa tamanho, margem ou raio — usa estes degraus.

# ---- Tipografia (px virtuais; 720 de largura em pé). Nada abaixo de CAPTION.
const FS_DISPLAY := 48   ## título de tela cheia (RODADA 1, ESCOLHA DUAS CARTAS...)
const FS_H1 := 40        ## título de modal
const FS_H2 := 32        ## subtítulo / título de seção
const FS_TITLE := 28     ## título de card, valores grandes
const FS_BODY := 24      ## texto corrido
const FS_LABEL := 20     ## legenda, rótulo de card
const FS_CAPTION := 18   ## o mínimo: dica, nota

# ---- Espaçamento (grade de 4)
const SP_XS := 4
const SP_S := 8          ## dentro de um grupo (título ↔ subtítulo, linhas de uma lista)
const SP_M := 12
const SP_L := 16         ## entre grupos
const SP_XL := 24        ## margem de tela
const SP_XXL := 32

# ---- Forma
const R_CARD := 16
const R_BUTTON := 14
const R_MODAL := 22
const BORDER := 2
const TAP_H := 64        ## altura mínima de botão tocável (celular)
const TAP_H_WIDE := 56   ## no desktop o mouse é mais preciso

## Superfície de card/modal (a mesma da barra lateral e dos cards da mesa).
static func surface() -> Color:
	return UIKit.TR_PURPLE_DARK.darkened(0.3)


static func rim() -> Color:
	return UIKit.TR_PURPLE_LIGHT


## Cores de função → como pintar um botão: fundo (tom escuro da cor), borda, brilho e texto.
static func tone(accent: Color) -> Dictionary:
	if accent == UIKit.MUTED or accent == UIKit.BUTTON_MUTED:
		return {"bg": UIKit.TR_PURPLE, "rim": UIKit.TR_PURPLE_LIGHT.lightened(0.35), "glow": UIKit.TR_PURPLE_LIGHT, "ink": UIKit.TR_WHITE}
	return {
		"bg": accent.darkened(0.72),
		"rim": accent.lightened(0.2),
		"glow": accent.darkened(0.25),
		"ink": accent.lightened(0.6),
	}


## Parágrafo de modal/tela: título (H1/H2) e subtítulo (BODY) com o respiro padrão entre eles.
static func heading(parent: Control, title: String, subtitle := "", title_size := FS_H1, color: Color = UIKit.TR_GOLD) -> void:
	var t := UIKit.label(title, title_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(t)
	if subtitle != "":
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, SP_S)
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(gap)
		var s := UIKit.label(subtitle, FS_BODY, UIKit.muted_lilac(), HORIZONTAL_ALIGNMENT_CENTER)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(s)
