extends Node
# AudioManager - Procedural horror soundscape for HOLLOW.
# All audio is generated at runtime using AudioStreamGenerator so the demo is fully self-contained.
# Layers: sub-bass drone, vinyl/static hiss, heartbeat, occasional wood stress creaks, presence swells.
# Tension from GameManager drives intensity and layering.

const SAMPLE_RATE := 44100.0
const BUFFER_FRAMES := 512

var drone_player: AudioStreamPlayer
var static_player: AudioStreamPlayer
var heartbeat_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer   # for one-shots (creaks, door, etc)

var _drone_phase: float = 0.0
var _static_phase: float = 0.0
var _heartbeat_phase: float = 0.0
var _heartbeat_timer: float = 0.0

var drone_volume: float = 0.0
var static_volume: float = 0.0
var heartbeat_volume: float = 0.0

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    _create_players()
    # Start very subtle atmosphere immediately
    start_ambient(0.15, 0.08)

func _create_players() -> void:
    drone_player = AudioStreamPlayer.new()
    drone_player.name = "Drone"
    add_child(drone_player)

    static_player = AudioStreamPlayer.new()
    static_player.name = "Static"
    add_child(static_player)

    heartbeat_player = AudioStreamPlayer.new()
    heartbeat_player.name = "Heartbeat"
    add_child(heartbeat_player)

    sfx_player = AudioStreamPlayer.new()
    sfx_player.name = "SFX"
    add_child(sfx_player)

    # Configure generators
    var drone_gen := AudioStreamGenerator.new()
    drone_gen.mix_rate = SAMPLE_RATE
    drone_gen.buffer_length = 0.1
    drone_player.stream = drone_gen

    var static_gen := AudioStreamGenerator.new()
    static_gen.mix_rate = SAMPLE_RATE
    static_gen.buffer_length = 0.1
    static_player.stream = static_gen

    var hb_gen := AudioStreamGenerator.new()
    hb_gen.mix_rate = SAMPLE_RATE
    hb_gen.buffer_length = 0.1
    heartbeat_player.stream = hb_gen

    # SFX will use generated short clips via play_sfx_burst or we can swap in a generator too.
    # For reliability we also support simple beeps via play_tone.

func start_ambient(drone_target: float = 0.22, static_target: float = 0.12) -> void:
    drone_volume = drone_target
    static_volume = static_target
    if not drone_player.playing:
        drone_player.play()
    if not static_player.playing:
        static_player.play()
    if not heartbeat_player.playing:
        heartbeat_player.play()

func set_tension(t: float) -> void:
    # Called from GameManager or world when dread rises
    var t_clamped: float = clamp(t, 0.0, 1.0)
    drone_volume = lerp(0.18, 0.55, t_clamped * 0.7)
    static_volume = lerp(0.08, 0.38, t_clamped)
    heartbeat_volume = lerp(0.0, 0.85, max(0.0, (t_clamped - 0.35) / 0.65))

func play_creak(intensity: float = 0.7) -> void:
    # Short wood stress / house settling sound
    _play_noise_burst(180.0 + _rng.randf_range(-30, 80), 0.28 * intensity, 0.6 * intensity, 0.9)

func play_door_close() -> void:
    _play_noise_burst(95.0, 0.55, 1.1, 0.85)
    # Follow with a deeper thud
    get_tree().create_timer(0.28).timeout.connect(func(): _play_noise_burst(62.0, 0.9, 0.6, 0.7))

func play_heavy_step() -> void:
    _play_noise_burst(70.0, 1.0, 0.18, 0.95)

func play_flashlight_click(on: bool) -> void:
    var freq := 820.0 if on else 610.0
    _play_tone_burst(freq, 0.035, 0.08, 0.4)

func play_note_page() -> void:
    # Dry paper / old document sound
    _play_noise_burst(420.0 + _rng.randf_range(-80, 120), 0.18, 0.22, 0.5)

func play_anomaly_pulse() -> void:
    # The "heart" of the house - low, wet, wrong
    _play_noise_burst(38.0, 1.6, 1.4, 0.95)
    get_tree().create_timer(0.6).timeout.connect(func(): _play_noise_burst(29.0, 2.1, 1.8, 0.8))

func play_whisper_swell(duration: float = 1.8) -> void:
    # High, breathy, almost vocal texture
    _play_noise_burst(1450.0, 0.22, duration, 0.35)

func play_end_sequence() -> void:
    # Final layered horror
    drone_volume = 0.7
    static_volume = 0.55
    heartbeat_volume = 1.0
    for i in 6:
        get_tree().create_timer(i * 0.7).timeout.connect(func():
            if is_instance_valid(self):
                _play_noise_burst(48.0 + i * 3, 1.8, 0.9, 0.9)
        )

func _process(delta: float) -> void:
    _fill_drone(delta)
    _fill_static(delta)
    _fill_heartbeat(delta)

# --- Generator fill functions ---

