class_name Network

#Enums
enum {
	# A chat message is formatted: [CHAT_MESSAGE, UTF_8 buffer] when sent to the server. 
	# The server will then broadcoast [CHAT_MESSAGE, CLIENT_NAME_SIZE, CLIENT_NAME, CHARACTER_NAME_SIZE (optional, set to 0 if no character), CHARACTER_NAME, UTF_8 BUFFER]
	CHAT_MESSAGE,
	# Ultimately, whenever a player is connected, we will send a data array of [TYPE, SIZE, ID, SIZE, CLIENT_NAME, SIZE, CHARACTER_NAME]
	# Character name is optional; if size is 0, we won't send it.
	# Client names are not optional. For now, clients will choose a name before joining the server; eventually, proper auth.
	PLAYER_CONNECT,
	PLAYER_DISCONNECT, #[TYPE, ID] - We only need the type & ID of a client to disconnect it.
	PLAYER_INPUT, # [TYPE, ACTION, IS_BUTTON_PRESSED] If this is a release, IS_BUTTON_PRESSED == false.
	# This is a _full sync_ of all existing clients on the server.
	SYNC_CLIENT_FULL, # [TYPE, CLIENT_ID_SIZE, CLIENT_ID, CLIENT_NAME_SIZE, CLIENT_NAME, optional CHARACTER_NAME_SIZE, optional CHARACTER_NAME, REPEAT]
	# This syncs one client instead - same format as above, minus REPEAT.
	SYNC_CLIENT,
}

var clients = []
var conn: ENetConnection

func handle_packet(event: Array, pkt: PackedByteArray):
	pass
