@tool
class_name ElevenLabs
extends Node


signal generated


const HASH_LENGTH_IN_FILE_NAME: int = 12
const TEXT_LENGTH_IN_FILE_NAME: int = 20

const API_KEY_SETTING_PATH: String = "eleven_labs/api_key"
const OUTPUT_FORMATS: Array[String] = [
	"mp3_22050_32",
	"mp3_24000_48",
	"mp3_44100_32",
	"mp3_44100_64",
	"mp3_44100_96",
	"mp3_44100_128",
	"mp3_44100_192",
	"wav_8000",
	"wav_16000",
	"wav_22050",
	"wav_24000",
	"wav_32000",
	"wav_44100",
	"wav_48000",
]

const COLOR_IN_PROGRESS: = Color(0.5294118, 0.80784315, 0.92156863, 1)
const COLOR_SUCCESS: = Color(0.5647059, 0.93333334, 0.5647059, 1)
const COLOR_ERROR: = Color(0.8039216, 0.36078432, 0.36078432, 1)

enum Status {
	READY,
	IN_PROGRESS,
	SUCCESS,
	ERROR,
}

@onready var status_to_color_map: Dictionary [Status, Color] = {
	Status.READY: COLOR_SUCCESS,
	Status.IN_PROGRESS: COLOR_IN_PROGRESS,
	Status.SUCCESS: COLOR_SUCCESS,
	Status.ERROR: COLOR_ERROR,
}

@onready var control_to_error_text_map: Dictionary [Control, String] = {
	api_key: "No API Key entered.",
	voices: "No Voice selected.",
	text: "No Text entered.",
	multi_text_file_path: "No Multi text path entered.",
	output_path: "No Output path entered.",
}

@export var http: HTTPRequest
@export var player: AudioStreamPlayer
@export var show_api_key: Button
@export var api_key: LineEdit
@export var voices: OptionButton
@export var load_voices: Button
@export var status: RichTextLabel
@export var text_label: Label
@export var text: TextEdit
@export var language_label: Label
@export var language: LineEdit
@export var output_path: LineEdit
@export var generate: Button
@export var stop: Button

@export var play: CheckBox
@export var output_format: OptionButton

@export var usage: Label
@export var refresh: Button

@export var load_file: Button
@export var file_dialog: FileDialog
@export var multi_label: Label
@export var multi_text_file_path: LineEdit
@export var multi_container: HBoxContainer

@export var request_type: CheckButton
@export var request_type_label: Label

@export var hide_icon: CompressedTexture2D
@export var show_icon: CompressedTexture2D

var _voice_ids: Array[String]
var _last_request_ms: int

var _should_stop: bool = false


func _ready():
	api_key.text = _get_api_key()
	api_key.text_changed.connect(_save_api_key)
	show_api_key.pressed.connect(_on_show_api_key_pressed)
	refresh.pressed.connect(_on_refresh_pressed)
	load_voices.pressed.connect(_on_load_voices_pressed)
	generate.pressed.connect(_on_generate_pressed)
	status.meta_clicked.connect(_on_meta_clicked)
	
	request_type.pressed.connect(_on_request_type_pressed)
	_on_request_type_pressed()
	
	load_file.pressed.connect(file_dialog.popup)
	file_dialog.file_selected.connect(func(path): multi_text_file_path.text = path)
	
	stop.pressed.connect(func(): _should_stop = true)
	
	_fill_in_formats()
	_switch_buttons(true)
	_set_status(Status.READY)


func _on_request_type_pressed() -> void:
	request_type_label.text = "Multi" if request_type.button_pressed else "Single"
	
	language_label.visible = not request_type.button_pressed
	language.visible = not request_type.button_pressed
	text_label.visible = not request_type.button_pressed
	text.visible = not request_type.button_pressed
	
	multi_label.visible = request_type.button_pressed
	multi_container.visible = request_type.button_pressed


func _fill_in_formats() -> void:
	output_format.clear()
	for format in OUTPUT_FORMATS:
		output_format.add_item(format)
	output_format.select(OUTPUT_FORMATS.find("mp3_44100_32"))


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
	http.request_completed.connect(callback.bind(button), CONNECT_ONE_SHOT)
	var error = http.request(url + _get_params_string(params), _get_headers_array(headers), method, JSON.stringify(payload) if payload else "")
	if error != OK:
		_set_status(Status.ERROR, "An error occurred in the HTTP request.")
		_switch_buttons(true)


