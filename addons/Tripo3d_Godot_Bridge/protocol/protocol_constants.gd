# protocol_constants.gd
# WebSocket protocol constants and message types
@tool
class_name TripoBridgeProtocolConstants

# Server Configuration
const SERVER_HOST: String = "127.0.0.1"
const SERVER_PORT: int = 60650
const PROTOCOL_VERSION: String = "1.0.0"
const CLIENT_NAME: String = "Godot"

# Message Types
const MSG_HANDSHAKE: String = "handshake"
const MSG_HANDSHAKE_ACK: String = "handshake_ack"
const MSG_PING: String = "ping"
const MSG_PONG: String = "pong"
const MSG_FILE_TRANSFER: String = "file_transfer"
const MSG_FILE_TRANSFER_ACK: String = "file_transfer_ack"
const MSG_FILE_TRANSFER_COMPLETE: String = "file_transfer_complete"
const MSG_IMPORT_COMPLETE: String = "import_complete"

# Transfer Settings
const CHUNK_SIZE: int = 5 * 1024 * 1024  # 5MB
const HEARTBEAT_INTERVAL_MS: int = 1000   # 1 second
const HEARTBEAT_TIMEOUT_MS: int = 30000   # 30 seconds

# Error Codes
const ERROR_INVALID_JSON: int = 1001
const ERROR_PROCESSING: int = 1002

# File Formats
const SUPPORTED_FORMATS: Array[String] = [".fbx", ".obj", ".glb", ".gltf", ".zip"]
