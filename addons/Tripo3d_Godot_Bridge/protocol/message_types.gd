# message_types.gd
# Protocol message builders and parsers
@tool
class_name MessageTypes

# --- Builders ---

static func handshake_ack(godot_version: String) -> Dictionary:
	return {
		"type": TripoBridgeProtocolConstants.MSG_HANDSHAKE_ACK,
		"payload": {
			"success": true,
			"clientName": TripoBridgeProtocolConstants.CLIENT_NAME,
			"dccVersion": godot_version,
			"pluginVersion": TripoBridgeProtocolConstants.PROTOCOL_VERSION,
			"protocolVersion": TripoBridgeProtocolConstants.PROTOCOL_VERSION
		}
	}

static func pong() -> Dictionary:
	return {"type": TripoBridgeProtocolConstants.MSG_PONG}

static func file_transfer_ack(file_id: String, file_index: int, success: bool, code: int = 0) -> Dictionary:
	return {
		"type": TripoBridgeProtocolConstants.MSG_FILE_TRANSFER_ACK,
		"payload": {
			"success": success,
			"fileId": file_id,
			"fileIndex": file_index,
			"code": code
		}
	}

static func file_transfer_complete(file_id: String, status: String, message: String) -> Dictionary:
	return {
		"type": TripoBridgeProtocolConstants.MSG_FILE_TRANSFER_COMPLETE,
		"payload": {
			"fileId": file_id,
			"status": status,
			"message": message
		}
	}

static func import_complete(file_id: String, success: bool, message: String) -> Dictionary:
	return {
		"type": TripoBridgeProtocolConstants.MSG_IMPORT_COMPLETE,
		"payload": {
			"fileId": file_id,
			"success": success,
			"message": message
		}
	}

# --- Parsers ---

static func get_type(json_obj: Dictionary) -> String:
	return json_obj.get("type", "")

static func get_payload(json_obj: Dictionary) -> Dictionary:
	var p = json_obj.get("payload", null)
	if p is Dictionary:
		return p
	return {}
