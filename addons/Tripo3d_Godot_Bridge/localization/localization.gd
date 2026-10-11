# localization.gd
# Localization manager for 9 languages
@tool
class_name TripoBridgeLocalization

enum Key {
	WINDOW_TITLE,
	START_SERVER,
	STOP_SERVER,
	STATUS,
	PORT,
	CONNECTION,
	LISTENING,
	CONNECTED,
	DISCONNECTED,
	PORT_IN_USE,
	START_FAILED,
	FILE,
	PROGRESS,
	MESSAGE_LOG,
	CLEAR,
	ASSET_CONVERTER,
	REFRESH,
	CONVERT,
	CONVERT_ALL,
	CATEGORY,
	FRIENDLY_NAME,
	CONVERT_SUCCESS,
	CONVERT_FAILED,
	NO_MODELS_FOUND,
	SOURCE,
}

static var _texts: Dictionary = {}
static var _loaded: bool = false

static func get_text(key: int) -> String:
	if not _loaded:
		_load_language()
	return _texts.get(key, Key.keys()[key])

static func _load_language() -> void:
	_loaded = true
	var locale := OS.get_locale().to_lower()
	if locale.begins_with("zh"):
		_texts = _chinese()
	elif locale.begins_with("ja"):
		_texts = _japanese()
	elif locale.begins_with("ko"):
		_texts = _korean()
	elif locale.begins_with("ru"):
		_texts = _russian()
	elif locale.begins_with("fr"):
		_texts = _french()
	elif locale.begins_with("de"):
		_texts = _german()
	elif locale.begins_with("es"):
		_texts = _spanish()
	elif locale.begins_with("pt"):
		_texts = _portuguese()
	else:
		_texts = _english()

static func _english() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "Start Server",
		Key.STOP_SERVER:    "Stop Server",
		Key.STATUS:         "Status",
		Key.PORT:           "Port:",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "Listening",
		Key.CONNECTED:      "Connected",
		Key.DISCONNECTED:   "Disconnected",
		Key.PORT_IN_USE:    "Port In Use",
		Key.START_FAILED:   "Start Failed",
		Key.FILE:           "Receiving File:",
		Key.PROGRESS:       "Progress",
		Key.MESSAGE_LOG:    "Message Log",
		Key.CLEAR:          "Clear",
		Key.ASSET_CONVERTER: "Asset Converter",
		Key.REFRESH:        "Refresh",
		Key.CONVERT:        "Convert",
		Key.CONVERT_ALL:    "Convert All",
		Key.CATEGORY:       "Category:",
		Key.FRIENDLY_NAME:  "Name:",
		Key.CONVERT_SUCCESS: "Conversion successful",
		Key.CONVERT_FAILED: "Conversion failed",
		Key.NO_MODELS_FOUND: "No models found in TripoModels/",
		Key.SOURCE:         "Source:",
	}

static func _chinese() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "启动服务器",
		Key.STOP_SERVER:    "停止服务器",
		Key.STATUS:         "状态",
		Key.PORT:           "端口：",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "监听中",
		Key.CONNECTED:      "已连接",
		Key.DISCONNECTED:   "未连接",
		Key.PORT_IN_USE:    "端口被占用",
		Key.START_FAILED:   "启动失败",
		Key.FILE:           "接收文件：",
		Key.PROGRESS:       "进度",
		Key.MESSAGE_LOG:    "消息日志",
		Key.CLEAR:          "清空",
		Key.ASSET_CONVERTER: "资源转换",
		Key.REFRESH:        "刷新",
		Key.CONVERT:        "转换",
		Key.CONVERT_ALL:    "全部转换",
		Key.CATEGORY:       "分类：",
		Key.FRIENDLY_NAME:  "名称：",
		Key.CONVERT_SUCCESS: "转换成功",
		Key.CONVERT_FAILED: "转换失败",
		Key.NO_MODELS_FOUND: "TripoModels/ 中未找到模型",
		Key.SOURCE:         "来源：",
	}

