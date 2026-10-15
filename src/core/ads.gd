# AdMob through the Poing Studios plugin (GD3-240), Android only (no-op elsewhere and in tests). Startup asks for
# consent with Google UMP, then initializes the SDK (teen content rating, not child-directed: GD3-203) and preloads an
# interstitial. Interstitials only between runs, when the player is back in the main menu after at least
# RemoteSettings ads_interstitial_gap_sec (180 s) of play; never after a death retry (the game restarts by itself) and never during
# a run. The banner lives in the main menu only. Rewarded ads (song trials, GD3-242) load when the song list shows a
# locked song and play only when the player asks; they stay available after remove_ads. Ad unit IDs: project settings geodash/ads/*_unit (release builds);
# debug builds always use Google's test units.
# Related: src/ui/menu/main_menu.gd, src/presentation/level/run_telemetry.gd (play time), docs/release/admob_setup.md
class_name Ads
extends RefCounted

enum State { OFF, STARTING, READY }

const UNIT_SETTING: String = "geodash/ads/%s_unit"
## Google's public test units (Android).
const TEST_UNITS: Dictionary[String, String] = {
	"interstitial": "ca-app-pub-3940256099942544/1033173712",
	"banner": "ca-app-pub-3940256099942544/6300978111",
	"rewarded": "ca-app-pub-3940256099942544/5224354917",
}

## False after the remove_ads purchase (GD3-241): no interstitials, no banner.
static var enabled: bool = true
## Called with true when a full-screen ad opens and false when it closes (the menu pauses its music).
static var on_fullscreen: Callable
static var _state: State = State.OFF
static var _play_since_interstitial: float = 0.0
static var _interstitial: InterstitialAd
static var _loading_interstitial: bool = false
static var _banner: AdView
static var _rewarded: RewardedAd
static var _loading_rewarded: bool = false
static var _earned_reward: bool = false
static var _on_reward: Callable
static var _banner_wanted: bool = false


static func is_supported() -> bool:
	return OS.get_name() == "Android"


## Once at startup (main menu): consent first, then the SDK.
static func start() -> void:
	if _state != State.OFF or not is_supported():
		return
	_state = State.STARTING
	UserMessagingPlatform.consent_information.update(ConsentRequestParameters.new(), _on_consent_info_updated,
			func(error: FormError) -> void:
				_warn_form_error(error)
				_initialize())


## Seconds of real play (RunTelemetry, normal and practice runs) toward the next interstitial.
static func note_play_time(seconds: float) -> void:
	_play_since_interstitial += maxf(seconds, 0.0)


## The main menu after a run: shows a preloaded interstitial when enough play has passed. True when shown.
static func maybe_show_interstitial() -> bool:
	if not enabled or _state != State.READY or _interstitial == null:
		return false
	if _play_since_interstitial < RemoteSettings.get_float("ads_interstitial_gap_sec"):
		return false
	_play_since_interstitial = 0.0
	Telemetry.log_event("ad_shown", {"format": "interstitial", "placement": "menu_return"})
	_interstitial.show()
	return true


static func show_banner() -> void:
	_banner_wanted = true
	if not enabled or _state != State.READY or _banner != null:
		return
	var size: AdSize = AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)
	_banner = AdView.new(_unit("banner"), size, AdPosition.BOTTOM)
	_banner.load_ad(AdRequest.new())


static func hide_banner() -> void:
	_banner_wanted = false
	if _banner != null:
		_banner.destroy()
		_banner = null


## Screen pixels the bottom banner takes (0 without one): menu pages keep their buttons above it.
static func banner_height_pixels() -> int:
	return _banner.get_height_in_pixels() if _banner != null else 0


## Starts loading a rewarded ad if none is ready (the song list calls it when it shows a locked song).
static func preload_rewarded() -> void:
	if _state != State.READY or _loading_rewarded or _rewarded != null:
		return
	_loading_rewarded = true
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading_rewarded = false
		_rewarded = ad
		var content := FullScreenContentCallback.new()
		content.on_ad_showed_full_screen_content = func() -> void: _notify_fullscreen(true)
		content.on_ad_dismissed_full_screen_content = func() -> void: _rewarded_closed()
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: _rewarded_closed()
		ad.full_screen_content_callback = content
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading_rewarded = false
		push_warning("Ads: rewarded failed to load (%d %s)" % [error.code, error.message])
	RewardedAdLoader.new().load(_unit("rewarded"), AdRequest.new(), callback)


