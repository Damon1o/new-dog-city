extends RefCounted
## Rebindable controls on Godot's InputMap. Saved as "ui/keys" {action: [keycodes]};
## Esc (pause) and 5-9 (long menus) stay fixed so you can always get back to Settings.

const DEFAULTS := {  # action -> [label, default keycodes]
	"move_up": ["Move up", [KEY_W, KEY_UP]], "move_down": ["Move down", [KEY_S, KEY_DOWN]],
	"move_left": ["Move left", [KEY_A, KEY_LEFT]], "move_right": ["Move right", [KEY_D, KEY_RIGHT]],
	"sprint": ["Sprint", [KEY_SHIFT]], "bite": ["Bite  (hold: pounce)", [KEY_SPACE]],
	"dash": ["Dash", [KEY_C]], "bark": ["Bark", [KEY_R]], "interact": ["Interact", [KEY_F]],
	"inventory": ["Inventory", [KEY_I]], "map": ["Map", [KEY_M]], "breed": ["Change breed", [KEY_TAB]],
	"wardrobe": ["Wardrobe", [KEY_B]],
	"purina": ["Eat Purina", [KEY_Q]], "water": ["Drink water", [KEY_E]], "pee": ["Pee  (hold)", [KEY_G]],
	"hot_1": ["Hotbar 1 / choice 1", [KEY_1]], "hot_2": ["Hotbar 2 / choice 2", [KEY_2]],
	"hot_3": ["Hotbar 3 / choice 3", [KEY_3]], "hot_4": ["Hotbar 4 / choice 4", [KEY_4]],
}

## Register every action; `saved` overrides the defaults per action.
static func apply(saved: Dictionary) -> void:
	for a: String in DEFAULTS:
		set_keys(a, saved.get(a, DEFAULTS[a][1]))

static func set_keys(a: String, keys: Array) -> void:
	if not InputMap.has_action(a):
		InputMap.add_action(a)
	InputMap.action_erase_events(a)
	for k in keys:
		var ev := InputEventKey.new()
		ev.keycode = int(k) as Key
		InputMap.action_add_event(a, ev)

static func keys_of(a: String) -> Array:
	return InputMap.action_get_events(a).map(func(e): return int(e.keycode))

## Rebinding drops the key from any other action, so one key never does two things.
static func rebind(a: String, keycode: int) -> void:
	for other: String in DEFAULTS:
		if other != a and keycode in keys_of(other):
			set_keys(other, keys_of(other).filter(func(k): return k != keycode))
	set_keys(a, [keycode])

static func reset() -> void:
	apply({})

static func to_save() -> Dictionary:
	var d := {}
	for a: String in DEFAULTS:
		d[a] = keys_of(a)
	return d

static func label(a: String) -> String:
	var names: Array = keys_of(a).map(func(k): return OS.get_keycode_string(k))
	return " / ".join(names) if names else "unbound"

## The action a key event triggers ("" = none).
static func action_of(event: InputEvent) -> String:
	for a: String in DEFAULTS:
		if event.is_action(a) and a != "sprint":  # not exact: Shift + 1 still means hot_1 (buy x5)
			return a
	return ""