func _on_generate_pressed() -> void:
	if not _check_if_entered(api_key):
		return
	
	if not _check_if_entered(voices):
		return
	
	if request_type.button_pressed:
		if not _check_if_entered(multi_text_file_path):
			return
		
		var file: = FileAccess.open(multi_text_file_path.text, FileAccess.READ)
		file.get_as_text()
		
		var json: = JSON.new()
		var parse_result := json.parse(file.get_as_text())
		var body_array: Array = []
		if parse_result == OK:
			body_array = json.get_data()
		else:
			_set_status(Status.ERROR, "Incorrect file format.", true)
			return
		
		if body_array.is_empty():
			_set_status(Status.ERROR, "Incorrect file format.", true)
			return
		
		if not body_array[0].has("language") or not body_array[0].has("text"):
			_set_status(Status.ERROR, "Incorrect file format.", true)
			return
		
		for phrase in body_array:
			_generate(phrase.language, phrase.text)
			await generated
			if _should_stop:
				_should_stop = false
				return
	else:
		_generate(language.text, text.text)
		await generated


func _generate(language_: String, text_: String) -> void:
	if text_ == "":
		_set_status(Status.ERROR, "No text entered.")
		return
	
	_set_status(Status.IN_PROGRESS, "awaiting response.")
	_switch_buttons(false)
	
	var url = "https://api.elevenlabs.io/v1/text-to-speech/%s" % _voice_ids[voices.selected]
	var method = HTTPClient.METHOD_POST
	
	var headers = {}
	headers["xi-api-key"] = api_key.text
	
	var params = {}
	params.output_format = OUTPUT_FORMATS[output_format.selected]
	
	var payload = {}
	payload.text = text_
	if language_:
		payload.language_code = language_
		payload.apply_text_normalization = "on"
	
	_send_request(
		url,
		params,
		headers,
		method,
		payload,
		_on_text_to_speech_request_completed.bind(language_, text_),
		generate,
	)


func _on_text_to_speech_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, button: Button, language_: String, text_: String):
	#http.request_completed.disconnect(_on_text_to_speech_request_completed)
	_switch_buttons(true)
	generated.emit()
	
	if not _check_response_code(response_code):
		return
	
	if body.size() == 0:
		_set_status(Status.ERROR, "code: %s. Empty response." % response_code, true)
		return
	
	var file_folder = output_path.text
	var file_name = _get_file_name(language_, text_)
	var file_extension = OUTPUT_FORMATS[output_format.selected].left(3)
	var file_full_path = "%s%s.%s" % [file_folder, file_name, file_extension]
	
	if not DirAccess.dir_exists_absolute(file_folder):
		DirAccess.make_dir_absolute(file_folder)
	var file = FileAccess.open(file_full_path, FileAccess.WRITE)
	file.store_buffer(body)
	file.close()
	EditorInterface.get_resource_filesystem().scan_sources()
	
	_set_status(Status.SUCCESS, "File saved at [url]%s[/url]." % file_full_path, true)
	
	if play.button_pressed:
		var stream: AudioStream
		match file_extension:
			"mp3":
				stream = AudioStreamMP3.load_from_file(file_full_path)
			"wav":
				stream = AudioStreamWAV.load_from_file(file_full_path)
		
		if stream:
			player.stream = stream
			player.play()


func _on_load_voices_pressed() -> void:
	if not _check_if_entered(api_key):
		return
	
	_set_status(Status.IN_PROGRESS, "awaiting response.")
	_switch_buttons(false)
	
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
	#http.request_completed.disconnect(_on_get_voices_request_completed)
	_switch_buttons(true)
	
	if not _check_response_code(response_code):
		return
	
	var body_string: = body.get_string_from_utf8()
	
	var json := JSON.new()
	var parse_result := json.parse(body_string)
	
	var body_dict: Dictionary = {}
	if parse_result == OK:
		body_dict = json.get_data()
	else:
		_set_status(Status.ERROR, "Incorrect response format.", true)
		return
	
	if not body_dict.has("voices"):
		_set_status(Status.ERROR, "Incorrect response format.", true)
		return
	
	voices.clear()
	_voice_ids.clear()
	for voice in body_dict.voices:
		_voice_ids.append(voice.voice_id)
		voices.add_item(voice.name)
	voices.select(0)
	
	status.text = "[color=%s]Success (%dms):[/color] Loaded %s voices." % [COLOR_SUCCESS.to_html(), Time.get_ticks_msec() - _last_request_ms, _voice_ids.size()]