static func rewarded_ready() -> bool:
	return _rewarded != null


## Shows the rewarded ad; `on_reward` runs after it closes, only if the player earned the reward.
static func show_rewarded(placement: String, on_reward: Callable) -> bool:
	if _rewarded == null:
		return false
	_earned_reward = false
	_on_reward = on_reward
	Telemetry.log_event("ad_shown", {"format": "rewarded", "placement": placement})
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void: _earned_reward = true
	_rewarded.show(listener)
	return true


## True when the player must be able to reopen the consent form (EEA/UK): Settings shows a button.
static func privacy_options_required() -> bool:
	return _state != State.OFF and UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
			== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


static func show_privacy_options() -> void:
	if is_supported():
		UserMessagingPlatform.show_privacy_options_form(_warn_form_error)


static func _on_consent_info_updated() -> void:
	if not UserMessagingPlatform.consent_information.get_is_consent_form_available():
		_initialize()
		return
	UserMessagingPlatform.load_consent_form(func(form: ConsentForm) -> void:
		if UserMessagingPlatform.consent_information.get_consent_status() \
				== ConsentInformation.ConsentStatus.REQUIRED:
			form.show(func(_error: FormError) -> void: _initialize())
		else:
			_initialize(),
		func(_error: FormError) -> void: _initialize())


static func _initialize() -> void:
	if _state == State.READY:
		return
	var configuration := RequestConfiguration.new()
	configuration.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T
	configuration.tag_for_child_directed_treatment = RequestConfiguration.TagForChildDirectedTreatment.FALSE
	MobileAds.set_request_configuration(configuration)
	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = func(_status: InitializationStatus) -> void:
		_state = State.READY
		_load_interstitial()
		if _banner_wanted:
			show_banner()
	MobileAds.initialize(listener)


static func _load_interstitial() -> void:
	if not enabled or _loading_interstitial or _interstitial != null:
		return
	_loading_interstitial = true
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_loading_interstitial = false
		_interstitial = ad
		var content := FullScreenContentCallback.new()
		content.on_ad_showed_full_screen_content = func() -> void: _notify_fullscreen(true)
		content.on_ad_dismissed_full_screen_content = func() -> void: _interstitial_closed()
		content.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void: _interstitial_closed()
		ad.full_screen_content_callback = content
	callback.on_ad_failed_to_load = func(error: LoadAdError) -> void:
		_loading_interstitial = false
		push_warning("Ads: interstitial failed to load (%d %s)" % [error.code, error.message])
	InterstitialAdLoader.new().load(_unit("interstitial"), AdRequest.new(), callback)


static func _interstitial_closed() -> void:
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	_notify_fullscreen(false)
	_load_interstitial()


static func _rewarded_closed() -> void:
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null
	_notify_fullscreen(false)
	var reward: Callable = _on_reward
	_on_reward = Callable()
	if _earned_reward and reward.is_valid():
		reward.call()
	_earned_reward = false
	preload_rewarded()


static func _notify_fullscreen(shown: bool) -> void:
	if on_fullscreen.is_valid():
		on_fullscreen.call(shown)


static func _warn_form_error(error: FormError) -> void:
	if error != null:
		push_warning("Ads: consent form error %d %s" % [error.error_code, error.message])


## Test units in debug builds; the configured unit in release (no ads, with an error, when it is missing).
static func _unit(format: String) -> String:
	if OS.is_debug_build():
		return TEST_UNITS[format]
	var unit: String = str(ProjectSettings.get_setting(UNIT_SETTING % format, ""))
	if unit.is_empty():
		push_error("Ads: project setting %s is empty, no %s ads" % [UNIT_SETTING % format, format])
	return unit
