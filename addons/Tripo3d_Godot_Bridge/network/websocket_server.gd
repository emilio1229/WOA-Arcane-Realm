# websocket_server.gd
# WebSocket server using Godot 4 TCPServer + WebSocketPeer
@tool
extends RefCounted

# ————— config —————

signal connection_status_changed(connected: bool)
signal server_start_failed(error_code: int)
signal progress_updated(progress: float)
signal file_transfer_started(file_id: String, file_name: String, chunk_index: int, chunk_total: int)
signal file_transfer_completed(file_id: String, file_name: String, file_type: String)
signal import_result_ready(file_id: String, success: bool, message: String)

var _tcp_server: TCPServer = null
# Each entry: { ws: WebSocketPeer, id: String, ready: bool }
# ready=false means ws.accept_stream() was called but STATE_OPEN not yet reached;
# we send handshake_ack on the first frame it becomes OPEN.
var _clients: Array = []
var _transfer_manager = FileTransferManager.new()
var _completed_transfers: Dictionary = {}
var _is_running: bool = false

var is_running: bool:
	get: return _is_running

# ————— pub api —————

func start() -> void:
	if _is_running:
		LogHelper.log("Server already running")
		return
	_tcp_server = TCPServer.new()
	var err: int = _tcp_server.listen(TripoBridgeProtocolConstants.SERVER_PORT, TripoBridgeProtocolConstants.SERVER_HOST)
	if err != OK:
		LogHelper.error("Failed to start server on port %d: %s" % [TripoBridgeProtocolConstants.SERVER_PORT, str(err)])
		_tcp_server = null
		server_start_failed.emit(err)
		return
	_is_running = true
	LogHelper.log("WebSocket server started on ws://%s:%d" % [
		TripoBridgeProtocolConstants.SERVER_HOST, TripoBridgeProtocolConstants.SERVER_PORT])
	LogHelper.log("Waiting for client connections...")

func stop() -> void:
	if not _is_running:
		return
	for client in _clients:
		(client["ws"] as WebSocketPeer).close()
	_clients.clear()
	_tcp_server.stop()
	_tcp_server = null
	_transfer_manager.clear()
	_completed_transfers.clear()
	_is_running = false
	connection_status_changed.emit(false)
	LogHelper.log("WebSocket server stopped")

# Called every frame by the plugin _process()
func poll() -> void:
	if not _is_running:
		return

	# Accept new connections
	while _tcp_server.is_connection_available():
		var stream := _tcp_server.take_connection()
		var ws := WebSocketPeer.new()
		# Must be set BEFORE accept_stream; default is 65536 (64KB) which is
		# far too small for 5MB file chunks — 1009 "Message Too Big" otherwise.
		ws.inbound_buffer_size = 8 * 1024 * 1024   # 8 MB
		ws.outbound_buffer_size = 1 * 1024 * 1024  # 1 MB
		var err := ws.accept_stream(stream)
		if err == OK:
			var client_id := str(stream.get_connected_host()) + ":" + str(stream.get_connected_port())
			# ready=false: WebSocket HTTP upgrade not yet complete; do NOT send yet
			_clients.append({"ws": ws, "id": client_id, "ready": false})
		else:
			LogHelper.error("Failed to accept WebSocket stream: " + str(err))

	# Poll all connected clients
	var to_remove: Array = []
	for i in range(_clients.size()):
		var client: Dictionary = _clients[i]
		var ws: WebSocketPeer = client["ws"]
		ws.poll()
		var state := ws.get_ready_state()
		if state == WebSocketPeer.STATE_OPEN:
			# First time we see OPEN: send handshake ack and announce connection
			if not client.get("ready", false):
				_clients[i]["ready"] = true
				LogHelper.log("Client connected: " + client["id"])
				connection_status_changed.emit(true)
				_send_json(ws, MessageTypes.handshake_ack(
					Engine.get_version_info().get("string", "4.x")))
			while ws.get_available_packet_count() > 0:
				var packet := ws.get_packet()
				var is_binary := ws.was_string_packet() == false
				_handle_packet(ws, client["id"], packet, is_binary)
		elif state == WebSocketPeer.STATE_CLOSED:
			if client.get("ready", false):
				LogHelper.log("Client disconnected: " + client["id"] +
					" (code: %d)" % ws.get_close_code())
				connection_status_changed.emit(false)
			to_remove.append(client)
	for c in to_remove:
		_clients.erase(c)

func send_import_result(file_id: String, success: bool, message: String) -> void:
	var msg: Dictionary = MessageTypes.import_complete(file_id, success, message)
	for client in _clients:
		_send_json(client["ws"], msg)

func take_completed_transfer(file_id: String) -> Dictionary:
	if not _completed_transfers.has(file_id):
		return {}
	_completed_transfers.erase(file_id)
	return _transfer_manager.take_session(file_id)

# ————— impl —————

