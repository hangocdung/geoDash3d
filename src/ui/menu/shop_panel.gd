# Shop (GD3-241): one row per product (name, Play price, BUY or OWNED), RESTORE PURCHASES and the store's last
# problem; refreshes when Store reports changes. Off Android it only says the store is not available.
# Related: src/core/store.gd, src/core/entitlements.gd, src/ui/menu/main_menu.gd
class_name ShopPanel
extends PanelContainer

signal closed

const PRODUCT_NAMES: Dictionary[String, String] = {
	"remove_ads": "REMOVE ADS",
	"unlock_all_songs": "UNLOCK ALL SONGS",
}

var _rows: VBoxContainer
var _status: Label


func _ready() -> void:
	Telemetry.log_event("shop_view")
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 22)
	add_child(column)
	column.add_child(UiTheme.make_label("SHOP", 48, UiTheme.ACCENT))
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 14)
	column.add_child(_rows)
	_status = UiTheme.make_label("", 24, UiTheme.HOT)
	column.add_child(_status)
	var restore: Button = UiTheme.make_button("RESTORE PURCHASES", 420.0, 64.0)
	restore.pressed.connect(Store.restore)
	restore.disabled = not Store.is_supported()
	column.add_child(restore)
	var back: Button = UiTheme.make_button("BACK", 300.0, 72.0, &"ui.back")
	back.pressed.connect(func() -> void: closed.emit())
	column.add_child(back)
	back.grab_focus()
	Store.on_changed = _refresh
	_refresh()


func _exit_tree() -> void:
	Store.on_changed = Callable()


func _refresh() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	for product_id: String in Store.PRODUCTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 24)
		var label: Label = UiTheme.make_label(PRODUCT_NAMES.get(product_id, product_id), 30)
		label.custom_minimum_size = Vector2(380, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(label)
		row.add_child(_buy_button(product_id))
		_rows.add_child(row)
	if not Store.is_supported():
		_status.text = Locale.t("The store is only available in the Google Play version.")
	else:
		_status.text = Locale.t(Store.status()) if not Store.status().is_empty() else ""


func _buy_button(product_id: String) -> Button:
	var owned: bool = Store.PRODUCTS[product_id].all(func(entitlement: StringName) -> bool:
		return Entitlements.has(entitlement))
	var price: String = Store.price(product_id)
	var text: String = Locale.t("OWNED") if owned else (Locale.t("BUY %s") % price if not price.is_empty() else "…")
	var button: Button = UiTheme.make_button(text, 240.0, 64.0, &"ui.confirm")
	button.disabled = owned or price.is_empty()
	button.pressed.connect(Store.buy.bind(product_id))
	return button
