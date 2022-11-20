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
	CHAT_MESSAGE
}

# Misc
var clients: Dictionary = {}
var ids: Dictionary = {}
var is_connected = false

func _ready():
	if "--server" in OS.get_cmdline_args():
		print("Running as server.")
		is_server = true
		server = ENetConnection.new()
		server.peer_disconnected.connect(self._peer_disconnect)
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
func handle_packet_server(event: Array):
	# We could combine these two functions into one, but that'll lead to a lot of ugly "if is_server" everywhere.
	# This is easier to read.
	var packet_peer: ENetPacketPeer = event[1]
	match event[0]:
		server.EVENT_CONNECT:
			packet_peer.get_remote_address()
		server.EVENT_DISCONNECT:
			pass
		server.EVENT_RECEIVE:
			pass
		_: pass
func handle_packet_client():
	pass
var event: Array = []
func _process(delta):
	var packet_peer: ENetPacketPeer
	if is_server:
		event = server.service()
		while event:
			packet_peer = event[1]
			handle_packet_server(event)
			event = server.service()
	if is_connected:
		event = client.service()
		while event:
			event = client.service()
		packet_peer = event[1]
		while event:
			handle_packet_client()
	event = null
