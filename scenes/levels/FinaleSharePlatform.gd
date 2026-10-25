class_name FinaleSharePlatform
extends RefCounted


static func is_web() -> bool:
	return OS.has_feature("web")


static func is_desktop() -> bool:
	if is_web():
		return false
	return (
		OS.has_feature("windows")
		or OS.has_feature("macos")
		or OS.has_feature("linux")
		or OS.has_feature("bsd")
	)


static func open_directory(directory_path: String) -> Error:
	if not is_desktop():
		return ERR_UNAVAILABLE
	return OS.shell_open(directory_path)


static func download_png(png_buffer: PackedByteArray, file_name: String) -> void:
	if not is_web():
		return
	JavaScriptBridge.download_buffer(png_buffer, file_name, "image/png")
