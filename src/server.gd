class_name Server extends Network

# SERVER FUNCTIONS

func handle_connect_server(id):
	pass
func handle_disconnect_server(id):
	pass
# These two functions might be able to be combined, but I'm leaving them separate even if there is some code repetition.
func sync_clients_server(packet_peer: ENetPacketPeer): # When a new client connects, we'll run this for them.
	# [TYPE, CLIENT_ID_SIZE, CLIENT_NAME_SIZE, CLIENT_CHARACTER_NAME_SIZE, CLIENT_ID, CLIENT_NAME, CLIENT_CHARACTER_NAME]
	for client in self.clients:
		var bytes: PackedByteArray = PackedByteArray()
		bytes.append(SYNC_CLIENT)
		bytes.append_array(client.serialize())
		packet_peer.send(1, bytes, ENetConnection.FLAG_RELIABLE)
func sync_client_server(event: Array, _id: String): # When a new client connects, this is ran for all existing clients including the new connector.
	# This will also be used to sync name changes, or when a user creates their character.
	var client: Client = clients[_id]
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(SYNC_CLIENT)
	bytes.append_array(client.serialize())
func handle_packet_server(event: Array):
	# We could combine these two functions into one, but that'll lead to a lot of ugly "if is_server" everywhere.
	# This is easier to read.
	if event[0] == ENetConnection.EVENT_NONE:
		return
	var packet_peer: ENetPacketPeer = event[1]
	var id: String = str(packet_peer.get_instance_id())
	var id_buf = id.to_utf8_buffer()
	match event[0]:	
		ENetConnection.EVENT_CONNECT:
			clients[id] = Client.new()
			clients[id].id = id
			sync_clients_server(packet_peer)
			sync_client_server(event, id)
		ENetConnection.EVENT_DISCONNECT:
			pass
		ENetConnection.EVENT_RECEIVE:
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
	conn.broadcast(1, bytes, ENetPacketPeer.FLAG_RELIABLE)
