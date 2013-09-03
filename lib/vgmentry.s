	; where the player is located in RAM.
	.alias music_player $e05
	.alias music_player_size 1024

	.alias music_initialize music_player
	.alias music_poll music_player+3
	.alias music_deinitialize music_player+6
