class_name Client extends Network

var id: String
var name: String = "YukenK"
var character: String = "Test_Name"
var peer: ENetPacketPeer

var client: ENetConnection
# GUI Elements
var main_menu: Control
var quit_button: Button
var connect_button: Button
var options_button: Button
var address_line: LineEdit
var name_line: LineEdit

var chat_line: LineEdit
var chat_box: RichTextLabel
var game_gui: Control

func init(_main_menu: Control):
	main_menu = _main_menu
	quit_button = main_menu.get_node("MenuPanel/Quit")
	quit_button.pressed.connect(self._on_quit_press)
	connect_button = main_menu.get_node("MenuPanel/Connect")
	connect_button.pressed.connect(self._on_connect_press)
	address_line = main_menu.get_node("MenuPanel/AddressLine")
	address_line.text_submitted.connect(self._on_address_entered)
	game_gui = main_menu.get_node("GameGUI")
	chat_line = main_menu.get_node("GameGUI/ChatLine")
	chat_line.text_submitted.connect(self._on_chat_entered)
	chat_box = main_menu.get_node("GameGUI/ChatPanel/ChatBox")
# [CLIENT_ID_SIZE, CLIENT_NAME_SIZE, CLIENT_CHARACTER_NAME_SIZE, CLIENT_ID, CLIENT_NAME, CLIENT_CHARACTER_NAME]
func serialize() -> PackedByteArray:
	var bytes: PackedByteArray = PackedByteArray()
	var id = self.id.to_utf8_buffer()
	var name = self.name.to_utf8_buffer()
	var char_name = self.character.to_utf8_buffer() if self.character != "" else null
	bytes.append(id.size())
	bytes.append(name.size())
	if char_name != null: 
		bytes.append(char_name.size())
	else:
		bytes.append(0)
	bytes.append_array(id)
	bytes.append_array(name)
	bytes.append_array(char_name) if char_name else null
	return bytes

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
	var id_size = pkt[1]
	var name_size = pkt[2]
	var char_name_size = pkt[3]
	var id = pkt.slice(4, 4 + id_size)
	var name = pkt.slice(4 + id_size, 4 + id_size + name_size)
	var char_name = ""
	if char_name_size > 0:
		char_name = pkt.slice(4 + id_size + name_size, pkt.size())
	var client: Client = Client.new()
	client.id = id
	client.name = name
	client.char_name = char_name
	clients[id] = client
func handle_packet_client(event: Array):
	pass
func send_chat(text: String):
	var bytes: PackedByteArray = PackedByteArray()
	bytes.append(CHAT_MESSAGE)
	bytes.append_array(text.to_utf8_buffer())
	peer.send(1, bytes, ENetPacketPeer.FLAG_UNSEQUENCED)
		# A chat message is formatted: [CHAT_MESSAGE, UTF_8 buffer] when sent to the server. 
	# The server will then broadcoast [CHAT_MESSAGE, CLIENT_NAME_SIZE, CLIENT_NAME, CHARACTER_NAME_SIZE (optional, set to 0 if no character), CHARACTER_NAME, UTF_8 BUFFER]
