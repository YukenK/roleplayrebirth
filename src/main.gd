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
	SYNC_CLIENT_FULL, # [TYPE, CLIENT_NAME_SIZE, CLIENT_NAME, optional CHARACTER_NAME_SIZE, optional CHARACTER_NAME, REPEAT]
	# This syncs one client instead.
	SYNC_CLIENT,
}

# Misc
var clients: Dictionary = {}
var client_connected = false


# Grab a client's name and character name, pack into a byte array.
func client_to_utf8(_client: Client) -> PackedByteArray:
	var data: PackedByteArray = PackedByteArray()
	var buf = _client.name.to_utf8_buffer()
	data.append(buf.size())
	data.append_array(buf)
	buf = _client.character.to_utf8_buffer()
	if buf.size():
		data.append(buf.size())
		data.append_array(buf)
	else:
		data.append(0)
	return data
	
# MISC FUNCTIONS

func _ready():
	if "--server" in OS.get_cmdline_args():
		print("Running as server.")
		is_server = true
		server = ENetConnection.new()
		return server.create_host_bound("0.0.0.0", 5515, 32, 2)
	client = ENetConnection.new()
	client.create_host()
	quit_button = get_node("Panel/Quit")
	quit_button.pressed.connect(self._on_quit_press)
	connect_button = get_node("Panel/Connect")
	connect_button.pressed.connect(self._on_connect_press)
	address_line = get_node("Panel/AddressLine")
	address_line.text_submitted.connect(self._on_address_entered)


# SERVER FUNCTIONS

func handle_connect_server(id):
	pass
func handle_disconnect_server(id):
	clients.erase(id)
func sync_clients_server(packet_peer: ENetPacketPeer):
	pass
func sync_client_server(packet_peer: ENetPacketPeer):
	for _peer in server.get_peers():
		pass
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
			var _client = clients.get(id)
			handle_connect_server(id)
			var bytes: PackedByteArray = PackedByteArray()
			bytes.append(PLAYER_CONNECT & 0xFF)
			bytes.append(id_buf.size() & 0xFF)
			bytes.append_array(id_buf)
			var client_name = _client.name.to_utf8_buffer()
			bytes.append(client_name.size() & 0xFF)
			bytes.append_array(client_name)
			if _client.character != null:
				var char_name = _client.character.to_utf8_buffer()
				bytes.append(char_name.size())
				bytes.append_array(char_name)
			else:
				bytes.append(0)
			server.broadcast(1, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)
			sync_clients_server(packet_peer)
		server.EVENT_DISCONNECT:
			handle_disconnect_server(id)
			var bytes: PackedByteArray = PackedByteArray()
			bytes.append(PLAYER_DISCONNECT & 0xFF)
			bytes.append(id_buf.size() & 0xFF)
			bytes.append_array(id_buf)
			server.broadcast(1, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)
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
	print(_client)
	var client_name_size = _client.name.to_utf8_buffer().size()
	var char_name_size = 0
	if _client.character != null:
		char_name_size = _client.character.to_utf8_buffer().size()
	bytes.append(CHAT_MESSAGE)
	bytes.append(client_name_size & 0xFF)
	bytes.append_array(_client.name.to_utf8_buffer())
	bytes.append(char_name_size & 0xFF)
	if char_name_size > 0:
		bytes.append_array(_client.character.to_utf8_buffer())
	bytes.append_array(pkt.slice(1, pkt.size()))
	server.broadcast(1, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)
# CLIENT FUNCTIONS
func try_connect(address: String, port: int):
	peer = client.connect_to_host(address, port, 2)
# Handle malformed addresses at a later date.
func _on_address_entered(text: String):
	var split_text = text.split(":")
	var address = split_text[0]
	var port = split_text[1]
	try_connect(address, int(port))
func _on_connect_press():
	if address_line.text == "":
		return
	_on_address_entered(address_line.text)
func _on_quit_press():
	get_tree().quit()
func handle_chat_client(event: Array, pkt: PackedByteArray):
	var client_name_size = pkt[1]
	var client_name = pkt.slice(2, client_name_size).get_string_from_utf8()
	var char_name_size = pkt[3 + client_name_size]
	var character_name = null
	var message = null
	if char_name_size > 0:
		character_name = pkt.slice(4 + client_name_size, char_name_size).get_string_from_utf8()
		message = pkt.slice(5 + client_name_size + char_name_size, pkt.size())
	else:
		message = pkt.slice(4 + client_name_size, pkt.size())
	print(client_name, character_name if character_name.to_utf8_buffer().size() > 0 else null, message)
func handle_connect_client(event: Array, pkt: PackedByteArray):
	var packet_peer = event[1]
	var data = event[2]
	var id: String = str(packet_peer.get_instance_id())
	var id_buf = id.to_utf8_buffer()
	var _client: Client = Client.new()
	clients[id] = _client
	peer = client.get_peers()[0]

func handle_disconnect_client(event: Array, pkt: PackedByteArray):
	var data: PackedByteArray = event[2]
	var id = data.slice(1, data.size()).get_string_from_utf8()
	clients.erase(id)
	peer = null
func handle_packet_client(event: Array):
	# [TYPE, SIZE, ID, SIZE, CLIENT_NAME, SIZE, CHARACTER_NAME]
	match event[0]:
		client.EVENT_CONNECT:
			self.hide()
			client_connected = true
		client.EVENT_DISCONNECT:
			self.show()
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
		_: pass
func send_chat(text: String):
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(CHAT_MESSAGE)
	bytes.append_array(text.to_utf8_buffer())
	print(bytes.size())
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
		var n = PackedByteArray()
		send_chat("TEST")
