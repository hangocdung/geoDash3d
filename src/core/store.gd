# In-app purchases through the official Godot Google Play Billing plugin (GD3-241), Android only. Connects at startup,
# loads prices and the player's purchases (which also restores them on a new install), grants entitlements for
# completed purchases and acknowledges them (Play refunds purchases left unacknowledged for 3 days). Pending purchases
# wait for the next update. Purchases are verified by the Play Store only (no server check yet).
# Related: src/core/entitlements.gd, src/ui/menu/shop_panel.gd, addons/GodotGooglePlayBilling, docs/release/iap_setup.md
class_name Store
extends RefCounted

## Play Console product ID → entitlements it grants (one-time, non-consumable products).
const PRODUCTS: Dictionary[String, Array] = {
	"remove_ads": [Entitlements.REMOVE_ADS],
	"unlock_all_songs": [Entitlements.UNLOCK_ALL_SONGS],
}
const PURCHASED: int = 1

## Called after prices, purchases or the connection change (the shop refreshes).
static var on_changed: Callable
static var _client: BillingClient
static var _prices: Dictionary[String, String] = {}
static var _status: String = ""


static func is_supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("GodotGooglePlayBilling")


## Once at startup (main menu). The client node lives under the tree root so it survives scene changes.
static func start(tree: SceneTree) -> void:
	if _client != null or not is_supported():
		return
	_client = BillingClient.new()
	_client.name = "BillingClient"
	tree.root.add_child.call_deferred(_client)
	_client.connected.connect(_on_connected)
	_client.connect_error.connect(func(code: int, message: String) -> void:
		_set_status("Store unavailable")
		push_warning("Store: connection error %d %s" % [code, message]))
	_client.query_product_details_response.connect(_on_product_details)
	_client.query_purchases_response.connect(_on_purchases_response)
	_client.on_purchase_updated.connect(_on_purchases_response)
	_client.acknowledge_purchase_response.connect(func(response: Dictionary) -> void:
		if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
			push_warning("Store: acknowledge failed %s" % str(response)))
	_client.start_connection()


static func is_ready() -> bool:
	return _client != null and _client.is_ready()


## Localized price ("" until known).
static func price(product_id: String) -> String:
	return _prices.get(product_id, "")


## Last problem to show in the shop, an English UI key ("" when fine).
static func status() -> String:
	return _status


static func buy(product_id: String) -> void:
	if not is_ready() or not _prices.has(product_id):
		_set_status("Store not ready")
		return
	Telemetry.log_event("iap_click", {"product_id": product_id})
	var result: Dictionary = _client.purchase(product_id)
	if int(result.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		_set_status("Purchase failed")
		push_warning("Store: purchase flow failed %s" % str(result))


## RESTORE PURCHASES: asks Play for the player's purchases again.
static func restore() -> void:
	if is_ready():
		_client.query_purchases(BillingClient.ProductType.INAPP)


## Grants the entitlements of completed purchases; returns the tokens that still need acknowledging.
## Pure apart from Entitlements (tests feed it Play-shaped dictionaries).
static func process_purchases(purchases: Array) -> PackedStringArray:
	var to_acknowledge: PackedStringArray = []
	for entry: Variant in purchases:
		var purchase: Dictionary = entry
		if int(purchase.get("purchase_state", 0)) != PURCHASED:
			continue
		for product_id: Variant in purchase.get("product_ids", []):
			for entitlement: StringName in PRODUCTS.get(str(product_id), []):
				Entitlements.grant(entitlement)
		if not bool(purchase.get("is_acknowledged", false)):
			to_acknowledge.append(str(purchase.get("purchase_token", "")))
	return to_acknowledge


static func _on_connected() -> void:
	_set_status("")
	_client.query_product_details(PackedStringArray(PRODUCTS.keys()), BillingClient.ProductType.INAPP)
	_client.query_purchases(BillingClient.ProductType.INAPP)


static func _on_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != BillingClient.BillingResponseCode.OK:
		_set_status("Prices unavailable")
		return
	for entry: Variant in response.get("product_details", []):
		var details: Dictionary = entry
		var offers: Variant = details.get("one_time_purchase_offer_details_list")
		if offers is Array and not (offers as Array).is_empty():
			var offer: Dictionary = (offers as Array)[0]
			_prices[str(details.get("product_id", ""))] = str(offer.get("formatted_price", ""))
	_notify()


static func _on_purchases_response(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -1))
	if code == BillingClient.BillingResponseCode.USER_CANCELED:
		return
	if code != BillingClient.BillingResponseCode.OK:
		_set_status("Store error")
		push_warning("Store: purchases response %s" % str(response))
		return
	for token: String in process_purchases(response.get("purchases", [])):
		if not token.is_empty():
			_client.acknowledge_purchase(token)
	_notify()


static func _set_status(text: String) -> void:
	_status = text
	_notify()


static func _notify() -> void:
	if on_changed.is_valid():
		on_changed.call()
