class_name Mob

# Mobs are our base movable entities. 
# Mobs can optionally be associated with a client.

var client_id: String
var icon: Sprite2D

var stats = {"health": 0, "energy": 0, "stamina": 0}

func serialize() -> PackedByteArray:
	pass
