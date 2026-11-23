extends GutTest
## Steam en las builds: la de playtest sale con Steam apagado (ficha de nombre); la "steamtest" y desarrollo lo
## intentan, y si el cliente está cerrado o falta steam_appid.txt el juego sigue sin Steam (nunca se traba).


func after_each() -> void:
	PlayerIdentity.reset()


func test_which_builds_use_steam() -> void:
	assert_false(PlaytestMode.steam_allowed(PackedStringArray(["playtest"])), "playtest: apagado")
	assert_false(PlaytestMode.steam_allowed(PackedStringArray(["release"])), "release: apagado")
	assert_true(PlaytestMode.steam_allowed(PackedStringArray(["playtest", "steam"])), "steamtest: encendido")
	assert_true(PlaytestMode.steam_allowed(PackedStringArray(["editor", "debug"])), "desarrollo: encendido")


func test_playtest_build_never_touches_steam() -> void:
	PlayerIdentity.reset()
	PlayerIdentity.try_steam(PackedStringArray(["playtest"]))
	assert_eq(PlayerIdentity.steam_status, "desactivado")
	assert_eq(PlayerIdentity.steam_name, "", "sin nombre de Steam: se pide la ficha")


func test_steam_build_survives_whatever_steam_answers() -> void:
	# Con el cliente abierto se conecta; cerrado (o en CI, sin cliente) el init falla y vuelve igual.
	PlayerIdentity.reset()
	var t0: int = Time.get_ticks_msec()
	PlayerIdentity.try_steam(PackedStringArray(["playtest", "steam"]))
	assert_ne(PlayerIdentity.steam_status, "desactivado", "la build steamtest sí lo intenta")
	assert_lt(Time.get_ticks_msec() - t0, 10000, "el intento no traba el arranque")
	PlayerIdentity.try_steam(PackedStringArray(["playtest", "steam"])) # un segundo llamado no hace nada
