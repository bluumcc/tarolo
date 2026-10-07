extends SceneTree
## Gera `assets/cards_md/` (432×720, reduzida com Lanczos) a partir de `assets/cards/` (qualquer tamanho, proporção 3:5 — ex.: 540×900 ou 720×1200).
## O jogo (celular e desktop) usa SÓ essas cópias: nítidas, sem serrilhado e leves na memória. As originais são o fonte.
## RODE SEMPRE QUE TROCAR/EDITAR UMA IMAGEM EM assets/cards/ (mesmos nomes de arquivo):
##   godot --headless --path . -s res://tools/gen_cards_md.gd
func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/cards_md")
	var d := DirAccess.open("res://assets/cards")
	var n := 0
	for f in d.get_files():
		if not f.ends_with(".png"):
			continue
		var img := Image.load_from_file("res://assets/cards/" + f)
		if img == null:
			continue
		img.resize(432, 720, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/cards_md/" + f)
		n += 1
	print("cards_md: %d imagens geradas" % n)
	quit()
