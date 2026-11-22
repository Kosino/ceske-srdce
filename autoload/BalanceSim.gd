extends Node
## Fáze 5 — AI vs AI headless balance sim.
## Autoload is a no-op unless `--sim` / `--sim-smoke`.

signal game_finished(result: Dictionary)
signal suite_finished(report_path: String)

const GAMES_PER_PAIR := 20
const TIME_SCALE := 80.0
const MAX_GAME_SEC := 2400.0 ## 40 in-game minutes
const REPORT_PATH := "res://docs/balance/report.md"
const Z95 := 1.96

const STRAT_RUSH := "rush"
const STRAT_BOOM := "boom"
const STRAT_FC := "fast_castle"
const STRATEGIES := [STRAT_RUSH, STRAT_BOOM, STRAT_FC]

var active: bool = false
var smoke_only: bool = false
var pairs: Array[Dictionary] = []
var pair_index: int = 0
var game_index: int = 0
var results: Array[Dictionary] = []
var unit_trains: Dictionary = {} ## civ_id -> {unit_id -> count}
var age_reach: Dictionary = {} ## civ_id -> {age -> [sim_sec]}
var _elapsed_sim: float = 0.0
var _current_a: String = ""
var _current_b: String = ""
var _strat_a: String = STRAT_RUSH
var _strat_b: String = STRAT_RUSH
var _running_game: bool = false
var _suite_ready: bool = false
var _strat_bag: Array[String] = []


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.has("--sim-smoke"):
		active = true
		smoke_only = true
	elif args.has("--sim"):
		active = true
		smoke_only = false
	if active:
		_ensure_suite()
		print("[SIM] BalanceSim active smoke=%s pairs=%d games/pair=%d max=%.0fs scale=×%.0f" % [
			smoke_only, pairs.size(), games_per_pair(), MAX_GAME_SEC, TIME_SCALE
		])


func _ensure_suite() -> void:
	if _suite_ready:
		return
	_suite_ready = true
	_build_pairs()
	unit_trains = {}
	age_reach = {}
	_strat_bag.clear()
	for civ in CivData.ALL_CIV_IDS:
		unit_trains[civ] = {}
		age_reach[civ] = {2: [], 3: [], 4: []}


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


