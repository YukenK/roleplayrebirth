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
	var connect_button = $PanelContainer/Panel/Connect
	connect_button.connect("pressed", self, "_on_connect_pressed")
	var quit_button = $PanelContainer/Panel/Quit
	quit_button.connect("pressed", self, "_on_quit_pressed")
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
	server.set_target_peer(id)
	pkt.remove(0)
	match pkt_type:
		CHAT_MESSAGE:
			print(id, pkt.get_string_from_utf8())
			server.set_target_peer(-id)
			pkt.insert(0, CHAT_MESSAGE)
			server.put_packet(pkt)
		_: pass
func handle_packet_client():
	var pkt: PoolByteArray = client.get_packet()
	var pkt_type = pkt[0]
	pkt.remove(0)
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
