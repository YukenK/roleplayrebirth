extends Control

var host: Network

# Client connection will stay untrue until the server has synced us.
var client_connected: bool = false
var is_server: bool = false






func _ready():
	host = Network.new()
	host.conn = ENetConnection.new()
	if "--server" in OS.get_cmdline_args():
		print("Running as server.")
		return host.conn.create_host_bound("0.0.0.0", 5515, 32, 2)
	host.conn.create_host()
	host.init(self)

var event: Array = []
func _process(delta):
	event = []
	var packet_peer: ENetPacketPeer
	if is_server or client_connected:
		event = host.conn.service()
		while event[0] != ENetConnection.EVENT_NONE:
			packet_peer = event[1]
			host.handle_packet(event, packet_peer.get_packet())
			event = host.conn.service()
