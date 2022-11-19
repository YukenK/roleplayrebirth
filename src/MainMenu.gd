extends Node

const Mob = preload("res://src/Mob.gd")
const Client = preload("res://src/Client.gd")

var server: NetworkedMultiplayerENet = null
var client: NetworkedMultiplayerENet = null

var clients: Dictionary = {}

enum {
	CHAT_MESSAGE
}

func _ready():
	if "--server" in OS.get_cmdline_args():
		server = NetworkedMultiplayerENet.new()
		server.connect("peer_connected", self, "_peer_connected")
		server.connect("peer_disconnected", self, "_peer_disconnected")
		server.create_server(5515, 32)
		get_tree().network_peer = server
		return get_tree().get_root().set_network_master(1, true)
	set_process(false)
	client = NetworkedMultiplayerENet.new()
	get_tree().connect("connected_to_server", self, "_connected_to_server")
	get_tree().connect("server_disconnected", self, "_disconnect_from_server")
	client.connect("connection_failed", self, "_connection_failed")
	var connect_button = $PanelContainer/Panel/Connect
	connect_button.connect("pressed", self, "_on_connect_pressed")
	var quit_button = $PanelContainer/Panel/Quit
	quit_button.connect("pressed", self, "_on_quit_pressed")
func _connection_failed():
	set_process(false)
func _connected_to_server():
	set_process(true)
func _disconnect_from_server():
	set_process(false)
	get_tree().network_peer = null
func _on_connect_pressed():
	client.create_client("127.0.0.1", 5515)
	get_tree().network_peer = client
func _peer_connected(id):
	var _client = Client.new()
	_client.id = id
	clients[id] = _client
func handle_packet_server(id, dt):
	var pkt: PoolByteArray = server.get_packet()
	var pkt_type = pkt[0]
	var _client: Client = clients[id]
	server.set_target_peer(id)
	match pkt_type:
		CHAT_MESSAGE:
			# Chat message structure is TYPE, CHARACTER_NAME_SIZE, CHARACTER_NAME, DATA
			print(id, pkt.get_string_from_utf8())
			server.set_target_peer(server.TARGET_PEER_BROADCAST)
			var new_packet: PoolByteArray = PoolByteArray()
			var character: PoolByteArray = _client.character.to_utf8()
			new_packet.append(CHAT_MESSAGE)
			var name_size = 0
			new_packet.append(character.size())
			new_packet.append_array(character)
			new_packet.append_array(pkt.subarray(1, pkt.size()))
			server.put_packet(new_packet)
		_: pass
func handle_packet_client():
	var pkt: PoolByteArray = client.get_packet()
	var pkt_type = pkt[0]
	match pkt_type:
		CHAT_MESSAGE:
			var name_size = pkt[1]
			var name_buf: PoolByteArray = PoolByteArray()
			var name: String = ""
			for i in range(name_size):
				name_buf.append(pkt[i + 1])
			name = name_buf.get_string_from_utf8()
			var message = pkt.subarray(name_size, pkt.size() - name_size - 2)
			print(message)
		_: pass
func _process(dt):
	if is_network_master():
		server.poll()
		for i in range(server.get_available_packet_count()):
			handle_packet_server(server.get_packet_peer(), dt)
		return
	client.poll()
	for i in range(client.get_available_packet_count()):
		handle_packet_client()
func _on_quit_pressed():
	get_tree().quit()