func _handle_packet(ws: WebSocketPeer, client_id: String, packet: PackedByteArray, is_binary: bool) -> void:
	if not is_binary:
		_process_text_message(ws, packet.get_string_from_utf8())
	else:
		_process_binary_message(ws, packet)

func _process_text_message(ws: WebSocketPeer, text: String) -> void:
	var json := JSON.new()
	if json.parse(text) != OK:
		LogHelper.error("Text message JSON parse error")
		return
	var obj: Dictionary = json.get_data()
	var msg_type: String = MessageTypes.get_type(obj)
	match msg_type:
		TripoBridgeProtocolConstants.MSG_HANDSHAKE:
			var payload: Dictionary = MessageTypes.get_payload(obj)
			LogHelper.log("Handshake from " + str(payload.get("clientName", "unknown")))
		TripoBridgeProtocolConstants.MSG_PING:
			_send_json(ws, MessageTypes.pong())

func _process_binary_message(ws: WebSocketPeer, data: PackedByteArray) -> void:
	var json_end := _find_json_end(data)
	if json_end <= 0:
		LogHelper.log("Invalid binary message format")
		_send_json(ws, MessageTypes.file_transfer_ack("", 0, false, TripoBridgeProtocolConstants.ERROR_INVALID_JSON))
		return

	var json_bytes := data.slice(0, json_end)
	var json_string := json_bytes.get_string_from_utf8()

	var json := JSON.new()
	if json.parse(json_string) != OK:
		LogHelper.error("Binary JSON parse error")
		_send_json(ws, MessageTypes.file_transfer_ack("", 0, false, TripoBridgeProtocolConstants.ERROR_INVALID_JSON))
		return
	var obj: Dictionary = json.get_data()
	var msg_type: String = MessageTypes.get_type(obj)

	# Handle ping/handshake in binary format
	if msg_type == TripoBridgeProtocolConstants.MSG_PING:
		_send_json(ws, MessageTypes.pong())
		return
	if msg_type == TripoBridgeProtocolConstants.MSG_HANDSHAKE:
		return
	if msg_type != TripoBridgeProtocolConstants.MSG_FILE_TRANSFER:
		LogHelper.log("Ignoring unknown binary message type: " + msg_type)
		return

	# Extract file_transfer payload
	var payload: Dictionary = MessageTypes.get_payload(obj)
	if payload.is_empty():
		LogHelper.error("Binary message error: payload is null")
		_send_json(ws, MessageTypes.file_transfer_ack("", 0, false, TripoBridgeProtocolConstants.ERROR_INVALID_JSON))
		return

	var file_id: String = payload.get("fileId", "")
	var file_name: String = payload.get("fileName", "")
	var file_type: String = payload.get("fileType", "")
	var chunk_index: int = payload.get("chunkIndex", 0)
	var chunk_total: int = payload.get("chunkTotal", 1)

	if file_id.is_empty():
		LogHelper.error("Binary message error: fileId is empty")
		_send_json(ws, MessageTypes.file_transfer_ack("", 0, false, TripoBridgeProtocolConstants.ERROR_INVALID_JSON))
		return

	# Extract binary chunk (everything after the JSON)
	var chunk_data := data.slice(json_end)

	# Notify start on first chunk
	if chunk_index == 0:
		file_transfer_started.emit(file_id, file_name, chunk_index, chunk_total)

	# Progress
	var prog := float(chunk_index + 1) / float(chunk_total)
	progress_updated.emit(prog)

	# Store chunk
	_transfer_manager.add_chunk(file_id, file_name, file_type, chunk_index, chunk_total, chunk_data)

	# ACK
	_send_json(ws, MessageTypes.file_transfer_ack(file_id, chunk_index, true))

	# Check completion
	if _transfer_manager.is_complete(file_id):
		if _completed_transfers.has(file_id):
			return

		LogHelper.log("File transfer complete: " + file_name)
		_send_json(ws, MessageTypes.file_transfer_complete(file_id, "importing",
			"File transfer complete, importing model..."))
		_completed_transfers[file_id] = true

		# Emit completion so the plugin can consume and prepare the transfer off-thread.
		file_transfer_completed.emit(file_id, file_name, file_type)

# ————— internal —————

func _send_json(ws: WebSocketPeer, data: Dictionary) -> void:
	if ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send_text(JSON.stringify(data))

# Brace-counting algorithm to find end of embedded JSON in binary frame
func _find_json_end(data: PackedByteArray) -> int:
	var brace_count := 0
	var in_string := false
	var escape := false
	for i in range(data.size()):
		var b := data[i]
		# Skip non-ASCII bytes (part of UTF-8 multibyte sequences)
		if b >= 128:
			continue
		var c := char(b)
		if escape:
			escape = false
			continue
		if in_string and c == "\\":
			escape = true
			continue
		if c == "\"":
			in_string = not in_string
			continue
		if not in_string:
			if c == "{":
				brace_count += 1
			elif c == "}":
				brace_count -= 1
				if brace_count == 0:
					return i + 1
	return -1