static func _japanese() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "サーバーを起動",
		Key.STOP_SERVER:    "サーバーを停止",
		Key.STATUS:         "ステータス",
		Key.PORT:           "ポート：",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "待機中",
		Key.CONNECTED:      "接続済み",
		Key.DISCONNECTED:   "未接続",
		Key.PORT_IN_USE:    "ポート使用中",
		Key.START_FAILED:   "起動失敗",
		Key.FILE:           "ファイルを受信中：",
		Key.PROGRESS:       "進行状況",
		Key.MESSAGE_LOG:    "メッセージログ",
		Key.CLEAR:          "クリア",
		Key.ASSET_CONVERTER: "アセット変換",
		Key.REFRESH:        "更新",
		Key.CONVERT:        "変換",
		Key.CONVERT_ALL:    "すべて変換",
		Key.CATEGORY:       "カテゴリ：",
		Key.FRIENDLY_NAME:  "名前：",
		Key.CONVERT_SUCCESS: "変換に成功しました",
		Key.CONVERT_FAILED: "変換に失敗しました",
		Key.NO_MODELS_FOUND: "TripoModels/ にモデルが見つかりません",
		Key.SOURCE:         "ソース：",
	}

static func _korean() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "서버 시작",
		Key.STOP_SERVER:    "서버 중지",
		Key.STATUS:         "상태",
		Key.PORT:           "포트：",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "대기 중",
		Key.CONNECTED:      "연결됨",
		Key.DISCONNECTED:   "연결 안 됨",
		Key.PORT_IN_USE:    "포트 사용 중",
		Key.START_FAILED:   "시작 실패",
		Key.FILE:           "파일 수신 중：",
		Key.PROGRESS:       "진행률",
		Key.MESSAGE_LOG:    "메시지 로그",
		Key.CLEAR:          "지우기",
		Key.ASSET_CONVERTER: "에셋 변환",
		Key.REFRESH:        "새로고침",
		Key.CONVERT:        "변환",
		Key.CONVERT_ALL:    "모두 변환",
		Key.CATEGORY:       "카테고리:",
		Key.FRIENDLY_NAME:  "이름:",
		Key.CONVERT_SUCCESS: "변환 성공",
		Key.CONVERT_FAILED: "변환 실패",
		Key.NO_MODELS_FOUND: "TripoModels/에 모델이 없습니다",
		Key.SOURCE:         "소스:",
	}

static func _russian() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "Запустить сервер",
		Key.STOP_SERVER:    "Остановить сервер",
		Key.STATUS:         "Статус",
		Key.PORT:           "Порт：",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "Ожидание подключения",
		Key.CONNECTED:      "Подключено",
		Key.DISCONNECTED:   "Отключено",
		Key.PORT_IN_USE:    "Порт занят",
		Key.START_FAILED:   "Ошибка запуска",
		Key.FILE:           "Получение файла：",
		Key.PROGRESS:       "Прогресс",
		Key.MESSAGE_LOG:    "Журнал сообщений",
		Key.CLEAR:          "Очистить",
		Key.ASSET_CONVERTER: "Конвертер ресурсов",
		Key.REFRESH:        "Обновить",
		Key.CONVERT:        "Конвертировать",
		Key.CONVERT_ALL:    "Конвертировать все",
		Key.CATEGORY:       "Категория:",
		Key.FRIENDLY_NAME:  "Имя:",
		Key.CONVERT_SUCCESS: "Конвертация выполнена",
		Key.CONVERT_FAILED: "Ошибка конвертации",
		Key.NO_MODELS_FOUND: "Модели в TripoModels/ не найдены",
		Key.SOURCE:         "Источник:",
	}

static func _french() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "Démarrer le serveur",
		Key.STOP_SERVER:    "Arrêter le serveur",
		Key.STATUS:         "Statut",
		Key.PORT:           "Port :",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "En attente",
		Key.CONNECTED:      "Connecté",
		Key.DISCONNECTED:   "Déconnecté",
		Key.PORT_IN_USE:    "Port occupé",
		Key.START_FAILED:   "Échec du démarrage",
		Key.FILE:           "Réception du fichier :",
		Key.PROGRESS:       "Progression",
		Key.MESSAGE_LOG:    "Journal des messages",
		Key.CLEAR:          "Effacer",
		Key.ASSET_CONVERTER: "Convertisseur d'assets",
		Key.REFRESH:        "Actualiser",
		Key.CONVERT:        "Convertir",
		Key.CONVERT_ALL:    "Tout convertir",
		Key.CATEGORY:       "Catégorie :",
		Key.FRIENDLY_NAME:  "Nom :",
		Key.CONVERT_SUCCESS: "Conversion réussie",
		Key.CONVERT_FAILED: "Échec de la conversion",
		Key.NO_MODELS_FOUND: "Aucun modèle trouvé dans TripoModels/",
		Key.SOURCE:         "Source :",
	}

