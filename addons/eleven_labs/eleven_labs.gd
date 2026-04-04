@tool
extends Node


const API_KEY_SETTING_PATH: String = "eleven_labs/api_key"


@onready var COLOR_ERROR: String = Color.INDIAN_RED.to_html()
@onready var COLOR_IN_PROGRESS: String = Color.SKY_BLUE.to_html()
@onready var COLOR_SUCCESS: String = Color.LIGHT_GREEN.to_html()


@export var http: HTTPRequest
@export var player: AudioStreamPlayer
@export var show_api_key: Button
@export var api_key: LineEdit
@export var voices: OptionButton
@export var load_voices: Button
@export var status: RichTextLabel
@export var text: TextEdit
@export var language: LineEdit
@export var path: LineEdit
@export var generate: Button
@export var play: CheckBox

@export var hide_icon: CompressedTexture2D
@export var show_icon: CompressedTexture2D


var _voice_ids: Array[String]
var _last_request_ms: int


func _ready():
	api_key.text = _get_api_key()
	api_key.text_changed.connect(_save_api_key)
	show_api_key.pressed.connect(_on_show_api_key_pressed)
	load_voices.pressed.connect(get_voices)
	generate.pressed.connect(generate_text_to_speech)
	status.meta_clicked.connect(_on_meta_clicked)


func _save_api_key(key: String) -> void:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	editor_settings.set_setting(API_KEY_SETTING_PATH, key)


func _get_api_key() -> String:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if editor_settings.has_setting(API_KEY_SETTING_PATH):
		return editor_settings.get_setting(API_KEY_SETTING_PATH)
	return ""


func _send_request(url: String, params: Dictionary, headers: Dictionary, method: HTTPClient.Method, payload: Dictionary, callback: Callable, button: Button) -> void:
	_last_request_ms = Time.get_ticks_msec()
	http.request_completed.connect(callback.bind(button))
	var error = http.request(url + _get_params_string(params), _get_headers_array(headers), method, JSON.stringify(payload) if payload else "")
	if error != OK:
		status.text = "[color=%s]Error:[/color] An error occurred in the HTTP request." % COLOR_ERROR
		button.disabled = false


func generate_text_to_speech() -> void:
	if api_key.text == "":
		status.text = "[color=%s]Error:[/color] No API key entered." % COLOR_ERROR
		return
	
	if voices.selected == -1:
		status.text = "[color=%s]Error:[/color] No voice selected." % COLOR_ERROR
		return
	
	if text.text == "":
		status.text = "[color=%s]Error:[/color] No text entered." % COLOR_ERROR
		return
	
	status.text = "[color=%s]In progress:[/color] ... awaiting response ..." % COLOR_IN_PROGRESS
	generate.disabled = true
	
	var url = "https://api.elevenlabs.io/v1/text-to-speech/%s" % _voice_ids[voices.selected]
	var method = HTTPClient.METHOD_POST
	
	var headers = {}
	headers["xi-api-key"] = api_key.text
	
	var params = {}
	params.output_format = "mp3_44100_32"
	
	var payload = {}
	payload.text = text.text
	if language.text:
		payload.language_code = language.text
		payload.apply_text_normalization = "on"
	
	_send_request(
		url,
		params,
		headers,
		method,
		payload,
		_on_text_to_speech_request_completed,
		generate,
	)


func _on_text_to_speech_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, button: Button):
	button.disabled = false
	http.request_completed.disconnect(_on_text_to_speech_request_completed)
	
	if response_code == HTTPClient.RESPONSE_UNAUTHORIZED:
		status.text = "[color=%s]Error (%dms):[/color] code: %s. Unauthorized - check API key." % [COLOR_ERROR, Time.get_ticks_msec() - _last_request_ms, response_code]
		return
	
	if response_code != HTTPClient.RESPONSE_OK:
		status.text = "[color=%s]Error (%dms):[/color] code: %s." % [COLOR_ERROR, Time.get_ticks_msec() - _last_request_ms, response_code]
		return
	
	if body.size() == 0:
		status.text = "[color=%s]Error (%dms):[/color] code: %s. Empty response." % [COLOR_ERROR, Time.get_ticks_msec() - _last_request_ms, response_code]
		return
	
	var file_folder = path.text
	var file_name = _get_file_name(language.text, text.text)
	var file_extension = "mp3"
	var file_full_path = "%s%s.%s" % [file_folder, file_name, file_extension]
	
	if not DirAccess.dir_exists_absolute(file_folder):
		DirAccess.make_dir_absolute(file_folder)
	var file = FileAccess.open(file_full_path, FileAccess.WRITE)
	file.store_buffer(body)
	file.close()
	EditorInterface.get_resource_filesystem().scan_sources()
	
	status.text = "[color=%s]Success (%dms):[/color] File saved at [url]%s[/url]." % [COLOR_SUCCESS, Time.get_ticks_msec() - _last_request_ms, file_full_path]
	
	if play.button_pressed:
		var stream = AudioStreamMP3.load_from_file(file_full_path)
		player.stream = stream
		player.play()


