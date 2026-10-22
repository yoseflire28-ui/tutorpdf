import 'dart:io';
import 'dart:typed_data';

// Full 256-entry CRC32 table for PNG
final _crcTable = () {
  final table = Uint32List(256);
  for (int n = 0; n < 256; n++) {
    int c = n;
    for (int k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(List<int> data) {
  int crc = 0xFFFFFFFF;
  for (final b in data) {
    crc = _crcTable[(crc ^ b) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

void _writeUint32(ByteData bd, int offset, int value) {
  bd.setUint32(offset, value, Endian.big);
}

Uint8List _chunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final crcInput = [...typeBytes, ...data];
  final crc = _crc32(crcInput);
  final out = ByteData(4 + 4 + data.length + 4);
  _writeUint32(out, 0, data.length);
  for (int i = 0; i < 4; i++) {
    out.setUint8(4 + i, typeBytes[i]);
  }
  for (int i = 0; i < data.length; i++) {
    out.setUint8(8 + i, data[i]);
  }
  _writeUint32(out, 8 + data.length, crc & 0xFFFFFFFF);
  return out.buffer.asUint8List();
}

Uint8List makePng(int width, int height, int r, int g, int b, int a) {
  // PNG signature
  final sig = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);

  // IHDR
  final ihdrData = ByteData(13);
  ihdrData.setUint32(0, width, Endian.big);
  ihdrData.setUint32(4, height, Endian.big);
  ihdrData.setUint8(8, 8);   // bit depth
  ihdrData.setUint8(9, 6);   // color type: RGBA
  ihdrData.setUint8(10, 0);  // compression
  ihdrData.setUint8(11, 0);  // filter
  ihdrData.setUint8(12, 0);  // interlace

  // Raw scanlines: filter byte (0) + RGBA per pixel
  final raw = <int>[];
  for (int y = 0; y < height; y++) {
    raw.add(0); // filter: None
    for (int x = 0; x < width; x++) {
      raw.addAll([r, g, b, a]);
    }
  }

  final compressed = ZLibEncoder().convert(raw);

  final out = <int>[];
  out.addAll(sig);
  out.addAll(_chunk('IHDR', ihdrData.buffer.asUint8List()));
  out.addAll(_chunk('IDAT', compressed));
  out.addAll(_chunk('IEND', []));
  return Uint8List.fromList(out);
}

void main() {
  Directory('assets/images').createSync(recursive: true);

  // App icon 1024x1024 — Royal Blue #4169E1
  File('assets/images/app_icon.png').writeAsBytesSync(
    makePng(1024, 1024, 65, 105, 225, 255),
  );
  print('✓ Created assets/images/app_icon.png (1024x1024, Royal Blue)');

  // Splash logo 512x512 — fully transparent
  File('assets/images/splash_logo.png').writeAsBytesSync(
    makePng(512, 512, 0, 0, 0, 0),
  );
  print('✓ Created assets/images/splash_logo.png (512x512, transparent)');
}
