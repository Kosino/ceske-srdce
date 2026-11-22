extends Node
## Fáze 5 — AI vs AI headless balance sim. Autoload; activated by `--sim`.

signal game_finished(result: Dictionary)
signal suite_finished(report_path: String)

const GAMES_PER_PAIR := 20
const TIME_SCALE := 20.0
const MAX_GAME_SEC := 150.0 ## simulated seconds before draw
## Shared age unlock schedule (sim seconds) so both sides get the same tech gate.
const AGE_AT := {2: 70.0, 3: 150.0, 4: 260.0}
const REPORT_PATH := "res://docs/balance/report.md"

var active: bool = false
var smoke_only: bool = false ## one short game for headless regression
var pairs: Array[Dictionary] = [] ## [{a, b}] unordered civ pairs
var pair_index: int = 0
var game_index: int = 0 ## 0..GAMES_PER_PAIR-1 within pair
var results: Array[Dictionary] = []
var unit_trains: Dictionary = {} ## civ_id -> {unit_id -> count}
var age_reach: Dictionary = {} ## civ_id -> {age -> [times]}  (shared clock recorded per game for both)
var _match_start_sec: float = 0.0
var _age_logged: Dictionary = {} ## age -> bool for current game
var _current_a: String = ""
var _current_b: String = ""
var _running_game: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--sim-smoke"):
		active = true
		smoke_only = true
	elif args.has("--sim"):
		active = true
		smoke_only = false
	if not active:
		return
	_build_pairs()
	unit_trains = {}
	age_reach = {}
	for civ in CivData.ALL_CIV_IDS:
		unit_trains[civ] = {}
		age_reach[civ] = {2: [], 3: [], 4: []}
	print("[SIM] BalanceSim active smoke=%s pairs=%d games/pair=%d" % [
		smoke_only, pairs.size(), GAMES_PER_PAIR if not smoke_only else 1
	])


func _build_pairs() -> void:
	pairs.clear()
	var ids: Array = CivData.ALL_CIV_IDS.duplicate()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			pairs.append({"a": str(ids[i]), "b": str(ids[j])})


func games_per_pair() -> int:
	return 1 if smoke_only else GAMES_PER_PAIR


func current_pair() -> Dictionary:
	if pair_index < 0 or pair_index >= pairs.size():
		return {}
	return pairs[pair_index]


func begin_game() -> Dictionary:
	## Called by Map when starting a sim match. Returns {civ_a, civ_b, seed}.
	_running_game = true
	_age_logged = {}
	_match_start_sec = Time.get_ticks_msec() / 1000.0
	var pair := current_pair()
	_current_a = str(pair.get("a", CivData.DEFAULT_PLAYER))
	_current_b = str(pair.get("b", CivData.DEFAULT_ENEMY))
	# Alternate home/away each game for fairness.
	if game_index % 2 == 1:
		var tmp := _current_a
		_current_a = _current_b
		_current_b = tmp
	GameManager.player_civ = _current_a
	GameManager.enemy_civ = _current_b
	GameManager.current_age = 1
	GameManager.food = 200
	GameManager.wood = 200
	GameManager.gold = 100
	GameManager.stone = 0
	GameManager.population = 0
	GameManager.population_max = 10
	GameManager._researched = {0: {}, 1: {}}
	Engine.time_scale = TIME_SCALE
	var seed := 4242 + pair_index * 1000 + game_index
	print("[SIM] game pair=%s vs %s idx=%d seed=%d" % [_current_a, _current_b, game_index, seed])
	return {"civ_a": _current_a, "civ_b": _current_b, "seed": seed}


func tick_age_schedule(elapsed_sim_sec: float) -> void:
	if not _running_game:
		return
	for age in [2, 3, 4]:
		var need: float = float(AGE_AT[age])
		if elapsed_sim_sec >= need and GameManager.current_age < age:
			GameManager.current_age = age
		if elapsed_sim_sec >= need and not _age_logged.get(age, false):
			_age_logged[age] = true
			# Record shared reach time for both civs in this matchup.
			(age_reach[_current_a][age] as Array).append(elapsed_sim_sec)
			(age_reach[_current_b][age] as Array).append(elapsed_sim_sec)
			print("[SIM] age %d reached at t=%.1fs" % [age, elapsed_sim_sec])


func record_unit_trained(team: int, unit_id: String) -> void:
	if not active or not _running_game or unit_id == "" or unit_id == "villager":
		return
	var civ := GameManager.civ_for_team(team)
	if not unit_trains.has(civ):
		unit_trains[civ] = {}
	var bag: Dictionary = unit_trains[civ]
	bag[unit_id] = int(bag.get(unit_id, 0)) + 1


