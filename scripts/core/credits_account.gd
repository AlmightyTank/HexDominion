extends RefCounted
class_name CreditsAccount
## Shared, synchronous money authority for every faction. Never debit via UI checks.
const DEFAULT_STARTING_FUNDS: float = 400.0
const MAX_CREDITS: float = 1.0e15
var _balance: float = 0.0
var _starting_funds: float = 0.0
var _history: Array[Dictionary] = []
var balance: float:
	get:
		return _balance
var starting_funds: float:
	get:
		return _starting_funds

func _init(funds: float = DEFAULT_STARTING_FUNDS) -> void:
	_starting_funds = funds if _valid_amount(funds) else 0.0
	_balance = _starting_funds
	_record("starting_funds", 0.0, "Starting funds")

static func _valid_amount(amount: Variant) -> bool:
	return (amount is int or amount is float) and is_finite(float(amount)) and amount >= 0.0 and amount <= MAX_CREDITS

func can_afford(amount: float) -> bool:
	return _valid_amount(amount) and _balance >= amount

func try_spend(amount: float, reason: String = "Purchase") -> bool:
	if not can_afford(amount):
		return false
	if amount == 0.0:
		return true
	var before: float = _balance
	_balance -= amount
	_record("spend", before, reason)
	return true

func add_income(amount: float, reason: String = "Income") -> bool:
	if not _valid_amount(amount) or amount > MAX_CREDITS - _balance:
		return false
	if amount == 0.0:
		return true
	var before: float = _balance
	_balance += amount
	_record("income", before, reason)
	return true

func set_balance(amount: float, reason: String = "Balance adjustment") -> bool:
	# Compatibility/setup entry point; invalid direct credit assignments are ignored.
	if not _valid_amount(amount):
		return false
	if amount == _balance:
		return true
	var before: float = _balance
	_balance = amount
	_record("adjustment", before, reason)
	return true

func _record(type: String, before: float, reason: String) -> void:
	# Continuous passive income is one ledger entry until another transaction occurs.
	# This keeps full history without producing 60 rows per second per faction.
	if type == "income" and not _history.is_empty() and _history[-1]["type"] == type and _history[-1]["reason"] == reason:
		_history[-1]["balance"] = _balance
		_history[-1]["amount"] = _balance - _history[-1]["before"]
		return
	_history.append({"id": _history.size() + 1, "type": type, "reason": reason,
		"before": before, "amount": _balance - before, "balance": _balance})

func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)

func snapshot() -> Dictionary:
	return {"starting_funds": _starting_funds, "balance": _balance, "history": get_history()}

static func valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or not _valid_amount(data.get("starting_funds")) or not _valid_amount(data.get("balance")) or not data.get("history") is Array or data["history"].is_empty():
		return false
	var previous: float = 0.0
	for index in range(data["history"].size()):
		var entry: Variant = data["history"][index]
		if not entry is Dictionary or entry.get("id") != index + 1 or not entry.get("reason") is String:
			return false
		if not _valid_amount(entry.get("before")) or not _valid_amount(entry.get("balance")) or not (entry.get("amount") is float or entry.get("amount") is int):
			return false
		var amount: float = entry["amount"]
		if not is_finite(amount) or entry["before"] != previous or not is_equal_approx(entry["balance"] - entry["before"], amount):
			return false
		if index == 0:
			if entry.get("type") != "starting_funds" or entry["balance"] != data["starting_funds"]:
				return false
		elif entry.get("type") not in ["income", "spend", "adjustment"]:
			return false
		elif (entry["type"] == "income" and amount < 0) or (entry["type"] == "spend" and amount > 0):
			return false
		previous = entry["balance"]
	return previous == data["balance"]

func restore(data: Dictionary) -> bool:
	if not valid_snapshot(data):
		return false
	_balance = data["balance"]
	_starting_funds = data["starting_funds"]
	_history.assign(data["history"].duplicate(true))
	return true