func _refill_strat_bag(rng: RandomNumberGenerator) -> void:
	## Equal thirds → each strategy ≥25% over the suite.
	_strat_bag.clear()
	for s in STRATEGIES:
		for _i in 8:
			_strat_bag.append(s)
	for i in range(_strat_bag.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: String = _strat_bag[i]
		_strat_bag[i] = _strat_bag[j]
		_strat_bag[j] = tmp


func _next_strategy(rng: RandomNumberGenerator) -> String:
	if _strat_bag.is_empty():
		_refill_strat_bag(rng)
	return _strat_bag.pop_back()


func begin_game() -> Dictionary:
	if not active:
		return {}
	_ensure_suite()
	_running_game = true
	_elapsed_sim = 0.0
	var pair := current_pair()
	_current_a = str(pair.get("a", CivData.DEFAULT_PLAYER))
	_current_b = str(pair.get("b", CivData.DEFAULT_ENEMY))
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
	var sim_seed := 4242 + pair_index * 10007 + game_index * 97 + int(Time.get_ticks_msec()) % 1000
	var rng := RandomNumberGenerator.new()
	rng.seed = sim_seed
	var jitter_a := rng.randf_range(0.90, 1.10)
	var jitter_b := rng.randf_range(0.90, 1.10)
	_strat_a = _next_strategy(rng)
	_strat_b = _next_strategy(rng)
	print("[SIM] game pair=%s(%s) vs %s(%s) idx=%d seed=%d" % [
		_current_a, _strat_a, _current_b, _strat_b, game_index, sim_seed
	])
	return {
		"civ_a": _current_a,
		"civ_b": _current_b,
		"seed": sim_seed,
		"jitter_a": jitter_a,
		"jitter_b": jitter_b,
		"strategy_a": _strat_a,
		"strategy_b": _strat_b,
	}


func note_elapsed(elapsed_sim_sec: float) -> void:
	if _running_game:
		_elapsed_sim = elapsed_sim_sec


func elapsed() -> float:
	return _elapsed_sim


func record_age_reached(team: int, age: int) -> void:
	if not active or not _running_game:
		return
	if age < 2 or age > 4:
		return
	var civ := GameManager.civ_for_team(team)
	if not age_reach.has(civ):
		age_reach[civ] = {2: [], 3: [], 4: []}
	(age_reach[civ][age] as Array).append(_elapsed_sim)
	print("[SIM] team=%d civ=%s age %d at t=%.1fs" % [team, civ, age, _elapsed_sim])


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
	var is_draw := timed_out or winner_team < 0
	if not is_draw:
		if winner_team == 0:
			winner_civ = _current_a
			loser_civ = _current_b
		else:
			winner_civ = _current_b
			loser_civ = _current_a
	var row := {
		"civ_a": _current_a,
		"civ_b": _current_b,
		"strategy_a": _strat_a,
		"strategy_b": _strat_b,
		"winner": winner_civ,
		"loser": loser_civ,
		"draw": is_draw,
		"length": elapsed_sim_sec,
		"pair_index": pair_index,
		"game_index": game_index,
	}
	results.append(row)
	print("[SIM] finished winner=%s draw=%s length=%.1fs strats=%s/%s" % [
		winner_civ if winner_civ != "" else "—", is_draw, elapsed_sim_sec, _strat_a, _strat_b
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
	print("[SIM] next pair_index=%d game_index=%d" % [pair_index, game_index])


func suite_done() -> bool:
	if not active:
		return true
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
	_ensure_suite()
	var lines: PackedStringArray = []
	lines.append("# AI vs AI balance report")
	lines.append("")
	var games_pp := GAMES_PER_PAIR if not smoke_only else 1
	lines.append((
		"Generated by headless `--sim` (Fáze 5). Two `SimpleEnemyAI` with per-game strategies "
		+ "(rush / boom / fast-castle, each ≥25%%), economic ages, time scale ×%.0f, "
		+ "max **40 in-game minutes** (%.0fs), %d games/pair. "
		+ "Win = destroy enemy Town Center. Timeouts = draws. Seed + AI jitter ±10%%."
	) % [TIME_SCALE, MAX_GAME_SEC, games_pp])
	lines.append("")

	var wins: Dictionary = {}
	var decided: Dictionary = {}
	var played: Dictionary = {}
	var lengths: Array[float] = []
	for civ in CivData.ALL_CIV_IDS:
		wins[civ] = 0
		decided[civ] = 0
		played[civ] = 0
	var draws := 0
	var strat_played: Dictionary = {}
	var strat_wins: Dictionary = {}
	var strat_draws: Dictionary = {}
	for s in STRATEGIES:
		strat_played[s] = 0
		strat_wins[s] = 0
		strat_draws[s] = 0

	for r in results:
		lengths.append(float(r["length"]))
		played[r["civ_a"]] = int(played[r["civ_a"]]) + 1
		played[r["civ_b"]] = int(played[r["civ_b"]]) + 1
		var sa: String = str(r.get("strategy_a", STRAT_RUSH))
		var sb: String = str(r.get("strategy_b", STRAT_RUSH))
		strat_played[sa] = int(strat_played.get(sa, 0)) + 1
		strat_played[sb] = int(strat_played.get(sb, 0)) + 1
		if r["draw"]:
			draws += 1
			strat_draws[sa] = int(strat_draws.get(sa, 0)) + 1
			strat_draws[sb] = int(strat_draws.get(sb, 0)) + 1
			continue
		var w: String = str(r["winner"])
		var l: String = str(r["loser"])
		wins[w] = int(wins[w]) + 1
		decided[w] = int(decided[w]) + 1
		decided[l] = int(decided[l]) + 1
		if w == str(r["civ_a"]):
			strat_wins[sa] = int(strat_wins.get(sa, 0)) + 1
		elif w == str(r["civ_b"]):
			strat_wins[sb] = int(strat_wins.get(sb, 0)) + 1

	var total := results.size()
	var decided_n := total - draws
	var decided_share := 0.0 if total == 0 else 100.0 * float(decided_n) / float(total)

	lines.append("## Win rate per civilization (decided games)")
	lines.append("")
	lines.append("| Civ | Wins | Decided | Win % | 95% CI | Decided share |")
	lines.append("|-----|------|---------|-------|--------|---------------|")
	var outside: Array[String] = []
	for civ in CivData.ALL_CIV_IDS:
		var d := int(decided.get(civ, 0))
		var w := int(wins.get(civ, 0))
		var g := int(played.get(civ, 0))
		var ci := _wilson(w, d)
		var pct := 0.0 if d == 0 else 100.0 * float(w) / float(d)
		var share := 0.0 if g == 0 else 100.0 * float(d) / float(g)
		lines.append("| %s | %d | %d | %.1f%% | [%.1f%%, %.1f%%] | %.0f%% |" % [
			CivData.civ_name(civ), w, d, pct, ci.lo * 100.0, ci.hi * 100.0, share
		])
		if d > 0 and (pct < 40.0 or pct > 60.0):
			outside.append(civ)
	lines.append("")
	lines.append(
		"Draws / timeouts: **%d** / %d games. Share of decided games: **%.1f%%**." % [
			draws, total, decided_share
		]
	)
	lines.append("")

	## Length distribution
	var avg_len := 0.0
	for x in lengths:
		avg_len += x
	if lengths.size() > 0:
		avg_len /= float(lengths.size())
	var sorted_len: Array[float] = lengths.duplicate()
	sorted_len.sort()
	var med := _percentile(sorted_len, 0.50)
	var p25 := _percentile(sorted_len, 0.25)
	var p75 := _percentile(sorted_len, 0.75)
	lines.append("## Game length distribution")
	lines.append("")
	lines.append(
		"Avg **%.1fs** (%.1f min). Median **%.1fs**. p25 **%.1fs**. p75 **%.1fs**. Cap %.0fs (40 min)." % [
			avg_len, avg_len / 60.0, med, p25, p75, MAX_GAME_SEC
		]
	)
	lines.append("")

	## Strategy mix + win rate
	lines.append("## Strategies (rush / boom / fast-castle)")
	lines.append("")
	lines.append("| Strategy | Appearances | Share | Wins | Win % (non-draw apps) |")
	lines.append("|----------|-------------|-------|------|------------------------|")
	var strat_total := 0
	for s in STRATEGIES:
		strat_total += int(strat_played.get(s, 0))
	for s in STRATEGIES:
		var sp := int(strat_played.get(s, 0))
		var sw := int(strat_wins.get(s, 0))
		var sd := int(strat_draws.get(s, 0))
		var non_draw := sp - sd
		var share := 0.0 if strat_total == 0 else 100.0 * float(sp) / float(strat_total)
		var wp := 0.0 if non_draw == 0 else 100.0 * float(sw) / float(non_draw)
		lines.append("| %s | %d | %.1f%% | %d | %.1f%% |" % [s, sp, share, sw, wp])
	lines.append("")

	## Age reach with %
	lines.append("## Age-reach (avg sim seconds + % of civ appearances)")
	lines.append("")
	lines.append("| Civ | →Age2 | % | →Age3 | % | →Age4 | % |")
	lines.append("|-----|-------|---|-------|---|-------|---|")
	for civ in CivData.ALL_CIV_IDS:
		var g := int(played.get(civ, 0))
		var arr2: Array = age_reach.get(civ, {}).get(2, [])
		var arr3: Array = age_reach.get(civ, {}).get(3, [])
		var arr4: Array = age_reach.get(civ, {}).get(4, [])
		var a2 := _avg(arr2)
		var a3 := _avg(arr3)
		var a4 := _avg(arr4)
		var p2 := 0.0 if g == 0 else 100.0 * float(arr2.size()) / float(g)
		var p3 := 0.0 if g == 0 else 100.0 * float(arr3.size()) / float(g)
		var p4 := 0.0 if g == 0 else 100.0 * float(arr4.size()) / float(g)
		lines.append("| %s | %s | %.0f%% | %s | %.0f%% | %s | %.0f%% |" % [
			CivData.civ_name(civ), _fmt_avg(a2), p2, _fmt_avg(a3), p3, _fmt_avg(a4), p4
		])
	lines.append("")

	lines.append("## Army composition (units trained per civ)")
	lines.append("")
	for civ in CivData.ALL_CIV_IDS:
		var bag: Dictionary = unit_trains.get(civ, {})
		var ranked: Array = bag.keys()
		ranked.sort_custom(func(a, b): return int(bag[a]) > int(bag[b]))
		var parts: PackedStringArray = []
		var n := mini(10, ranked.size())
		for i in range(n):
			var uid: String = str(ranked[i])
			parts.append("%s (%d)" % [uid, int(bag[uid])])
		lines.append("- **%s:** %s" % [
			CivData.civ_name(civ), (", ".join(parts) if parts.size() > 0 else "—")
		])
	lines.append("")

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
			var ra := str(r["civ_a"])
			var rb := str(r["civ_b"])
			var match_pair := (ra == ca and rb == cb) or (ra == cb and rb == ca)
			if not match_pair:
				continue
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

	lines.append("## Proposed tweaks (not applied)")
	lines.append("")
	if outside.is_empty():
		lines.append("All civ win rates (decided) are inside **40–60%**. No balance tweaks proposed.")
	else:
		var names: PackedStringArray = []
		for c in outside:
			names.append(CivData.civ_name(str(c)))
		lines.append("Civs outside 40–60%% win rate: **%s**." % ", ".join(names))
		lines.append("")
		for civ in outside:
			var d := int(decided.get(civ, 0))
			var w := int(wins.get(civ, 0))
			var pct := 0.0 if d == 0 else 100.0 * float(w) / float(d)
			if pct > 60.0:
				lines.append(_propose_nerf(str(civ), pct))
			else:
				lines.append(_propose_buff(str(civ), pct))
		lines.append("")
		lines.append("*These are NÁVRH proposals only — do not apply until approved.*")
	lines.append("")
	return "\n".join(lines)


func _percentile(sorted_arr: Array, p: float) -> float:
	if sorted_arr.is_empty():
		return 0.0
	if sorted_arr.size() == 1:
		return float(sorted_arr[0])
	var idx := clampf(p, 0.0, 1.0) * float(sorted_arr.size() - 1)
	var lo := int(floor(idx))
	var hi := int(ceil(idx))
	if lo == hi:
		return float(sorted_arr[lo])
	var t := idx - float(lo)
	return float(sorted_arr[lo]) * (1.0 - t) + float(sorted_arr[hi]) * t


func _wilson(wins: int, n: int) -> Dictionary:
	if n <= 0:
		return {"lo": 0.0, "hi": 0.0, "p": 0.0}
	var p := float(wins) / float(n)
	var z2 := Z95 * Z95
	var denom := 1.0 + z2 / float(n)
	var center := (p + z2 / (2.0 * float(n))) / denom
	var margin := (
		Z95 * sqrt((p * (1.0 - p) + z2 / (4.0 * float(n))) / float(n))
	) / denom
	return {
		"lo": clampf(center - margin, 0.0, 1.0),
		"hi": clampf(center + margin, 0.0, 1.0),
		"p": p,
	}


func _propose_nerf(civ: String, pct: float) -> String:
	match civ:
		CivData.MORAVANE:
			return "- **Moravané (%.1f%%):** NÁVRH — soften wood gather bonus +15%%→+10%%." % pct
		CivData.PREMYSLOVCI:
			return "- **Přemyslovci (%.1f%%):** NÁVRH — cut cavalry damage bonus +10%%→+5%%." % pct
		CivData.HUSITE:
			return "- **Husité (%.1f%%):** NÁVRH — reduce Válečný vůz HP/pierce ~10%%." % pct
		CivData.HABSBURKOVE:
			return "- **Habsburkové (%.1f%%):** NÁVRH — trim Lancknecht cavalry bonus." % pct
		_:
			return "- **%s (%.1f%%):** NÁVRH — reduce unique combat ~10%%." % [CivData.civ_name(civ), pct]


func _propose_buff(civ: String, pct: float) -> String:
	match civ:
		CivData.MORAVANE:
			return "- **Moravané (%.1f%%):** NÁVRH — bump wood gather +15%%→+20%%." % pct
		CivData.PREMYSLOVCI:
			return "- **Přemyslovci (%.1f%%):** NÁVRH — cavalry damage +10%%→+15%%." % pct
		CivData.HUSITE:
			return "- **Husité (%.1f%%):** NÁVRH — infantry HP civ bonus +5%%." % pct
		CivData.HABSBURKOVE:
			return "- **Habsburkové (%.1f%%):** NÁVRH — Lancknecht +1 melee armor." % pct
		_:
			return "- **%s (%.1f%%):** NÁVRH — +5%% unique damage." % [CivData.civ_name(civ), pct]


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
