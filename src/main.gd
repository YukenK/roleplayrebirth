extends Control

var client: ENetConnection
var server: ENetConnection

var is_server: bool = false

# GUI Elements
var quit_button: Button
var connect_button: Button
var options_button: Button
var address_line: LineEdit
var name_line: LineEdit

#Enums
enum {
	CHAT_MESSAGE,
	PLAYER_CONNECT,
	PLAYER_DISCONNECT
}

# Misc
var clients: Dictionary = {}
var client_connected = false

func _ready():
	if "--server" in OS.get_cmdline_args():
		print("Running as server.")
		is_server = true
		server = ENetConnection.new()
		return server.create_host_bound("0.0.0.0", 5515)
	set_process(false)
	client = ENetConnection.new()
	quit_button = get_node("Panel/Quit")
	quit_button.pressed.connect(self._on_quit_press)
	connect_button = get_node("Panel/Connect")
	connect_button.pressed.connect(self._on_connect_press)
	address_line = get_node("Panel/AddressLine")
	address_line.text_submitted.connect(self._on_address_entered)
func _on_address_entered(text: String):
	pass
func _on_connect_press():
	client.connect_to_host("127.0.0.1", 5515)
func _on_quit_press():
	get_tree().quit()
func handle_connect_server(id):
	pass
func handle_disconnect_server(id):
	clients.erase(id)
func handle_packet_server(event: Array):
	# We could combine these two functions into one, but that'll lead to a lot of ugly "if is_server" everywhere.
	# This is easier to read.
	var packet_peer: ENetPacketPeer = event[1]
	var id: String = str(packet_peer.get_instance_id())
	var id_buf = id.to_utf8_buffer()
	match event[0]:
		server.EVENT_CONNECT:
			# Ultimately, whenever a player is connected, we will send a data array of [TYPE, SIZE, ID, SIZE, CLIENT_NAME, SIZE, CHARACTER_NAME]
			# Character name is optional; if size is 0, we won't send it.
			# Client names are not optional. For now, clients will choose a name before joining the server; eventually, proper auth.
			clients[id] = Client.new()
			var _client = clients[id]
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
			
			server.broadcast(1, bytes, server.FLAG_RELIABLE)
		server.EVENT_DISCONNECT:
			handle_disconnect_server(id)
			var bytes: PackedByteArray = PackedByteArray()
			bytes.append(PLAYER_DISCONNECT & 0xFF)
			bytes.append(id_buf.size() & 0xFF)
			bytes.append_array(id_buf)

			server.broadcast(1, bytes, server.FLAG_RELIABLE)
		server.EVENT_RECEIVE:
			pass
		_: pass
func handle_connect_client(event: Array):
	pass
func handle_disconnect_client(event: Array):
	pass
func handle_packet_client(event: Array):
	match event[0]:
		client.EVENT_CONNECT:
			client_connected = true
			set_process(true)
		client.EVENT_DISCONNECT:
			client_connected = false
			set_process(false)
		client.EVENT_RECEIVE:
			var data = event[2]
			match data[0]:
				PLAYER_CONNECT:
					handle_connect_client(event)
				PLAYER_DISCONNECT:
					handle_disconnect_client(event)
		_: pass
var event: Array = []
func _process(delta):
	var packet_peer: ENetPacketPeer
	if is_server and clients.size() > 0:
		event = server.service()
		while event:
			packet_peer = event[1]
			handle_packet_server(event)
			event = server.service()
	if client_connected:
		event = client.service()
		while event:
			packet_peer = event[1]
			handle_packet_client(event)
			event = client.service()
	event = []
