extends Node

# Procedural audio system — generates all SFX at runtime using AudioStreamWAV
# No external audio files needed

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
const MAX_CONCURRENT := 8
const SAMPLE_RATE := 22050

func _ready() -> void:
	# Create a pool of AudioStreamPlayers
	for i in MAX_CONCURRENT:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)

	# Generate all sound effects
	_sounds["sword_attack"] = _make_sound([
		{"type": "noise", "freq": 800.0, "duration": 0.08, "volume": 0.4},
		{"type": "sine", "freq": 400.0, "duration": 0.1, "volume": 0.3},
	])
	_sounds["arrow_fire"] = _make_sound([
		{"type": "noise", "freq": 2000.0, "duration": 0.05, "volume": 0.2},
		{"type": "sine", "freq": 1200.0, "duration": 0.08, "volume": 0.2},
	])
	_sounds["enemy_hit"] = _make_sound([
		{"type": "sine", "freq": 200.0, "duration": 0.1, "volume": 0.3},
	])
	_sounds["enemy_death"] = _make_sound([
		{"type": "sine", "freq": 300.0, "duration": 0.15, "volume": 0.4},
		{"type": "sine", "freq": 150.0, "duration": 0.2, "volume": 0.3},
	])
	_sounds["build_place"] = _make_sound([
		{"type": "sine", "freq": 600.0, "duration": 0.05, "volume": 0.3},
		{"type": "sine", "freq": 800.0, "duration": 0.08, "volume": 0.3},
	])
	_sounds["build_fail"] = _make_sound([
		{"type": "sine", "freq": 200.0, "duration": 0.15, "volume": 0.4},
		{"type": "sine", "freq": 150.0, "duration": 0.15, "volume": 0.3},
	])
	_sounds["build_remove"] = _make_sound([
		{"type": "sine", "freq": 500.0, "duration": 0.06, "volume": 0.2},
		{"type": "sine", "freq": 350.0, "duration": 0.08, "volume": 0.2},
	])
	_sounds["wave_start"] = _make_sound([
		{"type": "sine", "freq": 400.0, "duration": 0.12, "volume": 0.4},
		{"type": "sine", "freq": 500.0, "duration": 0.12, "volume": 0.4},
		{"type": "sine", "freq": 650.0, "duration": 0.15, "volume": 0.5},
	])
	_sounds["wave_complete"] = _make_sound([
		{"type": "sine", "freq": 500.0, "duration": 0.1, "volume": 0.4},
		{"type": "sine", "freq": 630.0, "duration": 0.1, "volume": 0.4},
		{"type": "sine", "freq": 750.0, "duration": 0.1, "volume": 0.4},
		{"type": "sine", "freq": 1000.0, "duration": 0.2, "volume": 0.5},
	])
	_sounds["game_over"] = _make_sound([
		{"type": "sine", "freq": 400.0, "duration": 0.2, "volume": 0.5},
		{"type": "sine", "freq": 300.0, "duration": 0.2, "volume": 0.4},
		{"type": "sine", "freq": 200.0, "duration": 0.3, "volume": 0.4},
		{"type": "sine", "freq": 120.0, "duration": 0.4, "volume": 0.3},
	])
	_sounds["victory"] = _make_sound([
		{"type": "sine", "freq": 520.0, "duration": 0.12, "volume": 0.4},
		{"type": "sine", "freq": 650.0, "duration": 0.12, "volume": 0.4},
		{"type": "sine", "freq": 780.0, "duration": 0.12, "volume": 0.5},
		{"type": "sine", "freq": 1040.0, "duration": 0.25, "volume": 0.5},
	])
	_sounds["gold_earned"] = _make_sound([
		{"type": "sine", "freq": 1200.0, "duration": 0.04, "volume": 0.15},
		{"type": "sine", "freq": 1600.0, "duration": 0.06, "volume": 0.15},
	])
	_sounds["select"] = _make_sound([
		{"type": "sine", "freq": 900.0, "duration": 0.04, "volume": 0.15},
	])
	_sounds["fireball_cast"] = _make_sound([
		{"type": "noise", "freq": 600.0, "duration": 0.06, "volume": 0.3},
		{"type": "sine", "freq": 350.0, "duration": 0.12, "volume": 0.4},
		{"type": "sine", "freq": 250.0, "duration": 0.08, "volume": 0.3},
	])
	_sounds["fireball_explode"] = _make_sound([
		{"type": "noise", "freq": 300.0, "duration": 0.15, "volume": 0.5},
		{"type": "sine", "freq": 120.0, "duration": 0.2, "volume": 0.4},
		{"type": "noise", "freq": 150.0, "duration": 0.15, "volume": 0.3},
	])
	_sounds["ice_blast"] = _make_sound([
		{"type": "noise", "freq": 2500.0, "duration": 0.08, "volume": 0.3},
		{"type": "sine", "freq": 1800.0, "duration": 0.1, "volume": 0.3},
		{"type": "sine", "freq": 1200.0, "duration": 0.15, "volume": 0.2},
	])

func play(sound_name: String) -> void:
	if not _sounds.has(sound_name):
		return
	# Find an available player
	for p in _players:
		if not p.playing:
			p.stream = _sounds[sound_name]
			p.play()
			return
	# All busy — steal the first one
	_players[0].stream = _sounds[sound_name]
	_players[0].play()

# ── Sound Generation ──

func _make_sound(tones: Array) -> AudioStreamWAV:
	# Calculate total duration
	var total_duration := 0.0
	for t in tones:
		total_duration += t["duration"]

	var num_samples := int(total_duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(num_samples * 2)

	var sample_offset := 0
	for t in tones:
		var tone_samples := int(t["duration"] * SAMPLE_RATE)
		var freq: float = t["freq"]
		var vol: float = t["volume"]
		var is_noise: bool = t["type"] == "noise"

		for i in tone_samples:
			var env := 1.0 - (float(i) / tone_samples)  # Linear decay
			env = env * env  # Exponential decay
			var sample: float
			if is_noise:
				sample = (randf() * 2.0 - 1.0) * vol * env
				# Apply a rough bandpass by mixing with tone
				sample = sample * 0.6 + sin(float(i) / SAMPLE_RATE * freq * TAU) * vol * env * 0.4
			else:
				sample = sin(float(i) / SAMPLE_RATE * freq * TAU) * vol * env

			var idx := (sample_offset + i) * 2
			if idx + 1 < data.size():
				var s16 := int(clampf(sample, -1.0, 1.0) * 32767)
				data[idx] = s16 & 0xFF
				data[idx + 1] = (s16 >> 8) & 0xFF

		sample_offset += tone_samples

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = data
	return stream