func _fill_drone(_delta: float) -> void:
    if not drone_player or not drone_player.playing or drone_volume <= 0.001:
        return
    var gen := drone_player.get_stream_playback() as AudioStreamGeneratorPlayback
    if gen == null:
        return
    var to_fill := gen.get_frames_available()
    if to_fill <= 0:
        return

    var buffer := PackedVector2Array()
    buffer.resize(to_fill)

    var base_freq := 38.0
    var lfo := 0.7 + sin(Time.get_ticks_msec() / 21000.0) * 0.3  # very slow breathing

    for i in to_fill:
        _drone_phase += base_freq / SAMPLE_RATE * lfo
        if _drone_phase > TAU:
            _drone_phase -= TAU

        # Sub sine + 2nd harmonic + slight noise for "body"
        var s := sin(_drone_phase) * 0.85
        s += sin(_drone_phase * 2.02) * 0.12
        s += (_rng.randf() - 0.5) * 0.03  # grit

        var vol := drone_volume * 0.65
        buffer[i] = Vector2(s * vol, s * vol)

    gen.push_buffer(buffer)

func _fill_static(_delta: float) -> void:
    if not static_player or not static_player.playing or static_volume <= 0.001:
        return
    var gen := static_player.get_stream_playback() as AudioStreamGeneratorPlayback
    if gen == null:
        return
    var to_fill := gen.get_frames_available()
    if to_fill <= 0:
        return

    var buffer := PackedVector2Array()
    buffer.resize(to_fill)

    for i in to_fill:
        _static_phase += 1.0
        # Band-limited-ish white noise (cheap high-pass feel by alternating)
        var n := (_rng.randf() - 0.5) * 2.0
        n = n * (0.6 + sin(_static_phase * 0.0007) * 0.4)  # slow modulation
        var vol := static_volume * 0.55
        buffer[i] = Vector2(n * vol, n * vol)

    gen.push_buffer(buffer)

func _fill_heartbeat(_delta: float) -> void:
    if not heartbeat_player or not heartbeat_player.playing or heartbeat_volume <= 0.001:
        _heartbeat_timer = 0.0
        return
    var gen := heartbeat_player.get_stream_playback() as AudioStreamGeneratorPlayback
    if gen == null:
        return
    var to_fill := gen.get_frames_available()
    if to_fill <= 0:
        return

    var buffer := PackedVector2Array()
    buffer.resize(to_fill)

    var bpm: float = lerp(48.0, 92.0, clamp(heartbeat_volume, 0.0, 1.0))
    var interval: float = 60.0 / bpm

    for i in to_fill:
        _heartbeat_phase += 1.0 / SAMPLE_RATE
        _heartbeat_timer += 1.0 / SAMPLE_RATE

        var s := 0.0
        if _heartbeat_timer > interval:
            _heartbeat_timer = 0.0
            # Two thumps (lub-dub)
            pass  # handled below via phase

        # Simple heartbeat shape: low sine burst
        var local_t := fmod(_heartbeat_phase * bpm / 60.0, 1.0)
        if local_t < 0.08:
            s = sin(local_t / 0.08 * TAU) * exp(-local_t * 18.0) * 1.6
        elif local_t > 0.18 and local_t < 0.26:
            s = sin((local_t - 0.18) / 0.08 * TAU) * exp(-(local_t - 0.18) * 22.0) * 1.1

        var vol := heartbeat_volume * 0.9
        buffer[i] = Vector2(s * vol, s * vol)

    gen.push_buffer(buffer)

func _play_noise_burst(center_freq: float, q: float, duration: float, volume: float) -> void:
    # Cheap resonant noise burst for creaks, thuds, etc. Uses a temporary generator.
    var player := AudioStreamPlayer.new()
    add_child(player)
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = SAMPLE_RATE
    gen.buffer_length = max(0.2, duration + 0.1)
    player.stream = gen
    player.volume_db = linear_to_db(volume * 0.8)
    player.play()

    var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
    var frames := int(duration * SAMPLE_RATE)
    var buf := PackedVector2Array()
    buf.resize(frames)

    var phase := 0.0
    var env := 0.0
    var decay := 1.0 / (duration * 0.7)

    for i in frames:
        phase += center_freq / SAMPLE_RATE
        if phase > TAU:
            phase -= TAU
        env = max(0.0, 1.0 - (i / float(frames)) * decay)
        var n := (_rng.randf() - 0.5) * 2.0
        # Simple resonator
        var s := n * 0.7 + sin(phase) * 0.3
        s *= env * q
        buf[i] = Vector2(s, s)

    playback.push_buffer(buf)

    # Auto cleanup
    get_tree().create_timer(duration + 0.4).timeout.connect(func():
        if is_instance_valid(player):
            player.queue_free()
    )

func _play_tone_burst(freq: float, duration: float, volume: float, q: float = 0.6) -> void:
    var player := AudioStreamPlayer.new()
    add_child(player)
    var gen := AudioStreamGenerator.new()
    gen.mix_rate = SAMPLE_RATE
    gen.buffer_length = max(0.15, duration + 0.05)
    player.stream = gen
    player.volume_db = linear_to_db(volume)
    player.play()

    var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
    var frames := int(duration * SAMPLE_RATE)
    var buf := PackedVector2Array()
    buf.resize(frames)

    var phase := 0.0
    var env := 0.0

    for i in frames:
        phase += freq / SAMPLE_RATE
        if phase > TAU: phase -= TAU
        env = 1.0 - (i / float(frames))
        var s := sin(phase) * env * q
        buf[i] = Vector2(s, s)

    playback.push_buffer(buf)

    get_tree().create_timer(duration + 0.3).timeout.connect(func():
        if is_instance_valid(player): player.queue_free()
    )

func stop_all() -> void:
    drone_volume = 0.0
    static_volume = 0.0
    heartbeat_volume = 0.0
    if drone_player: drone_player.stop()
    if static_player: static_player.stop()
    if heartbeat_player: heartbeat_player.stop()
