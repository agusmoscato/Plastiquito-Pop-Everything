extends GutTest


func test_title_bubbles_pop_and_regrow() -> void:
	var t: TitleScreen = TitleScreen.new()
	add_child_autofree(t)
	var c: Vector2 = t.bubble_center(3)
	assert_eq(t.bubble_at(c), 3, "el clic en el centro cae en esa burbuja")
	t.pop_bubble(3)
	assert_eq(t.bubble_at(c), -1, "reventada: ya no se puede volver a reventar")
	for i: int in 200:
		t._process(0.02)
	assert_eq(t.bubble_at(c), 3, "se vuelve a inflar sola")
	t._start()
	assert_false(t.is_open())
	assert_false(get_tree().paused, "al empezar, el juego deja de estar pausado")
