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
		print(clients.size())
