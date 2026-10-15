# Line icons for buttons, rows and headers: small SVG strings (24×24 grid, round strokes) rendered at runtime to
# the requested pixel size and colour, cached. No imported image files, so they stay crisp at every UI scale.
# Related: src/ui/theme/ui_theme.gd, src/ui/theme/ui_kit.gd
class_name UiIcons
extends RefCounted

const VIEW_SIZE: float = 24.0
const STROKE: float = 2.0
## Path data per icon. "F:" marks a filled shape, everything else is stroked; "|" separates elements.
const SHAPES: Dictionary[StringName, String] = {
	&"play": "F:M7 4.5v15l12.5-7.5z",
	&"target": "C12,12,9|C12,12,5|F:C12,12,1.6",
	&"headphones": "M4 15v-3a8 8 0 0 1 16 0v3|M4 15h3v5H5a1 1 0 0 1-1-1z|M20 15h-3v5h2a1 1 0 0 0 1-1z",
	&"wave": "M2 12h3l2-5 3 11 3-14 3 10 2-4h4",
	&"gear": "M19.2 10.2L21.9 10.4L21.9 13.6L19.2 13.8L18.3 15.8L20.1 17.9L17.9 20.1L15.8 18.3L13.8 19.2L13.6 21.9L10.4 21.9L10.2 19.2L8.2 18.3L6.1 20.1L3.9 17.9L5.7 15.8L4.8 13.8L2.1 13.6L2.1 10.4L4.8 10.2L5.7 8.2L3.9 6.1L6.1 3.9L8.2 5.7L10.2 4.8L10.4 2.1L13.6 2.1L13.8 4.8L15.8 5.7L17.9 3.9L20.1 6.1L18.3 8.2z|C12,12,3.2",
	&"cart": "M2 3h3l2.6 12.2a1.5 1.5 0 0 0 1.5 1.2h8.6a1.5 1.5 0 0 0 1.5-1.1L21 8H6|C9.5,20.5,1.3|C17.5,20.5,1.3",
	&"record": "C12,12,9|F:C12,12,4.5",
	&"power": "M12 2.5v9|M6.3 6.3a8 8 0 1 0 11.4 0",
	&"back": "M19 12H5|M11 5l-7 7 7 7",
	&"chevron": "M9 5l7 7-7 7",
	&"chevron_down": "M5 9l7 7 7-7",
	&"music": "M9 18V5l11-2v13|C6.5,18,2.5|C17.5,16,2.5",
	&"star": "F:M12 2.8l2.8 5.9 6.4.8-4.7 4.4 1.2 6.3L12 17.1l-5.7 3.1 1.2-6.3-4.7-4.4 6.4-.8z",
	&"lock": "M5 11h14v10H5z|M8 11V7.5a4 4 0 0 1 8 0V11|F:C12,16,1.4",
	&"unlock": "M5 11h14v10H5z|M8 11V7.5a4 4 0 0 1 7.6-1.7|F:C12,16,1.4",
	&"ad": "M3 5h18v12H3z|M8 21h8|M7.5 14l2-6 2 6|M8.2 12h2.6|M14 8v6h1.5a3 3 0 0 0 0-6z",
	&"no_ads": "M3 5h18v12H3z|M8 21h8|M4 4l16 16",
	&"restore": "M3 12a9 9 0 1 0 2.6-6.4|M3 3v5h5",
	&"pause": "F:M6 4h4v16H6z|F:M14 4h4v16h-4z",
	&"restart": "M20 12a8 8 0 1 1-2.3-5.7|M20 4v5h-5",
	&"home": "M3 11l9-8 9 8|M5 9.5V21h5v-6h4v6h5V9.5",
	&"next": "F:M5 5v14l9-7z|M18 5v14",
	&"sliders": "M4 6h10|M18 6h2|C16,6,2|M4 12h4|M12 12h8|C10,12,2|M4 18h12|M20 18h0|C18,18,2",
	&"speaker": "F:M3 9h4l5-4v14l-5-4H3z|M16 8.5a5 5 0 0 1 0 7|M18.8 6a8.5 8.5 0 0 1 0 12",
	&"eye": "M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z|C12,12,3",
	&"vibrate": "M8 3h8v18H8z|M11 18h2|M4 8v8|M20 8v8",
	&"bars": "F:M4 14h3v6H4z|F:M10.5 9h3v11h-3z|F:M17 4h3v16h-3z",
	&"globe": "C12,12,9.5|M2.5 12h19|M12 2.5c3 3 3 16 0 19|M12 2.5c-3 3-3 16 0 19",
	&"info": "C12,12,9.5|M12 11v6|F:C12,7.5,1.2",
	&"link": "M10 14a4.5 4.5 0 0 0 6.4 0l3-3a4.5 4.5 0 0 0-6.4-6.4l-1 1|M14 10a4.5 4.5 0 0 0-6.4 0l-3 3a4.5 4.5 0 0 0 6.4 6.4l1-1",
	&"gamepad": "M7 7h10a5 5 0 0 1 4.8 6.4l-1 3.4a2.5 2.5 0 0 1-4.3.9L14 15h-4l-2.5 2.7a2.5 2.5 0 0 1-4.3-.9l-1-3.4A5 5 0 0 1 7 7z|M8 10v3|M6.5 11.5h3|F:C16,10.5,1|F:C18,12.5,1",
	&"monitor": "M3 4h18v12H3z|M8 20h8|M12 16v4",
	&"shield": "M12 2.5l8 3v6c0 5-3.4 8.6-8 10-4.6-1.4-8-5-8-10v-6z",
	&"check": "M4 12.5l5 5L20 6.5",
	&"gauge": "M4 17a8 8 0 1 1 16 0|M12 17l4-5|F:C12,17,1.4",
	&"privacy": "M12 2.5l8 3v6c0 5-3.4 8.6-8 10-4.6-1.4-8-5-8-10v-6z|M8.5 12l2.5 2.5 4.5-5",
	&"heart": "M12 20s-8-4.8-8-10.5A4.5 4.5 0 0 1 12 6.6a4.5 4.5 0 0 1 8 2.9C20 15.2 12 20 12 20z",
	&"trophy": "M7 3h10v6a5 5 0 0 1-10 0z|M7 5H3.5v1.5A3.5 3.5 0 0 0 7 10|M17 5h3.5v1.5A3.5 3.5 0 0 1 17 10|M12 14v4|M8 21h8|M9 18h6",
	&"speed": "M4 17a8 8 0 1 1 16 0|M12 17l-3-6|F:C12,17,1.4|M7 7.5l1 1|M17 7.5l-1 1",
}

