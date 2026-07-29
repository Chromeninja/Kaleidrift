class_name ProceduralMusicController
extends Node

const MAX_VOICES := 12
const BASE_NOTE := 57
const MUSIC_BUS := &"Music"

var bank := ProceduralInstrumentBank.new()
var composer := MusicComposer.new()
var player := AudioStreamPlayer.new()
var context := MusicContext.new()
var playback: AudioStreamPlaybackPolyphonic
var enabled := true
var volume_linear := 0.7
var _started := false
var _bank_ready := false
var _step_elapsed := 0.0
var _step_index := 0
var _bar_index := 0
var _current_region := 0
var _pending_region := 0
var _region_change_pending := false
var _smoothed_energy := 0.0
var _smoothed_proximity := 0.0
var _smoothed_gain := 0.0
var _web_audio_started := false


func _ready() -> void:
	_ensure_audio_buses()
	var polyphonic := AudioStreamPolyphonic.new()
	polyphonic.polyphony = 16
	player.stream = polyphonic
	player.bus = MUSIC_BUS
	add_child(player)
	set_process(true)


func start(journey_seed: int) -> void:
	composer.configure(journey_seed, context.region_id)
	_current_region = context.region_id
	_pending_region = _current_region
	_started = true
	_step_elapsed = 0.0
	_step_index = 0
	_bar_index = 0
	if OS.has_feature("web"):
		_web_audio_started = true
		JavaScriptBridge.eval("window.kaleidriftAudioStart(%s);" % str(volume_linear))
		return
	if _bank_ready and enabled:
		_begin_playback()


func set_context(new_context: MusicContext) -> void:
	context = new_context
	if context.region_id != _current_region:
		_pending_region = context.region_id
		_region_change_pending = true


func set_music_enabled(new_enabled: bool) -> void:
	enabled = new_enabled
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.kaleidriftAudioSetEnabled(%s);" % ("true" if enabled else "false"))
		return
	if not enabled:
		player.stop()
		playback = null
	elif _started and _bank_ready:
		_begin_playback()


func set_volume_linear(new_volume: float) -> void:
	volume_linear = clampf(new_volume, 0.0, 1.0)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.kaleidriftAudioSetVolume(%s);" % str(volume_linear))


func stop(fade_seconds: float = 2.0) -> void:
	_started = false
	if OS.has_feature("web"):
		_web_audio_started = false
		JavaScriptBridge.eval("window.kaleidriftAudioStop(%s);" % str(maxf(fade_seconds, 0.01)))
		return
	if not is_instance_valid(player):
		return
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -60.0, maxf(fade_seconds, 0.01))
	tween.tween_callback(player.stop)


func _process(delta: float) -> void:
	if OS.has_feature("web"):
		return
	if not _bank_ready:
		_bank_ready = bank.build_next()
		if _bank_ready and _started and enabled:
			_begin_playback()
		return
	if not _started or not enabled or playback == null:
		return

	var smoothing := 1.0 - exp(-delta / (10.0 if context.reduced_motion else 7.0))
	_smoothed_energy = lerpf(_smoothed_energy, context.speed_normalized, smoothing)
	_smoothed_proximity = lerpf(_smoothed_proximity, context.surface_proximity, smoothing)
	var target_gain := volume_linear * (0.5 if context.paused else 1.0)
	_smoothed_gain = lerpf(_smoothed_gain, target_gain, 1.0 - exp(-delta / 2.0))
	player.volume_db = linear_to_db(maxf(_smoothed_gain, 0.001))
	_update_filter()

	var bpm := 58.0 + float(posmod(_current_region, 5)) * 2.0
	var step_seconds := 60.0 / bpm / 2.0
	_step_elapsed += delta
	while _step_elapsed >= step_seconds:
		_step_elapsed -= step_seconds
		_advance_step()


func _begin_playback() -> void:
	player.volume_db = -60.0
	player.play()
	playback = player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	_smoothed_gain = 0.001
	_play_pad()


func _advance_step() -> void:
	_step_index = (_step_index + 1) % 8
	if _step_index == 0:
		_bar_index += 1
		if _region_change_pending and _bar_index % 2 == 0:
			_current_region = _pending_region
			composer.configure(context.journey_seed, _current_region)
			_region_change_pending = false
		if _bar_index % 2 == 0:
			composer.advance_chord()
		_play_pad()

	var pulse_count := 2 if context.reduced_motion else (4 if context.game_mode == MusicContext.Mode.SURVIVAL else 3)
	var pattern := composer.euclidean_pattern(pulse_count, 8, posmod(_current_region, 8))
	if pattern[_step_index] and not composer.should_rest(0.35 if context.reduced_motion else 0.18):
		var note := composer.next_melody_note()
		var energy_db := lerpf(-22.0, -12.0, _smoothed_energy)
		_play_note(&"pluck", note, energy_db)
	if _step_index == 0 and context.game_mode == MusicContext.Mode.SURVIVAL:
		_play_note(&"bass", composer.root_midi - 12, -20.0 + _smoothed_energy * 4.0)
	if _step_index == 4 and not context.reduced_motion and not composer.should_rest(0.72):
		_play_note(&"bell", composer.next_melody_note() + 12, -23.0)
	if _step_index == 6 and _smoothed_proximity > 0.2:
		_play_note(&"wash", BASE_NOTE, -30.0 + _smoothed_proximity * 8.0)


func _play_pad() -> void:
	if playback == null:
		return
	var notes := composer.chord_notes()
	for note in notes:
		_play_note(&"pad", note, -23.0)


func _play_note(instrument: StringName, midi_note: int, volume_db: float) -> int:
	if playback == null:
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	var stream := bank.get_stream(instrument)
	if stream == null:
		return AudioStreamPlaybackPolyphonic.INVALID_ID
	var pitch_scale := pow(2.0, float(midi_note - BASE_NOTE) / 12.0)
	return playback.play_stream(stream, 0.0, volume_db, pitch_scale)


func _update_filter() -> void:
	var bus_index := AudioServer.get_bus_index(MUSIC_BUS)
	if bus_index < 0:
		return
	var filter := AudioServer.get_bus_effect(bus_index, 0) as AudioEffectLowPassFilter
	if filter:
		filter.cutoff_hz = lerpf(2200.0, 7200.0, _smoothed_energy)


func _ensure_audio_buses() -> void:
	var music_index := AudioServer.get_bus_index(MUSIC_BUS)
	if music_index < 0:
		AudioServer.add_bus()
		music_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_index, MUSIC_BUS)
		AudioServer.set_bus_send(music_index, &"Master")
	if AudioServer.get_bus_effect_count(music_index) == 0:
		var filter := AudioEffectLowPassFilter.new()
		filter.cutoff_hz = 3800.0
		AudioServer.add_bus_effect(music_index, filter)
		var delay := AudioEffectDelay.new()
		delay.dry = 0.82
		delay.tap1_active = true
		delay.tap1_delay_ms = 310.0
		delay.tap1_level_db = -18.0
		AudioServer.add_bus_effect(music_index, delay)
		var reverb := AudioEffectReverb.new()
		reverb.room_size = 0.72
		reverb.damping = 0.68
		reverb.wet = 0.14
		AudioServer.add_bus_effect(music_index, reverb)
	var master_index := AudioServer.get_bus_index(&"Master")
	var has_limiter := false
	for effect_index in range(AudioServer.get_bus_effect_count(master_index)):
		if AudioServer.get_bus_effect(master_index, effect_index) is AudioEffectHardLimiter:
			has_limiter = true
	if not has_limiter:
		AudioServer.add_bus_effect(master_index, AudioEffectHardLimiter.new())
