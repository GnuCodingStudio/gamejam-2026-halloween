class_name FinaleSharePlatform
extends RefCounted


const WEB_SHARE_STATUS_KEY: String = "__halloween2026ShareStatus"


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


static func can_copy_text() -> bool:
	return DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)


static func copy_text(text: String) -> bool:
	if not can_copy_text():
		return false
	DisplayServer.clipboard_set(text)
	return true


static func open_directory(directory_path: String) -> Error:
	if not is_desktop():
		return ERR_UNAVAILABLE
	return OS.shell_open(directory_path)


static func download_png(png_buffer: PackedByteArray, file_name: String) -> void:
	if not is_web():
		return
	JavaScriptBridge.download_buffer(png_buffer, file_name, "image/png")


static func start_web_share(
	share_text: String,
	png_buffer: PackedByteArray,
	file_name: String
) -> String:
	if not is_web():
		return "unavailable"

	var base64_png: String = Marshalls.raw_to_base64(png_buffer)
	var script: String = """
(() => {
	const statusKey = %s;
	window[statusKey] = "pending";
	if (!navigator.share) {
		window[statusKey] = "unavailable";
		return "unavailable";
	}

	const textPayload = { title: "Game Jam Halloween 2026", text: %s };
	let payload = textPayload;
	let mode = "text";
	try {
		const encodedPng = %s;
		if (encodedPng.length > 0 && typeof File !== "undefined") {
			const binary = atob(encodedPng);
			const bytes = new Uint8Array(binary.length);
			for (let index = 0; index < binary.length; index++) {
				bytes[index] = binary.charCodeAt(index);
			}
			const image = new File([bytes], %s, { type: "image/png" });
			const filePayload = {
				title: textPayload.title,
				text: textPayload.text,
				files: [image],
			};
			if (navigator.canShare && navigator.canShare(filePayload)) {
				payload = filePayload;
				mode = "image";
			}
		}
	} catch (_imageError) {
		payload = textPayload;
		mode = "text";
	}

	navigator.share(payload).then(() => {
		window[statusKey] = "success_" + mode;
	}).catch((error) => {
		window[statusKey] = error && error.name === "AbortError" ? "cancelled" : "error";
	});
	return "pending_" + mode;
})()
""" % [
		JSON.stringify(WEB_SHARE_STATUS_KEY),
		JSON.stringify(share_text),
		JSON.stringify(base64_png),
		JSON.stringify(file_name),
	]
	return str(JavaScriptBridge.eval(script, true))


static func get_web_share_status() -> String:
	if not is_web():
		return "unavailable"
	var script: String = "window[%s] || \"\"" % JSON.stringify(WEB_SHARE_STATUS_KEY)
	return str(JavaScriptBridge.eval(script, true))
