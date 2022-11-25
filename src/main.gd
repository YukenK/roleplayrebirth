extends Control

var client: ENetConnection
var server: ENetConnection
var peer: ENetPacketPeer

var is_server: bool = false

# GUI Elements
var quit_button: Button
var connect_button: Button
var options_button: Button
var address_line: LineEdit
var name_line: LineEdit

var chat_line: LineEdit
var chat_box: RichTextLabel
var game_gui: Control

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

# Misc
var clients: Dictionary = {}
var client_connected = false
var mobs: Dictionary = {}


# MISC FUNCTIONS

func _ready():
	if "--server" in OS.get_cmdline_args():
		print("Running as server.")
		is_server = true
		server = ENetConnection.new()
		return server.create_host_bound("0.0.0.0", 5515, 32, 2)
	client = ENetConnection.new()
	client.create_host()
	quit_button = get_node("MenuPanel/Quit")
	quit_button.pressed.connect(self._on_quit_press)
	connect_button = get_node("MenuPanel/Connect")
	connect_button.pressed.connect(self._on_connect_press)
	address_line = get_node("MenuPanel/AddressLine")
	address_line.text_submitted.connect(self._on_address_entered)
	game_gui = get_node("GameGUI")
	chat_line = get_node("GameGUI/ChatLine")
	chat_line.text_submitted.connect(self._on_chat_entered)
	chat_box = get_node("GameGUI/ChatPanel/ChatBox")

# SERVER FUNCTIONS

func handle_connect_server(id):
	pass
func handle_disconnect_server(id):
	clients.erase(id)
	
func sync_clients_server(packet_peer: ENetPacketPeer): # When a new client connects, we'll run this for them.
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(SYNC_CLIENT_FULL)
	for i in range(0, server.get_peers().size()):
		var id = str(server.get_peers()[i].get_instance_id())
		var serialized_client = clients[id].serialize()
		bytes.append_array(serialized_client)
		if (i + 1 == server.get_peers().size()):
			bytes.append(0)
		else:
			bytes.append(1)
	packet_peer.send(1, bytes, ENetPacketPeer.FLAG_RELIABLE)
func sync_client_server(event: Array, id: String): # When a new client connects, this is ran for all existing clients including the new connector.
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(SYNC_CLIENT)
	var serialized_client = clients[id].serialize()
	bytes.append_array(serialized_client)
	for _peer in server.get_peers():
		_peer.send(1, serialized_client, ENetPacketPeer.FLAG_RELIABLE)
func handle_packet_server(event: Array):
	# We could combine these two functions into one, but that'll lead to a lot of ugly "if is_server" everywhere.
	# This is easier to read.
	if event[0] == server.EVENT_NONE:
		return
	var packet_peer: ENetPacketPeer = event[1]
	var id: String = str(packet_peer.get_instance_id())
	var id_buf = id.to_utf8_buffer()
	match event[0]:
		server.EVENT_CONNECT:
			clients[id] = Client.new()
			clients[id].id = id
			sync_clients_server(packet_peer)
			sync_client_server(event, id)
		server.EVENT_DISCONNECT:
			pass
		server.EVENT_RECEIVE:
			var pkt: Array = event[1].get_packet()
			match pkt[0]:
				CHAT_MESSAGE: handle_chat_server(event, pkt)
				_: pass
		_: pass
func handle_chat_server(event: Array, pkt: Array):
	var packet_peer: ENetPacketPeer = event[1]
	var bytes: PackedByteArray = PackedByteArray()
	var _client: Client = clients.get(str(packet_peer.get_instance_id()))
	var client_name_size = _client.name.to_utf8_buffer().size()
	var char_name_size = 0
	if _client.character != "":
		char_name_size = _client.character.to_utf8_buffer().size()
	bytes.append(CHAT_MESSAGE)
	bytes.append(client_name_size)
	bytes.append_array(_client.name.to_utf8_buffer())
	bytes.append(char_name_size)
	if char_name_size > 0:
		bytes.append_array(_client.character.to_utf8_buffer())
	bytes.append_array(pkt.slice(1, pkt.size()))
	server.broadcast(1, bytes, ENetPacketPeer.FLAG_RELIABLE)
# CLIENT FUNCTIONS
func try_connect(address: String, port: int):
	peer = client.connect_to_host(address, port, 2)
# Handle malformed addresses at a later date.
func _on_address_entered(text: String):
	var split_text = text.split(":")
	var address = split_text[0]
	var port = split_text[1]
	try_connect(address, int(port))