func finish_game(winner_team: int, elapsed_sim_sec: float, timed_out: bool = false) -> void:
	if not _running_game:
		return
	_running_game = false
	Engine.time_scale = 1.0
	var winner_civ := ""
	var loser_civ := ""
	if timed_out or winner_team < 0:
		winner_civ = ""
		loser_civ = ""
	elif winner_team == 0:
		winner_civ = _current_a
		loser_civ = _current_b
	else:
		winner_civ = _current_b
		loser_civ = _current_a
	var row := {
		"civ_a": _current_a,
		"civ_b": _current_b,
		"winner": winner_civ,
		"loser": loser_civ,
		"draw": timed_out or winner_team < 0,
		"length": elapsed_sim_sec,
		"pair_index": pair_index,
		"game_index": game_index,
	}
	results.append(row)
	print("[SIM] finished winner=%s draw=%s length=%.1fs" % [
		winner_civ if winner_civ != "" else "—", row["draw"], elapsed_sim_sec
	])
	game_finished.emit(row)
	_advance_or_finish()


func _advance_or_finish() -> void:
	game_index += 1
	if game_index >= games_per_pair():
		game_index = 0
		pair_index += 1
	if smoke_only or pair_index >= pairs.size():
		var path := write_report()
		suite_finished.emit(path)
		print("[SIM] suite done report=%s" % path)
		return
	# Next game — Map reloads itself.
	print("[SIM] next pair_index=%d game_index=%d" % [pair_index, game_index])


func suite_done() -> bool:
	return smoke_only or pair_index >= pairs.size()


func write_report() -> String:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/balance"))
	var md := _build_report_markdown()
	var f := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("[SIM] cannot write %s" % REPORT_PATH)
		return ""
	f.store_string(md)
	f.close()
	print("[SIM] wrote %s" % ProjectSettings.globalize_path(REPORT_PATH))
	return REPORT_PATH


func _build_report_markdown() -> String:
	var lines: PackedStringArray = []
	lines.append("# AI vs AI balance report")
	lines.append("")
	lines.append("Generated by headless `--sim` (Fáze 5). Seeded map, two `SimpleEnemyAI`, time scale ×%.0f, max %.0fs/game, %d games/pair." % [
		TIME_SCALE, MAX_GAME_SEC, GAMES_PER_PAIR if not smoke_only else 1
	])
	lines.append("")
	lines.append("Age unlock schedule (shared): age2@%.0fs, age3@%.0fs, age4@%.0fs." % [
		AGE_AT[2], AGE_AT[3], AGE_AT[4]
	])
	lines.append("")

	# Win rates
	var wins: Dictionary = {}
	var played: Dictionary = {}
	var lengths: Array[float] = []
	for civ in CivData.ALL_CIV_IDS:
		wins[civ] = 0
		played[civ] = 0
	var draws := 0
	for r in results:
		lengths.append(float(r["length"]))
		if r["draw"]:
			draws += 1
			played[r["civ_a"]] = int(played[r["civ_a"]]) + 1
			played[r["civ_b"]] = int(played[r["civ_b"]]) + 1
			continue
		var w: String = str(r["winner"])
		var l: String = str(r["loser"])
		wins[w] = int(wins[w]) + 1
		played[w] = int(played[w]) + 1
		played[l] = int(played[l]) + 1

	lines.append("## Win rate per civilization")
	lines.append("")
	lines.append("| Civ | Wins | Games | Win % |")
	lines.append("|-----|------|-------|-------|")
	var outside: Array[String] = []
	for civ in CivData.ALL_CIV_IDS:
		var g := int(played.get(civ, 0))
		var w := int(wins.get(civ, 0))
		var pct := 0.0 if g == 0 else 100.0 * float(w) / float(g)
		lines.append("| %s | %d | %d | %.1f%% |" % [CivData.civ_name(civ), w, g, pct])
		if g > 0 and (pct < 40.0 or pct > 60.0):
			outside.append(civ)
	lines.append("")
	lines.append("Draws / timeouts: **%d** / %d games." % [draws, results.size()])
	lines.append("")

	# Avg length
	var avg_len := 0.0
	if lengths.size() > 0:
		for x in lengths:
			avg_len += x
		avg_len /= float(lengths.size())
	lines.append("## Average game length")
	lines.append("")
	lines.append("%.1f simulated seconds (n=%d)." % [avg_len, lengths.size()])
	lines.append("")

	# Age reach
	lines.append("## Age-reach times (avg sim seconds)")
	lines.append("")
	lines.append("| Civ | →Age2 | →Age3 | →Age4 |")
	lines.append("|-----|-------|-------|-------|")
	for civ in CivData.ALL_CIV_IDS:
		var a2 := _avg(age_reach.get(civ, {}).get(2, []))
		var a3 := _avg(age_reach.get(civ, {}).get(3, []))
		var a4 := _avg(age_reach.get(civ, {}).get(4, []))
		lines.append("| %s | %s | %s | %s |" % [
			CivData.civ_name(civ), _fmt_avg(a2), _fmt_avg(a3), _fmt_avg(a4)
		])
	lines.append("")

	# Most trained units
	lines.append("## Most-trained units (per civ)")
	lines.append("")
	for civ in CivData.ALL_CIV_IDS:
		var bag: Dictionary = unit_trains.get(civ, {})
		var ranked: Array = bag.keys()
		ranked.sort_custom(func(a, b): return int(bag[a]) > int(bag[b]))
		var parts: PackedStringArray = []
		var n := mini(5, ranked.size())
		for i in range(n):
			var uid: String = str(ranked[i])
			parts.append("%s (%d)" % [uid, int(bag[uid])])
		lines.append("- **%s:** %s" % [
			CivData.civ_name(civ), (", ".join(parts) if parts.size() > 0 else "—")
		])
	lines.append("")

	# Pair matrix
	lines.append("## Pair results")
	lines.append("")
	lines.append("| Pair | A wins | B wins | Draws | Avg length |")
	lines.append("|------|--------|--------|-------|------------|")
	for p in pairs:
		var ca: String = str(p["a"])
		var cb: String = str(p["b"])
		var aw := 0
		var bw := 0
		var dw := 0
		var lens: Array[float] = []
		for r in results:
			var same := (
				(str(r["civ_a"]) == ca and str(r["civ_b"]) == cb)
				or (str(r["civ_a"]) == cb and str(r["civ_b"]) == ca)
			)
			# Count only games whose unordered pair matches; home/away swapped still same pair.
			var ra := str(r["civ_a"])
			var rb := str(r["civ_b"])
			var match_pair := (ra == ca and rb == cb) or (ra == cb and rb == ca)
			if not match_pair:
				continue
			# Map winner back to unordered labels.
			if r["draw"]:
				dw += 1
			elif str(r["winner"]) == ca:
				aw += 1
			elif str(r["winner"]) == cb:
				bw += 1
			lens.append(float(r["length"]))
		var al := 0.0
		for x in lens:
			al += x
		if lens.size() > 0:
			al /= float(lens.size())
		lines.append("| %s vs %s | %d | %d | %d | %.1fs |" % [
			CivData.civ_name(ca), CivData.civ_name(cb), aw, bw, dw, al
		])
	lines.append("")

	# Tweaks — propose only, do not apply
	lines.append("## Proposed tweaks (not applied)")
	lines.append("")
	if outside.is_empty():
		lines.append("All civ win rates are inside **40–60%**. No balance tweaks proposed.")
	else:
		var names: PackedStringArray = []
		for c in outside:
			names.append(CivData.civ_name(str(c)))
		lines.append("Civs outside 40–60%% win rate: **%s**." % ", ".join(names))
		lines.append("")
		for civ in outside:
			var g := int(played.get(civ, 0))
			var w := int(wins.get(civ, 0))
			var pct := 0.0 if g == 0 else 100.0 * float(w) / float(g)
			if pct > 60.0:
				lines.append(_propose_nerf(str(civ), pct))
			else:
				lines.append(_propose_buff(str(civ), pct))
		lines.append("")
		lines.append("*These are proposals only — do not apply until approved.*")
	lines.append("")
	return "\n".join(lines)


