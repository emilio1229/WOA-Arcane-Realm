# file_transfer_manager.gd
# Manages chunked file transfer sessions
@tool
class_name FileTransferManager

# Session structure:
# { file_id: { file_name, file_type, total_chunks, chunks: { index: PackedByteArray } } }
var _sessions: Dictionary = {}

func add_chunk(file_id: String, file_name: String, file_type: String,
		chunk_index: int, chunk_total: int, chunk_data: PackedByteArray) -> void:
	if not _sessions.has(file_id):
		_sessions[file_id] = {
			"file_name": file_name,
			"file_type": file_type,
			"total_chunks": chunk_total,
			"chunks": {}
		}
	_sessions[file_id]["chunks"][chunk_index] = chunk_data

func is_complete(file_id: String) -> bool:
	if not _sessions.has(file_id):
		return false
	var session: Dictionary = _sessions[file_id]
	return session["chunks"].size() == session["total_chunks"]

func assemble_file(file_id: String) -> PackedByteArray:
	if not _sessions.has(file_id):
		LogHelper.error("FileTransferManager: session not found: " + file_id)
		return PackedByteArray()
	return assemble_session_data(_sessions[file_id], file_id)

func take_session(file_id: String) -> Dictionary:
	if not _sessions.has(file_id):
		return {}
	var session: Dictionary = _sessions[file_id].duplicate(true)
	session["file_id"] = file_id
	_sessions.erase(file_id)
	return session

func remove_session(file_id: String) -> void:
	_sessions.erase(file_id)

func clear() -> void:
	_sessions.clear()

static func assemble_session_data(session: Dictionary, file_id: String) -> PackedByteArray:
	var chunks: Dictionary = session["chunks"]
	var total: int = session["total_chunks"]
	var result := PackedByteArray()
	for i in range(total):
		if not chunks.has(i):
			LogHelper.error("FileTransferManager: missing chunk %d for %s" % [i, file_id])
			return PackedByteArray()
		result.append_array(chunks[i])
	return result