static func _german() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "Server starten",
		Key.STOP_SERVER:    "Server stoppen",
		Key.STATUS:         "Status",
		Key.PORT:           "Port:",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "Lauscht",
		Key.CONNECTED:      "Verbunden",
		Key.DISCONNECTED:   "Getrennt",
		Key.PORT_IN_USE:    "Port belegt",
		Key.START_FAILED:   "Start fehlgeschlagen",
		Key.FILE:           "Datei empfangen:",
		Key.PROGRESS:       "Fortschritt",
		Key.MESSAGE_LOG:    "Nachrichtenprotokoll",
		Key.CLEAR:          "Löschen",
		Key.ASSET_CONVERTER: "Asset-Konverter",
		Key.REFRESH:        "Aktualisieren",
		Key.CONVERT:        "Konvertieren",
		Key.CONVERT_ALL:    "Alle konvertieren",
		Key.CATEGORY:       "Kategorie:",
		Key.FRIENDLY_NAME:  "Name:",
		Key.CONVERT_SUCCESS: "Konvertierung erfolgreich",
		Key.CONVERT_FAILED: "Konvertierung fehlgeschlagen",
		Key.NO_MODELS_FOUND: "Keine Modelle in TripoModels/ gefunden",
		Key.SOURCE:         "Quelle:",
	}

static func _spanish() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "Iniciar servidor",
		Key.STOP_SERVER:    "Detener servidor",
		Key.STATUS:         "Estado",
		Key.PORT:           "Puerto:",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "Escuchando",
		Key.CONNECTED:      "Conectado",
		Key.DISCONNECTED:   "Desconectado",
		Key.PORT_IN_USE:    "Puerto en uso",
		Key.START_FAILED:   "Error al iniciar",
		Key.FILE:           "Recibiendo archivo:",
		Key.PROGRESS:       "Progreso",
		Key.MESSAGE_LOG:    "Registro de mensajes",
		Key.CLEAR:          "Limpiar",
		Key.ASSET_CONVERTER: "Convertidor de assets",
		Key.REFRESH:        "Actualizar",
		Key.CONVERT:        "Convertir",
		Key.CONVERT_ALL:    "Convertir todo",
		Key.CATEGORY:       "Categoría:",
		Key.FRIENDLY_NAME:  "Nombre:",
		Key.CONVERT_SUCCESS: "Conversión exitosa",
		Key.CONVERT_FAILED: "Error en la conversión",
		Key.NO_MODELS_FOUND: "No se encontraron modelos en TripoModels/",
		Key.SOURCE:         "Fuente:",
	}

static func _portuguese() -> Dictionary:
	return {
		Key.WINDOW_TITLE:   "Tripo Bridge",
		Key.START_SERVER:   "Iniciar servidor",
		Key.STOP_SERVER:    "Parar servidor",
		Key.STATUS:         "Status",
		Key.PORT:           "Porta:",
		Key.CONNECTION:     "Tripo Studio:",
		Key.LISTENING:      "Aguardando conexão",
		Key.CONNECTED:      "Conectado",
		Key.DISCONNECTED:   "Desconectado",
		Key.PORT_IN_USE:    "Porta em uso",
		Key.START_FAILED:   "Falha ao iniciar",
		Key.FILE:           "Recebendo arquivo:",
		Key.PROGRESS:       "Progresso",
		Key.MESSAGE_LOG:    "Registro de mensagens",
		Key.CLEAR:          "Limpar",
		Key.ASSET_CONVERTER: "Conversor de assets",
		Key.REFRESH:        "Atualizar",
		Key.CONVERT:        "Converter",
		Key.CONVERT_ALL:    "Converter tudo",
		Key.CATEGORY:       "Categoria:",
		Key.FRIENDLY_NAME:  "Nome:",
		Key.CONVERT_SUCCESS: "Conversão realizada",
		Key.CONVERT_FAILED: "Falha na conversão",
		Key.NO_MODELS_FOUND: "Nenhum modelo encontrado em TripoModels/",
		Key.SOURCE:         "Fonte:",
	}
