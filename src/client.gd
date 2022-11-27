class_name Client extends Network

var id: int
var name: String = "YukenK"
var character: String = "Test_Name"
var peer: ENetPacketPeer

var client: ENetConnection

func serialize() -> PackedByteArray:
	var data: PackedByteArray = PackedByteArray()
	var buf = self.name.to_utf8_buffer()
	data.append(buf.size())
	data.append_array(buf)
	buf = self.character.to_utf8_buffer()
	if buf.size():
		data.append(buf.size())
		data.append_array(buf)
	else:
		data.append(0)
	return data

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
	self.get_tree().quit()
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
	pass
func handle_full_sync_client(event: Array, pkt: PackedByteArray):
	pass
func handle_packet_client(event: Array):
	pass
func send_chat(text: String):
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(CHAT_MESSAGE)
	bytes.append_array(text.to_utf8_buffer())
	peer.send(1, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)
		# A chat message is formatted: [CHAT_MESSAGE, UTF_8 buffer] when sent to the server. 
	# The server will then broadcoast [CHAT_MESSAGE, CLIENT_NAME_SIZE, CLIENT_NAME, CHARACTER_NAME_SIZE (optional, set to 0 if no character), CHARACTER_NAME, UTF_8 BUFFER]
