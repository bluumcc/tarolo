extends SceneTree
## Gera `assets/cards_md/` (360×600, reduzida com Lanczos) a partir de `assets/cards/` (540×900).
## O desktop usa essas cópias (nítidas, sem serrilhado); o celular usa as originais.
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
		img.resize(360, 600, Image.INTERPOLATE_LANCZOS)
		img.save_png("res://assets/cards_md/" + f)
		n += 1
	print("cards_md: %d imagens geradas" % n)
	quit()