func _on_chat_entered(text: String):
	chat_line.clear()
	send_chat(text)
func _on_connect_press():
	if address_line.text == "":
		return
	_on_address_entered(address_line.text)
func _on_quit_press():
	get_tree().quit()
func handle_chat_client(event: Array, pkt: PackedByteArray):
	var client_name_size = pkt[1]
	var client_name: PackedByteArray = pkt.slice(1, 2 + client_name_size)
	var char_name_size = pkt[2 + client_name_size]
	var character_name = null
	var message = null
	if char_name_size > 0:
		character_name = pkt.slice(3 + client_name_size, char_name_size + 3 + client_name_size)
		message = pkt.slice(3 + client_name_size + char_name_size, pkt.size())
		chat_box.add_text(character_name.get_string_from_utf8() + " (" + client_name.get_string_from_utf8() + "): " + message.get_string_from_utf8() + "\n")
	else:
		message = pkt.slice(3 + client_name_size, pkt.size())
		chat_box.add_text(client_name.get_string_from_utf8() + ": " + message.get_string_from_utf8() + "\n")
func handle_connect_client(event: Array, pkt: PackedByteArray):
	pass
func handle_disconnect_client(event: Array, pkt: PackedByteArray):
	pass
func handle_sync_client(event: Array, pkt: PackedByteArray):
	var id = str(event[1].get_instance_id())
	if not clients.has(id):
		clients[id] = Client.new()
		clients[id].id = id
	var client_name_size = pkt[1]
	var client_name = pkt.slice(2, client_name_size + 2)
	var character_name_size = pkt[2 + client_name_size]
	var character_name = null
	if character_name_size:
		character_name = pkt.slice(client_name_size + 3, pkt.size())
func handle_full_sync_client(event: Array, pkt: PackedByteArray):
	var id = str(event[1].get_instance_id())
#	[TYPE, CLIENT_NAME_SIZE, CLIENT_NAME, optional CHARACTER_NAME_SIZE, optional CHARACTER_NAME, REPEAT]
	var offset = 0
	while true:
		if not clients.has(id):
			clients[id] = Client.new()
			clients[id].id = id
		var client_name_size = pkt[1 + offset]
		var client_name = pkt.slice(2 + offset, client_name_size + 2 + offset).get_string_from_utf8()
		clients[id].name = client_name
		var character_name_size = pkt[client_name_size + 2 + offset]
		var character_name = null
		if character_name_size:
			character_name = pkt.slice(client_name_size + 3 + offset, character_name_size + client_name_size + offset + 3).get_string_from_utf8()
			clients[id].character = character_name
		print(client_name)
		if not pkt[client_name_size + character_name_size + offset + 3]:
			return
		offset += client_name_size + character_name_size + 3

		
func handle_packet_client(event: Array):
	match event[0]:
		client.EVENT_CONNECT:
			self.get_node("MenuPanel").hide()
			self.get_node("GameGUI").show()
			client_connected = true
		client.EVENT_DISCONNECT:
			self.get_node("MenuPanel").show()
			self.get_node("GameGUI").hide()
			client_connected = false
		client.EVENT_RECEIVE:
			var pkt = event[1].get_packet()
			match pkt[0]:
				CHAT_MESSAGE:
					handle_chat_client(event, pkt)
				PLAYER_CONNECT:
					handle_connect_client(event, pkt)
				PLAYER_DISCONNECT:
					handle_disconnect_client(event, pkt)
				SYNC_CLIENT:
					handle_sync_client(event, pkt)
				SYNC_CLIENT_FULL:
					handle_full_sync_client(event, pkt)
		_: pass
func send_chat(text: String):
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(CHAT_MESSAGE)
	bytes.append_array(text.to_utf8_buffer())
	peer.send(1, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)
		# A chat message is formatted: [CHAT_MESSAGE, UTF_8 buffer] when sent to the server. 
	# The server will then broadcoast [CHAT_MESSAGE, CLIENT_NAME_SIZE, CLIENT_NAME, CHARACTER_NAME_SIZE (optional, set to 0 if no character), CHARACTER_NAME, UTF_8 BUFFER]

var event: Array = []
func _process(delta):
	event = []
	var packet_peer: ENetPacketPeer
	if is_server:
		event = server.service()
		while event[0] != server.EVENT_NONE:
			packet_peer = event[1]
			handle_packet_server(event)
			event = server.service()
		return
	event = client.service()
	while event[0] != client.EVENT_NONE:
		packet_peer = event[1]
		handle_packet_client(event)
		event = client.service()
	if client_connected:
		pass
