# Shop (GD3-241): one card per product (icon, name, what it gives, Play price as BUY or OWNED), RESTORE PURCHASES and
# the store's last problem; refreshes when Store reports changes. Off Android it only says the store is not available.
# Cards sit side by side in landscape and stack in portrait.
# Related: src/core/store.gd, src/core/entitlements.gd, src/ui/menu/main_menu.gd
class_name ShopPanel
extends UiScreen

const PRODUCTS: Dictionary[String, Dictionary] = {
	"remove_ads": {"name": "REMOVE ADS", "icon": &"no_ads",
			"text": "No more banners or ads between runs. Ad trials of locked songs stay available."},
	"unlock_all_songs": {"name": "UNLOCK ALL SONGS", "icon": &"unlock",
			"text": "Every song open right away, no clears needed."},
}
const CARD_WIDTH: float = 560.0

var _cards: BoxContainer
var _status: Label


func _title() -> String:
	return "SHOP"


func _subtitle() -> String:
	return "SUPPORT THE GAME, PLAY YOUR WAY"


func _icon() -> StringName:
	return &"cart"


func _build_body() -> void:
	Telemetry.log_event("shop_view")
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 26)
	center.add_child(column)
	_cards = BoxContainer.new()
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards.add_theme_constant_override("separation", 32)
	column.add_child(_cards)
	_status = UiKit.label("", "", HORIZONTAL_ALIGNMENT_CENTER)
	_status.add_theme_font_size_override("font_size", 24)
	_status.add_theme_color_override("font_color", UiTheme.HOT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_status)
	var restore: Button = UiKit.button("RESTORE PURCHASES", &"restore", "", false, Vector2(460, 64))
	restore.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restore.pressed.connect(Store.restore)
	restore.disabled = not Store.is_supported()
	column.add_child(restore)
	Store.on_changed = _refresh
	_refresh()


func _layout(is_portrait: bool) -> void:
	_cards.vertical = is_portrait


func _exit_tree() -> void:
	Store.on_changed = Callable()


func _refresh() -> void:
	for child: Node in _cards.get_children():
		child.queue_free()
	for product_id: String in Store.PRODUCTS:
		_cards.add_child(_card(product_id))
	if not Store.is_supported():
		_status.text = Locale.t("The store is only available in the Google Play version.")
	else:
		_status.text = Locale.t(Store.status()) if not Store.status().is_empty() else ""


func _card(product_id: String) -> PanelContainer:
	var info: Dictionary = PRODUCTS.get(product_id, {"name": product_id, "icon": &"cart", "text": ""})
	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)
	column.add_child(UiKit.icon_rect(info["icon"], 96, UiTheme.HOT))
	var name_label: Label = UiKit.label(info["name"], "SectionTitle", HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(name_label)
	var text: Label = UiKit.label(info["text"], "Muted", HORIZONTAL_ALIGNMENT_CENTER)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(CARD_WIDTH - 80.0, 96)
	column.add_child(text)
	column.add_child(_buy_button(product_id))
	return card


func _buy_button(product_id: String) -> Button:
	var owned: bool = Store.PRODUCTS[product_id].all(func(entitlement: StringName) -> bool:
		return Entitlements.has(entitlement))
	var price: String = Store.price(product_id)
	var text: String = Locale.t("OWNED") if owned else (Locale.t("BUY %s") % price if not price.is_empty() else "…")
	var button: Button = UiKit.button(text, &"check" if owned else &"cart", "PrimaryButton", false, Vector2(0, 68),
			&"ui.confirm")
	button.disabled = owned or price.is_empty()
	button.pressed.connect(Store.buy.bind(product_id))
	return button