func _on_refresh_pressed() -> void:
	if not _check_if_entered(api_key):
		return
	
	_set_status(Status.IN_PROGRESS, "awaiting response.")
	_switch_buttons(false)
	
	var url = "https://api.elevenlabs.io/v1/user"
	var method = HTTPClient.METHOD_GET
	
	var headers = {}
	headers["xi-api-key"] = api_key.text
	
	_send_request(
		url,
		{},
		headers,
		method,
		{},
		_on_refresh_request_completed,
		refresh,
	)


func _on_refresh_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray, button: Button) -> void:
	#http.request_completed.disconnect(_on_refresh_request_completed)
	_switch_buttons(true)
	
	if not _check_response_code(response_code):
		return
	
	var body_string: = body.get_string_from_utf8()
	
	var json := JSON.new()
	var parse_result := json.parse(body_string)
	
	var body_dict: Dictionary = {}
	if parse_result == OK:
		body_dict = json.get_data()
	else:
		_set_status(Status.ERROR, "Incorrect response format.", true)
		return
	
	if not body_dict.has("subscription"):
		_set_status(Status.ERROR, "Incorrect response format.", true)
		return
	
	var percent: float = round(body_dict.subscription.character_count / body_dict.subscription.character_limit * 100)
	usage.text = "%d / %d (%d%%)" % [body_dict.subscription.character_count, body_dict.subscription.character_limit, percent]
	
	_set_status(Status.SUCCESS, "Current usage: %s." % usage.text, true)


func _get_file_name(language_: String, text_: String) -> String:
	var clean_text = text_.to_lower()
	clean_text = clean_text.left(TEXT_LENGTH_IN_FILE_NAME)
	clean_text = clean_text.strip_edges()
	
	var regex = RegEx.new()
	regex.compile("[^\\p{L}\\p{N}_]")
	clean_text = regex.sub(clean_text, "_", true)
	
	regex.compile("_+")
	clean_text = regex.sub(clean_text, "_", true)
	
	var hash: String = get_hash(text_)
	
	var file_name: String = ""
	if language_:
		file_name += language_ + "_"
	if clean_text:
		file_name += clean_text + "_"
	if hash:
		file_name += hash
	
	return file_name


static func get_hash(text_to_hash: String) -> String:
	var ctx: = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text_to_hash.to_utf8_buffer())
	return ctx.finish().hex_encode().left(HASH_LENGTH_IN_FILE_NAME)


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


func _switch_buttons(on: bool) -> void:
	refresh.disabled = not on
	load_voices.disabled = not on
	#generate.disabled = not on
	
	generate.visible = on
	stop.visible = not on
	print(on)

func _check_if_entered(control: Control) -> bool:
	if control is LineEdit:
		if control.text.is_empty():
			_set_status(Status.ERROR, control_to_error_text_map[control])
			return false
	elif control is OptionButton:
		if control.selected == -1:
			_set_status(Status.ERROR, control_to_error_text_map[control])
			return false
	return true


func _check_response_code(response_code: HTTPClient.ResponseCode) -> bool:
	if response_code == HTTPClient.RESPONSE_UNAUTHORIZED:
		_set_status(Status.ERROR, "code: %s. Unauthorized - check API key." % response_code, true)
		return false
	elif response_code != HTTPClient.RESPONSE_OK:
		_set_status(Status.ERROR, "code: %s." % response_code, true)
		return false
	return true


func _set_status(status_: Status, status_text: String = "", include_time: bool = false) -> void:
	var status_color: String = status_to_color_map[status_].to_html()
	var status_name: String = Status.keys()[status_].capitalize()
	if include_time:
		status_name += " (%sms)" % (Time.get_ticks_msec() - _last_request_ms)
	if status_text:
		status_text = status_text.insert(0, ": ")
	status.text = "[color=%s]%s[/color]%s" % [status_color, status_name, status_text]