func get_voices() -> void:
	if api_key.text == "":
		status.text = "[color=%s]Error:[/color] No API key entered." % COLOR_ERROR
		return
	
	status.text = "[color=%s]In progress:[/color] ... awaiting response ..." % COLOR_IN_PROGRESS
	load_voices.disabled = true
	
	var url = "https://api.elevenlabs.io/v2/voices"
	var method = HTTPClient.METHOD_GET
	
	var headers = {}
	headers["xi-api-key"] = api_key.text
	
	_send_request(
		url,
		{},
		headers,
		method,
		{},
		_on_get_voices_request_completed,
		load_voices,
	)


func _on_get_voices_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, button: Button) -> void:
	button.disabled = false
	http.request_completed.disconnect(_on_get_voices_request_completed)
	
	if response_code == HTTPClient.RESPONSE_UNAUTHORIZED:
		status.text = "[color=%s]Error (%dms):[/color] code: %s. Unauthorized - check API key." % [COLOR_ERROR, Time.get_ticks_msec() - _last_request_ms, response_code]
		return
	
	if response_code != HTTPClient.RESPONSE_OK:
		status.text = "[color=%s]Error (%dms):[/color] code: %s." % [COLOR_ERROR, Time.get_ticks_msec() - _last_request_ms, response_code]
		return
	
	var body_string: = body.get_string_from_utf8()
	
	var json := JSON.new()
	var parse_result := json.parse(body_string)
	
	var body_dict: Dictionary = {}
	if parse_result == OK:
		body_dict = json.get_data()
	else:
		status.text = "[color=%s]Error (%dms):[/color] Incorrect response format." % [COLOR_ERROR, Time.get_ticks_msec() - _last_request_ms]
		return
	
	if not body_dict.has("voices"):
		status.text = "[color=%s]Error (%dms):[/color] Incorrect response format." % [COLOR_ERROR, Time.get_ticks_msec() - _last_request_ms]
		return
	
	voices.clear()
	_voice_ids.clear()
	for voice in body_dict.voices:
		_voice_ids.append(voice.voice_id)
		voices.add_item(voice.name)
	voices.select(0)
	
	status.text = "[color=%s]Success (%dms):[/color] Loaded %s voices." % [COLOR_SUCCESS, Time.get_ticks_msec() - _last_request_ms, _voice_ids.size()]


func _get_file_name(language_: String, text_: String, text_length: int = 20, hash_length: int = 12) -> String:
	var clean_text = text_.to_lower()
	clean_text = clean_text.left(text_length)
	clean_text = clean_text.strip_edges()
	clean_text = clean_text.remove_chars(r":/\?*\"|%<>!'@#$^&()-=+~`,.")
	clean_text = clean_text.replace(" ", "_")
	
	var hash: String = _get_hash(text_, hash_length)
	
	var file_name: String = ""
	if language_:
		file_name += language_ + "_"
	if clean_text:
		file_name += clean_text + "_"
	if hash:
		file_name += hash
	
	return file_name


func _get_hash(text_to_hash: String, length: int = 12) -> String:
	var ctx: = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text_to_hash.to_utf8_buffer())
	return ctx.finish().hex_encode().left(length)


func _get_headers_array(headers_dict: Dictionary) -> PackedStringArray:
	var headers_array: PackedStringArray = []
	for header in headers_dict.keys():
		headers_array.append("%s: %s" % [header, headers_dict[header]])
	return headers_array


func _get_params_string(params_dict: Dictionary) -> String:
	var params_string: String = ""
	for key in params_dict.keys():
		if params_string != "":
			params_string += "&"
		params_string += key + "=" + params_dict[key].uri_encode()
	if params_string:
		params_string = "?" + params_string
	return params_string


func _on_meta_clicked(meta) -> void:
	EditorInterface.get_file_system_dock().navigate_to_path(str(meta))


func _on_show_api_key_pressed() -> void:
	api_key.secret = not api_key.secret
	show_api_key.icon = show_icon if api_key.secret else hide_icon