func _propose_nerf(civ: String, pct: float) -> String:
	match civ:
		CivData.MORAVANE:
			return "- **Moravané (%.1f%%):** NÁVRH — soften wood gather bonus +15%%→+10%%, or raise wood building discount −10%%→−5%%." % pct
		CivData.PREMYSLOVCI:
			return "- **Přemyslovci (%.1f%%):** NÁVRH — cut cavalry damage bonus +10%%→+5%%, or +5 gold cost on Družiník." % pct
		CivData.HUSITE:
			return "- **Husité (%.1f%%):** NÁVRH — reduce Válečný vůz HP or pierce by ~10%%, or slow unique train +5 s." % pct
		CivData.HABSBURKOVE:
			return "- **Habsburkové (%.1f%%):** NÁVRH — trim Lancknecht cavalry bonus +10→+6, or +10 food on unique cost." % pct
		_:
			return "- **%s (%.1f%%):** NÁVRH — reduce unique unit combat stats ~10%%." % [CivData.civ_name(civ), pct]


func _propose_buff(civ: String, pct: float) -> String:
	match civ:
		CivData.MORAVANE:
			return "- **Moravané (%.1f%%):** NÁVRH — bump wood gather +15%%→+20%%, or Bradaticar building bonus +8→+10." % pct
		CivData.PREMYSLOVCI:
			return "- **Přemyslovci (%.1f%%):** NÁVRH — cavalry damage +10%%→+15%%, or −5 gold on light cavalry." % pct
		CivData.HUSITE:
			return "- **Husité (%.1f%%):** NÁVRH — infantry HP civ bonus +5%%, or Válečný vůz −5 wood cost." % pct
		CivData.HABSBURKOVE:
			return "- **Habsburkové (%.1f%%):** NÁVRH — Lancknecht +1 melee armor, or earlier age-3 unique unlock via −50 stone castle (too heavy — prefer unit buff)." % pct
		_:
			return "- **%s (%.1f%%):** NÁVRH — +5%% unique unit damage." % [CivData.civ_name(civ), pct]


func _avg(arr: Variant) -> float:
	if arr == null:
		return -1.0
	var a: Array = arr as Array
	if a.is_empty():
		return -1.0
	var s := 0.0
	for x in a:
		s += float(x)
	return s / float(a.size())


func _fmt_avg(v: float) -> String:
	if v < 0.0:
		return "—"
	return "%.1f" % v
