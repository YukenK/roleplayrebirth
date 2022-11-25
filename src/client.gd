class_name Client

var id: int
var name: String = "YukenK"
var character: String = "Test_Name"
var peer: ENetPacketPeer

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
