class_name PdfImageWriter
extends RefCounted


static func write_pages(images: Array, path: String) -> bool:
	if images.is_empty():
		return false
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var written: Array = [0]
	var offsets: Array = []
	var write_str: Callable = func(s: String) -> void:
		var bytes: PackedByteArray = s.to_utf8_buffer()
		file.store_buffer(bytes)
		written[0] = int(written[0]) + bytes.size()
	var write_buf: Callable = func(b: PackedByteArray) -> void:
		file.store_buffer(b)
		written[0] = int(written[0]) + b.size()
	write_str.call("%PDF-1.4\n%\nE2\nE3\nCF\nD3\n")
	var page_count: int = images.size()
	var object_count: int = 1 + 1 + page_count * 3
	var page_object_ids: Array = []
	for i in range(page_count):
		page_object_ids.append(3 + i * 3)
	offsets.append(int(written[0]))
	write_str.call("1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
	offsets.append(int(written[0]))
	var kids_str: String = ""
	for k in page_object_ids:
		kids_str += "%d 0 R " % int(k)
	write_str.call("2 0 obj\n<< /Type /Pages /Kids [ %s] /Count %d >>\nendobj\n" % [kids_str, page_count])
	for i in range(page_count):
		var image: Image = images[i] as Image
		if image == null:
			continue
		if image.get_format() != Image.FORMAT_RGB8:
			image.convert(Image.FORMAT_RGB8)
		var page_obj_id: int = 3 + i * 3
		var content_obj_id: int = page_obj_id + 1
		var image_obj_id: int = page_obj_id + 2
		var w: int = image.get_width()
		var h: int = image.get_height()
		var page_w: float = float(w)
		var page_h: float = float(h)
		offsets.append(int(written[0]))
		write_str.call("%d 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 %f %f] /Contents %d 0 R /Resources << /XObject << /Im0 %d 0 R >> >> >>\nendobj\n" % [
			page_obj_id, page_w, page_h, content_obj_id, image_obj_id,
		])
		var content_stream: String = "q\n%f 0 0 %f 0 0 cm\n/Im0 Do\nQ" % [page_w, page_h]
		offsets.append(int(written[0]))
		write_str.call("%d 0 obj\n<< /Length %d >>\nstream\n%s\nendstream\nendobj\n" % [content_obj_id, content_stream.to_utf8_buffer().size(), content_stream])
		var raw_rgb: PackedByteArray = image.get_data()
		offsets.append(int(written[0]))
		write_str.call("%d 0 obj\n<< /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB /BitsPerComponent 8 /Length %d >>\nstream\n" % [
			image_obj_id, w, h, raw_rgb.size(),
		])
		write_buf.call(raw_rgb)
		write_str.call("\nendstream\nendobj\n")
	var xref_offset: int = int(written[0])
	write_str.call("xref\n0 %d\n0000000000 65535 f \n" % (object_count + 1))
	for off in offsets:
		write_str.call("%010d 00000 n \n" % int(off))
	write_str.call("trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%EOF\n" % [object_count + 1, xref_offset])
	file.close()
	return true
