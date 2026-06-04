extends SceneTree

const TARGET_SIZE := Vector2i(574, 81)
const ALPHA_THRESHOLD := 0.04
const HORIZONTAL_SAFE_MARGIN := 16
const BODY_REPAINT_TOP := 46
const BODY_REPAINT_BOTTOM_MARGIN := 1
const BODY_REPAINT_RIGHT_MARGIN := 88
const SLOT_IMAGE_PATHS := [
	"res://assets/art/ui/training_menu_components/dungeon_slot_normal.png",
	"res://assets/art/ui/training_menu_components/dungeon_slot_selected.png",
]

func _init() -> void:
	var failed := false
	for path in SLOT_IMAGE_PATHS:
		if not _normalize_slot_image(path):
			failed = true
	quit(1 if failed else 0)

func _normalize_slot_image(path: String) -> bool:
	var source := Image.load_from_file(path)
	if source == null or source.is_empty():
		push_error("无法读取副本边框图片：%s" % path)
		return false

	if source.get_size() == TARGET_SIZE:
		return _repair_slot_image(source, path)

	var target := Image.create(TARGET_SIZE.x, TARGET_SIZE.y, false, Image.FORMAT_RGBA8)
	target.fill(Color(0.0, 0.0, 0.0, 0.0))

	var copy_size := Vector2i(
		min(source.get_width(), TARGET_SIZE.x),
		min(source.get_height(), TARGET_SIZE.y)
	)
	target.blit_rect(source, Rect2i(Vector2i.ZERO, copy_size), Vector2i.ZERO)

	if source.get_height() < TARGET_SIZE.y:
		var edge_y: int = max(0, source.get_height() - 1)
		for y in range(source.get_height(), TARGET_SIZE.y):
			for x in range(copy_size.x):
				target.set_pixel(x, y, target.get_pixel(x, edge_y))

	if source.get_width() < TARGET_SIZE.x:
		var edge_x: int = max(0, source.get_width() - 1)
		for x in range(source.get_width(), TARGET_SIZE.x):
			for y in range(TARGET_SIZE.y):
				target.set_pixel(x, y, target.get_pixel(edge_x, y))

	var error := target.save_png(path)
	if error != OK:
		push_error("无法写入副本边框图片：%s" % path)
		return false
	return _repair_slot_image(target, path)

func _repair_slot_image(source: Image, path: String) -> bool:
	var sealed := _seal_slot_alpha_gaps(source)
	var repaired := _repaint_lower_body(sealed)
	var error := repaired.save_png(path)
	if error != OK:
		push_error("无法写入修复后的副本边框图片：%s" % path)
		return false
	return true

func _seal_slot_alpha_gaps(source: Image) -> Image:
	var target := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	target.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i.ZERO)

	for x in range(HORIZONTAL_SAFE_MARGIN, source.get_width() - HORIZONTAL_SAFE_MARGIN):
		var fill_color := _find_column_fill_color(source, x)
		if fill_color.a <= ALPHA_THRESHOLD:
			continue
		fill_color.a = max(fill_color.a, 0.96)
		for y in range(1, source.get_height() - 1):
			var pixel := target.get_pixel(x, y)
			if pixel.a <= ALPHA_THRESHOLD:
				target.set_pixel(x, y, fill_color)
	return target

func _repaint_lower_body(source: Image) -> Image:
	var target := Image.create(source.get_width(), source.get_height(), false, Image.FORMAT_RGBA8)
	target.blit_rect(source, Rect2i(Vector2i.ZERO, source.get_size()), Vector2i.ZERO)

	var right_limit := source.get_width() - BODY_REPAINT_RIGHT_MARGIN
	var bottom_limit := source.get_height() - BODY_REPAINT_BOTTOM_MARGIN
	for x in range(HORIZONTAL_SAFE_MARGIN, right_limit):
		var fill_color := _find_column_fill_color(source, x)
		if fill_color.a <= ALPHA_THRESHOLD:
			continue
		fill_color.a = 0.98
		for y in range(BODY_REPAINT_TOP, bottom_limit):
			var pixel := target.get_pixel(x, y)
			if pixel.a <= ALPHA_THRESHOLD:
				continue
			target.set_pixel(x, y, fill_color)
	return target

func _find_column_fill_color(image: Image, x: int) -> Color:
	var center_y := image.get_height() / 2
	var center_pixel := image.get_pixel(x, center_y)
	if center_pixel.a > ALPHA_THRESHOLD and _is_body_color(center_pixel):
		return center_pixel

	var best_color := Color(0.08, 0.18, 0.22, 0.96)
	var best_distance := image.get_height()
	for y in range(image.get_height()):
		var pixel := image.get_pixel(x, y)
		if pixel.a <= ALPHA_THRESHOLD or not _is_body_color(pixel):
			continue
		var distance: int = absi(y - center_y)
		if distance < best_distance:
			best_distance = distance
			best_color = pixel
	return best_color

func _is_body_color(pixel: Color) -> bool:
	return pixel.b >= pixel.r and pixel.g >= pixel.r * 0.8
