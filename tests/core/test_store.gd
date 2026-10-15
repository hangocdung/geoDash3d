# In-app purchases: completed purchases grant their entitlements (saved), pending ones do not, unacknowledged ones are
# returned for acknowledging, and remove_ads switches ads off. Related: src/core/store.gd, src/core/entitlements.gd
extends TestCase

const TEST_PATH: String = "user://test_entitlements.cfg"

var _saved_path: String
var _ads_enabled: bool


func before_each() -> void:
	_saved_path = Entitlements.path
	_ads_enabled = Ads.enabled
	Entitlements.path = TEST_PATH
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Entitlements.reset_cache()


func after_each() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	Entitlements.path = _saved_path
	Entitlements.reset_cache()
	Ads.enabled = _ads_enabled


func test_completed_purchase_grants_and_needs_acknowledging() -> void:
	var tokens: PackedStringArray = Store.process_purchases([
		{"product_ids": ["remove_ads"], "purchase_state": Store.PURCHASED, "purchase_token": "t1",
				"is_acknowledged": false},
		{"product_ids": ["unlock_all_songs"], "purchase_state": Store.PURCHASED, "purchase_token": "t2",
				"is_acknowledged": true},
	])
	assert_eq(",".join(tokens), "t1")
	assert_true(Entitlements.has(Entitlements.REMOVE_ADS))
	assert_true(Entitlements.has(Entitlements.UNLOCK_ALL_SONGS))
	assert_false(Ads.enabled, "remove_ads turns ads off")


func test_pending_purchase_grants_nothing() -> void:
	var tokens: PackedStringArray = Store.process_purchases([
		{"product_ids": ["remove_ads"], "purchase_state": 2, "purchase_token": "p", "is_acknowledged": false},
	])
	assert_eq(tokens.size(), 0)
	assert_false(Entitlements.has(Entitlements.REMOVE_ADS))


func test_entitlements_survive_a_restart() -> void:
	assert_true(Entitlements.grant(Entitlements.UNLOCK_ALL_SONGS))
	assert_false(Entitlements.grant(Entitlements.UNLOCK_ALL_SONGS), "already owned")
	Entitlements.reset_cache()
	assert_true(Entitlements.has(Entitlements.UNLOCK_ALL_SONGS), "read back from the file")
	assert_false(Entitlements.has(Entitlements.REMOVE_ADS))


func test_unknown_product_is_ignored() -> void:
	Store.process_purchases([{"product_ids": ["coins_100"], "purchase_state": Store.PURCHASED,
			"purchase_token": "x", "is_acknowledged": true}])
	for entitlement: StringName in Entitlements.ALL:
		assert_false(Entitlements.has(entitlement))