static var _cache: Dictionary[String, Texture2D] = {}


## `name` drawn `pixel_size` pixels square in `color`.
static func get_icon(name: StringName, pixel_size: int, color: Color = Color.WHITE) -> Texture2D:
	if not SHAPES.has(name):
		push_error("UiIcons: unknown icon '%s'" % name)
		return null
	return _render(_svg(SHAPES[name], color), float(pixel_size) / VIEW_SIZE,
			"%s:%d:%s" % [name, pixel_size, color.to_html()])


## Slider grabber: a filled circle with a soft ring in `ring`.
static func knob(pixel_size: int, color: Color, ring: Color) -> Texture2D:
	var svg: String = ('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
			+ '<circle cx="12" cy="12" r="11" fill="#%s" fill-opacity="0.35"/>' % ring.to_html(false)
			+ '<circle cx="12" cy="12" r="7.5" fill="#%s"/></svg>' % color.to_html(false))
	return _render(svg, float(pixel_size) / VIEW_SIZE, "knob:%d:%s:%s" % [pixel_size, color.to_html(), ring.to_html()])


## CheckButton switch (2:1 pill), `pixel_height` tall.
static func switch(on: bool, pixel_height: int) -> Texture2D:
	var track: String = ('<rect x="1" y="1" width="46" height="22" rx="11" fill="#c829dc" stroke="#ff8cf2" stroke-width="1.5"/>'
			if on else '<rect x="1" y="1" width="46" height="22" rx="11" fill="#1a1636" stroke="#6b6a9a" stroke-width="1.5"/>')
	var knob_x: float = 35.0 if on else 13.0
	var svg: String = ('<svg xmlns="http://www.w3.org/2000/svg" width="48" height="24" viewBox="0 0 48 24">%s'
			+ '<circle cx="%.1f" cy="12" r="8" fill="#ffffff"/></svg>') % [track, knob_x]
	return _render(svg, float(pixel_height) / VIEW_SIZE, "switch:%s:%d" % [on, pixel_height])


static func _render(svg: String, scale: float, key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	var image := Image.new()
	var error: Error = image.load_svg_from_string(svg, scale)
	if error != OK:
		push_error("UiIcons: cannot render '%s' (%s)" % [key, error_string(error)])
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_cache[key] = texture
	return texture


static func _svg(shape: String, color: Color) -> String:
	var hex: String = "#" + color.to_html(false)
	var opacity: float = color.a
	var parts: PackedStringArray = []
	for element: String in shape.split("|"):
		var filled: bool = element.begins_with("F:")
		var body: String = element.trim_prefix("F:")
		var paint: String = ('fill="%s" fill-opacity="%.3f" stroke="none"' % [hex, opacity]) if filled else \
				('fill="none" stroke="%s" stroke-opacity="%.3f" stroke-width="%.1f" stroke-linecap="round" stroke-linejoin="round"'
				% [hex, opacity, STROKE])
		if body.begins_with("C"):
			var circle: PackedStringArray = body.trim_prefix("C").split(",")
			parts.append('<circle cx="%s" cy="%s" r="%s" %s/>' % [circle[0], circle[1], circle[2], paint])
		else:
			parts.append('<path d="%s" %s/>' % [body, paint])
	return '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">%s</svg>' \
			% "".join(parts)
