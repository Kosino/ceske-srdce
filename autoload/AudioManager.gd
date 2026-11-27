extends Node
## SFX + Music buses. Fully silent under --headless / --sim (no players, no sim slowdown).

const BUS_MASTER := "Master"
const BUS_MUSIC := "Music"
const BUS_SFX := "SFX"
const MAX_IDENTICAL := 3
const POOL_SIZE := 12

const SFX_PATHS := {
	"select": "res://assets/audio/sfx/select.ogg",
	"command": "res://assets/audio/sfx/command.ogg",
	"wood_chop": "res://assets/audio/sfx/wood_chop.ogg",
	"mining": "res://assets/audio/sfx/mining.ogg",
	"building_complete": "res://assets/audio/sfx/building_complete.ogg",
	"melee_hit": "res://assets/audio/sfx/melee_hit.ogg",
	"bow_shot": "res://assets/audio/sfx/bow_shot.wav",
	"building_destroyed": "res://assets/audio/sfx/building_destroyed.ogg",
	"age_advance": "res://assets/audio/sfx/age_advance.ogg",
	"under_attack": "res://assets/audio/sfx/under_attack.ogg",
	"victory": "res://assets/audio/sfx/victory.ogg",
	"defeat": "res://assets/audio/sfx/defeat.ogg",
}

var enabled: bool = true
var sfx_muted: bool = false
var music_muted: bool = false
var sfx_volume_linear: float = 1.0
var music_volume_linear: float = 1.0

var _streams: Dictionary = {} ## id -> AudioStream
var _playing_counts: Dictionary = {} ## id -> int
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _under_attack_cooldown: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	enabled = not _should_silence()
	_ensure_buses()
	if not enabled:
		print("[AUDIO] silenced (headless/sim)")
		return
	_preload_streams()
	_build_pool()
	_apply_volumes()
	print("[AUDIO] ready sfx=%d" % _streams.size())


func _process(delta: float) -> void:
	if _under_attack_cooldown > 0.0:
		_under_attack_cooldown = maxf(0.0, _under_attack_cooldown - delta)


func _should_silence() -> bool:
	if DisplayServer.get_name() == "headless":
		return true
	if BalanceSim.active:
		return true
	var args := OS.get_cmdline_user_args()
	if args.has("--sim") or args.has("--sim-smoke"):
		return true
	return false


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(BUS_MUSIC) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_MUSIC)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, BUS_MASTER)
	if AudioServer.get_bus_index(BUS_SFX) < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, BUS_SFX)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, BUS_MASTER)


func _preload_streams() -> void:
	_streams.clear()
	for id in SFX_PATHS.keys():
		var path: String = str(SFX_PATHS[id])
		if not ResourceLoader.exists(path):
			push_warning("[AUDIO] missing %s -> %s" % [id, path])
			continue
		var stream := load(path) as AudioStream
		if stream:
			_streams[id] = stream


func _build_pool() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "SfxPlayer%d" % i
		p.bus = BUS_SFX
		p.finished.connect(_on_sfx_finished.bind(p))
		add_child(p)
		_sfx_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.bus = BUS_MUSIC
	add_child(_music_player)


func _apply_volumes() -> void:
	var sfx_i := AudioServer.get_bus_index(BUS_SFX)
	var music_i := AudioServer.get_bus_index(BUS_MUSIC)
	if sfx_i >= 0:
		AudioServer.set_bus_mute(sfx_i, sfx_muted or not enabled)
		AudioServer.set_bus_volume_db(sfx_i, linear_to_db(clampf(sfx_volume_linear, 0.0001, 1.0)))
	if music_i >= 0:
		AudioServer.set_bus_mute(music_i, music_muted or not enabled)
		AudioServer.set_bus_volume_db(music_i, linear_to_db(clampf(music_volume_linear, 0.0001, 1.0)))


func set_sfx_volume(linear: float) -> void:
	sfx_volume_linear = clampf(linear, 0.0, 1.0)
	_apply_volumes()


func set_music_volume(linear: float) -> void:
	music_volume_linear = clampf(linear, 0.0, 1.0)
	_apply_volumes()


func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_apply_volumes()


func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_apply_volumes()


func play_sfx(id: String) -> void:
	if not enabled or sfx_muted:
		return
	if not _streams.has(id):
		return
	var count := int(_playing_counts.get(id, 0))
	if count >= MAX_IDENTICAL:
		return
	var player := _free_sfx_player()
	if player == null:
		return
	player.stream = _streams[id]
	player.set_meta("sfx_id", id)
	_playing_counts[id] = count + 1
	player.play()


func play_under_attack() -> void:
	if not enabled or _under_attack_cooldown > 0.0:
		return
	_under_attack_cooldown = 2.5
	play_sfx("under_attack")


func all_sfx_paths() -> Dictionary:
	return SFX_PATHS.duplicate()


func stream_count() -> int:
	return _streams.size()


func verify_paths() -> Dictionary:
	## Returns {ok: bool, missing: PackedStringArray, loaded: int}
	var missing: PackedStringArray = []
	for id in SFX_PATHS.keys():
		var path: String = str(SFX_PATHS[id])
		if not ResourceLoader.exists(path) and not FileAccess.file_exists(path):
			missing.append("%s:%s" % [id, path])
	return {
		"ok": missing.is_empty(),
		"missing": missing,
		"loaded": _streams.size() if enabled else SFX_PATHS.size() - missing.size(),
		"enabled": enabled,
	}


func _free_sfx_player() -> AudioStreamPlayer:
	for p in _sfx_players:
		if not p.playing:
			return p
	return null


func _on_sfx_finished(player: AudioStreamPlayer) -> void:
	if not player.has_meta("sfx_id"):
		return
	var id: String = str(player.get_meta("sfx_id"))
	var count := int(_playing_counts.get(id, 0))
	_playing_counts[id] = maxi(0, count - 1)
