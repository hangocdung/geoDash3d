// Godot plugin singleton "GeoDashFirebase": Analytics events and user properties, Crashlytics logs, non-fatal errors
// and custom keys, Remote Config fetch. Every call is a no-op when the app has no Firebase config
// (google-services.json missing at build time), so the game behaves the same with or without it.
// Related: src/core/telemetry.gd, src/core/remote_settings.gd, addons/geodash_firebase/export_plugin.gd
package com.dunghn.geodash.firebase;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;

import androidx.annotation.NonNull;

import com.google.firebase.FirebaseApp;
import com.google.firebase.analytics.FirebaseAnalytics;
import com.google.firebase.crashlytics.FirebaseCrashlytics;
import com.google.firebase.remoteconfig.FirebaseRemoteConfig;
import com.google.firebase.remoteconfig.FirebaseRemoteConfigValue;

import org.godotengine.godot.Dictionary;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.SignalInfo;
import org.godotengine.godot.plugin.UsedByGodot;
import org.json.JSONObject;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Set;

public class GeoDashFirebase extends GodotPlugin {
    private static final String TAG = "GeoDashFirebase";
    private static final SignalInfo REMOTE_CONFIG_UPDATED = new SignalInfo("remote_config_updated", Boolean.class);
    private static final SignalInfo APP_INSTANCE_ID = new SignalInfo("app_instance_id_ready", String.class);

    private boolean ready = false;
    private FirebaseAnalytics analytics;
    private FirebaseCrashlytics crashlytics;
    private FirebaseRemoteConfig remoteConfig;
    private String appInstanceId = "";

    public GeoDashFirebase(Godot godot) {
        super(godot);
        Activity activity = getActivity();
        if (activity == null) {
            Log.e(TAG, "no activity, Firebase disabled");
            return;
        }
        if (FirebaseApp.getApps(activity).isEmpty() && FirebaseApp.initializeApp(activity) == null) {
            Log.w(TAG, "no Firebase config in this build (google-services.json), telemetry stays local");
            return;
        }
        analytics = FirebaseAnalytics.getInstance(activity);
        crashlytics = FirebaseCrashlytics.getInstance();
        remoteConfig = FirebaseRemoteConfig.getInstance();
        ready = true;
        analytics.getAppInstanceId().addOnCompleteListener(task -> {
            if (task.isSuccessful() && task.getResult() != null) {
                appInstanceId = task.getResult();
                emitSignal(APP_INSTANCE_ID.getName(), appInstanceId);
            }
        });
    }

    @NonNull
    @Override
    public String getPluginName() {
        return "GeoDashFirebase";
    }

    @NonNull
    @Override
    public Set<SignalInfo> getPluginSignals() {
        Set<SignalInfo> signals = new HashSet<>();
        signals.add(REMOTE_CONFIG_UPDATED);
        signals.add(APP_INSTANCE_ID);
        return signals;
    }

    /** True when Firebase is configured and running in this build. */
    @UsedByGodot
    public boolean is_ready() {
        return ready;
    }

    /** Ints, floats, bools and strings; bools are sent as 0/1 (Analytics has no boolean type). */
    @UsedByGodot
    public void log_event(String name, Dictionary params) {
        if (!ready) {
            return;
        }
        Bundle bundle = new Bundle();
        for (Map.Entry<String, Object> entry : params.entrySet()) {
            Object value = entry.getValue();
            if (value instanceof Boolean) {
                bundle.putLong(entry.getKey(), ((Boolean) value) ? 1L : 0L);
            } else if (value instanceof Integer || value instanceof Long) {
                bundle.putLong(entry.getKey(), ((Number) value).longValue());
            } else if (value instanceof Number) {
                bundle.putDouble(entry.getKey(), ((Number) value).doubleValue());
            } else if (value != null) {
                bundle.putString(entry.getKey(), value.toString());
            }
        }
        analytics.logEvent(name, bundle);
    }

    @UsedByGodot
    public void set_user_property(String name, String value) {
        if (ready) {
            analytics.setUserProperty(name, value);
        }
    }

    /** Analytics + Crashlytics collection (consent, GD3-240). */
    @UsedByGodot
    public void set_collection_enabled(boolean enabled) {
        if (ready) {
            analytics.setAnalyticsCollectionEnabled(enabled);
            crashlytics.setCrashlyticsCollectionEnabled(enabled);
        }
    }

    /** Breadcrumb shown with the next crash or non-fatal report. */
    @UsedByGodot
    public void crash_log(String message) {
        if (ready) {
            crashlytics.log(message);
        }
    }

    @UsedByGodot
    public void set_custom_key(String key, String value) {
        if (ready) {
            crashlytics.setCustomKey(key, value);
        }
    }

    /** A script error (push_error) as a Crashlytics non-fatal issue, grouped by its message. */
    @UsedByGodot
    public void record_error(String message) {
        if (ready) {
            crashlytics.recordException(new GodotScriptError(message));
        }
    }

    /** Sets the in-app defaults (key -> value as text), then fetches and activates; emits remote_config_updated. */
    @UsedByGodot
    public void fetch_remote_config(Dictionary defaults) {
        if (!ready) {
            return;
        }
        Map<String, Object> values = new HashMap<>();
        for (Map.Entry<String, Object> entry : defaults.entrySet()) {
            values.put(entry.getKey(), String.valueOf(entry.getValue()));
        }
        remoteConfig.setDefaultsAsync(values).addOnCompleteListener(defaultsTask ->
                remoteConfig.fetchAndActivate().addOnCompleteListener(task ->
                        emitSignal(REMOTE_CONFIG_UPDATED.getName(), task.isSuccessful())));
    }

    /** Active Remote Config values as a JSON object of strings (the game converts them using its defaults' types). */
    @UsedByGodot
    public String remote_config_json() {
        if (!ready) {
            return "{}";
        }
        JSONObject result = new JSONObject();
        try {
            for (Map.Entry<String, FirebaseRemoteConfigValue> entry : remoteConfig.getAll().entrySet()) {
                result.put(entry.getKey(), entry.getValue().asString());
            }
        } catch (org.json.JSONException error) {
            Log.e(TAG, "remote_config_json", error);
        }
        return result.toString();
    }

    @UsedByGodot
    public String get_app_instance_id() {
        return appInstanceId;
    }

    /** Test hook: a real native-side crash, to check Crashlytics end to end (debug menu only). */
    @UsedByGodot
    public void test_crash() {
        throw new RuntimeException("GeoDashFirebase test crash");
    }

    private static final class GodotScriptError extends Exception {
        GodotScriptError(String message) {
            super(message);
        }
    }
}
