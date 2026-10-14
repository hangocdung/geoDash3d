# Debug-only A/B switches (--perf=noglow,nosky,scale=0.5,tier=low,...) used to find GPU bottlenecks on
# devices; results are logged by PerfProbe. See tools/device/perf_matrix.sh.
# Related: src/presentation/level/level_runner.gd, src/core/perf_probe.gd
class_name PerfFlags
extends RefCounted


static func apply(runner: LevelRunner, flags: PackedStringArray) -> void:
	print("PERF flags %s" % ",".join(flags))
	var environment: Environment = runner.environment_director.environment
	for flag: String in flags:
		if flag.begins_with("scale="):
			runner.get_viewport().scaling_3d_scale = flag.trim_prefix("scale=").to_float()
		if flag.begins_with("tier="):
			var tier_name: String = flag.trim_prefix("tier=").to_upper()
			runner.apply_quality(QualityTier.from_int(QualityTier.Tier.keys().find(tier_name)))
		match flag:
			"noglow":
				environment.glow_enabled = false
			"glow1", "glow2":
				for level: int in 7:
					environment.set_glow_level(level, 0.0)
				environment.set_glow_level(1, 1.0)
				if flag == "glow2":
					environment.set_glow_level(2, 0.8)
			"nofog":
				environment.fog_enabled = false
			"nosky":
				environment.background_mode = Environment.BG_COLOR
				environment.background_color = Color(0.05, 0.02, 0.12)
			"noparticles":
				runner.vfx_director.visible = false
				runner.player_view.trail.visible = false
			"noscenery":
				runner.scenery_view.visible = false
				runner.decor_view.visible = false
			"noobstacles":
				runner.obstacle_view.visible = false
			"notrack":
				runner.track_view.visible = false
			"nodetail":
				RenderingServer.global_shader_parameter_set(&"detail_textures", 0.0)
