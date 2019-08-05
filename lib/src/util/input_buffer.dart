import 'dart:typed_data';

import '../image_exception.dart';
import '../internal/bit_operators.dart';

const int _MaxSignedInt32plus1 = 2147483648;
const int _MaxSignedInt16plus1 = 32768;
const int _MaxSignedInt8plus1 = 128;

abstract class InputBuffer {
  final Uint8List buffer;
  final int start;
  final int end;
  final bool bigEndian;
  int offset;

  /// Create a InputStream for reading from a List<int>
  /*InputBuffer(List<int> buffer, {this.bigEndian = false, int offset = 0,
    int length})
      : this.buffer = buffer,
        this.start = offset,
        this.offset = offset,
        this.end = (length == null) ? buffer.length : offset + length;

  /// Create a copy of [other].
  InputBuffer.from(InputBuffer other, {int offset = 0, int length})
      : this.buffer = other.buffer,
        this.offset = other.offset + offset,
        this.start = other.start,
        this.end =
        (length == null) ? other.end : other.offset + offset + length,
        this.bigEndian = other.bigEndian;*/

  InputBuffer._create(
      this.buffer, this.start, this.offset, this.end, this.bigEndian);

  factory InputBuffer(List<int> buffer,
      {int offset = 0, int length, bool bigEndian = false}) {
    Uint8List _buffer = Uint8List.fromList(buffer);
    int _start = offset;
    int _offset = offset;
    int _end = (length == null) ? buffer.length : offset + length;
    if (bigEndian) {
      return _InputBufferBE._create(_buffer, _start, _offset, _end, bigEndian);
    }
    return _InputBufferLE._create(_buffer, _start, _offset, _end, bigEndian);
  }

  factory InputBuffer.from(InputBuffer other) {
    return InputBuffer(other.buffer,
        offset: other.offset, length: other.length);
  }

  ///  The current read position relative to the start of the buffer.
  int get position => offset - start;

  /// How many bytes are left in the stream.
  int get length => end - offset;

  /// Is the current position at the end of the stream?
  bool get isEOS => offset >= end;

  /// Access the buffer relative from the current position.
  int operator [](int index) => buffer[offset + index];

  /// Set a buffer element relative to the current position.
  operator []=(int index, int value) => buffer[offset + index] = value;

  /// Move the read position by [count] bytes.
  void skip(int count) {
    offset += count;
  }

  /// Read a single byte.
  int readByte() {
    return buffer[offset++];
  }

  int readInt8() {
    int v = buffer[offset++];
    if (v >= _MaxSignedInt8plus1) v -= 2 * _MaxSignedInt8plus1;
    return v;
  }

  int readInt16() {
    int v = buffer[offset + 1] | (buffer[offset] << 8);
    offset += 2;
    if (v >= _MaxSignedInt16plus1) v -= 2 * _MaxSignedInt16plus1;
    return v;
  }

  int readInt32() {
    int v = buffer[offset + 3] |
        (buffer[offset + 2] << 8) |
        (buffer[offset + 1] << 16) |
        (buffer[offset] << 24);
    offset += 4;
    if (v >= _MaxSignedInt32plus1) v -= 2 * _MaxSignedInt32plus1;
    return v;
  }

  /// Read [count] bytes from an [offset] of the current read position, without
  /// moving the read position.
  InputBuffer peekBytes(int count, [int offset = 0]) {
    return subset(count, offset: offset);
  }

  String tryReadString() {
    List<int> codes = [];
    int c;
    while ((c = readByte()) != 0) {
      codes.add(c);
    }
    return String.fromCharCodes(codes);
  }

  String readString(int length) {
    String s = String.fromCharCodes(buffer, offset, offset + length);
    offset += length;
    return s;
  }

  /// Return a InputStream to read a subset of this stream. It does not
  /// move the read position of this stream. [position] is specified relative
  /// to the start of the buffer. If [position] is not specified, the current
  /// read position is used. If [length] is not specified, the remainder of this
  /// stream is used.
  InputBuffer subset(int count, {int position, int offset = 0}) {
    int pos = position != null ? start + position : this.offset;
    pos += offset;

    return InputBuffer(buffer, offset: pos, length: count);
  }

  /// Read [count] bytes from the stream.
  InputBuffer readBytes(int count) {
    InputBuffer bytes = subset(count);
    offset += bytes.length;
    return bytes;
  }

  Uint8List toUint8List() {
    return buffer;
  }

  int readUint16();

  int readUint32();

  double readFloat32();

  double readFloat64();
}

/// Lists used for data convertion (alias each other).
final Uint8List _convU8 = new Uint8List(8);
final Float32List _convF32 = new Float32List.view(_convU8.buffer);
final Float64List _convF64 = new Float64List.view(_convU8.buffer);

class _InputBufferBE extends InputBuffer {
  _InputBufferBE._create(
      Uint8List buffer, int start, int offset, int end, bool bigEndian)
      : super._create(buffer, start, offset, end, bigEndian);

  /// Read a 16-bit word from the stream.
  int readUint16() {
    int v = buffer[offset + 1] | (buffer[offset] << 8);
    offset += 2;
    return v;
  }

  /// Read a 32-bit word from the stream.
  int readUint32() {
    int v = (buffer[offset] << 24) | (buffer[offset+1] << 16) | (buffer[offset+2] << 8) | buffer[offset+3];
    offset += 4;
    return v;
  }

  double readFloat32() {
    _convU8[0] = buffer[offset + 0]; _convU8[1] = buffer[offset + 1];
    _convU8[2] = buffer[offset + 2]; _convU8[3] = buffer[offset + 3];
    offset += 4;
    return _convF32[0];
  }
  
  double readFloat64() {
    _convU8[0] = buffer[offset + 0]; _convU8[1] = buffer[offset + 1];
    _convU8[2] = buffer[offset + 2]; _convU8[3] = buffer[offset + 3];
    _convU8[4] = buffer[offset + 4]; _convU8[5] = buffer[offset + 5];
    _convU8[6] = buffer[offset + 6]; _convU8[7] = buffer[offset + 7];
    offset += 8;
    return _convF64[0];
  }
}

class _InputBufferLE extends InputBuffer {
  _InputBufferLE._create(
      Uint8List buffer, int start, int offset, int end, bool bigEndian)
      : super._create(buffer, start, offset, end, bigEndian);

  /// Read a 16-bit word from the stream.
  int readUint16() {
    int v = (buffer[offset] << 8) | buffer[offset + 1];
    offset += 2;
    return v;
  }

  int readUint32() {
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    int b3 = buffer[offset++] & 0xff;
    int b4 = buffer[offset++] & 0xff;
    return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
  }

  double readFloat32() {
    _convU8[0] = buffer[offset + 3]; _convU8[1] = buffer[offset + 2];
    _convU8[2] = buffer[offset + 1]; _convU8[3] = buffer[offset + 0];
    offset += 4;
    return _convF32[0];
  }

  double readFloat64() {
    _convU8[0] = buffer[offset + 7]; _convU8[1] = buffer[offset + 6];
    _convU8[2] = buffer[offset + 5]; _convU8[3] = buffer[offset + 4];
    _convU8[4] = buffer[offset + 3]; _convU8[5] = buffer[offset + 2];
    _convU8[6] = buffer[offset + 1]; _convU8[7] = buffer[offset + 0];
    offset += 8;
    return _convF64[0];
  }
}
/*
/// A buffer that can be read as a stream of bytes.
class InputBuffer {
  List<int> buffer;
  final int start;
  final int end;
  int offset;
  bool bigEndian;

  /// Create a InputStream for reading from a List<int>
  InputBuffer(List<int> buffer, {this.bigEndian = false, int offset = 0,
              int length})
      : this.buffer = buffer,
        this.start = offset,
        this.offset = offset,
        this.end = (length == null) ? buffer.length : offset + length;

  /// Create a copy of [other].
  InputBuffer.from(InputBuffer other, {int offset = 0, int length})
      : this.buffer = other.buffer,
        this.offset = other.offset + offset,
        this.start = other.start,
        this.end =
            (length == null) ? other.end : other.offset + offset + length,
        this.bigEndian = other.bigEndian;

  ///  The current read position relative to the start of the buffer.
  int get position => offset - start;

  /// How many bytes are left in the stream.
  int get length => end - offset;

  /// Is the current position at the end of the stream?
  bool get isEOS => offset >= end;

  /// Reset to the beginning of the stream.
  void rewind() {
    offset = start;
  }

  /// Access the buffer relative from the current position.
  int operator [](int index) => buffer[offset + index];

  /// Set a buffer element relative to the current position.
  operator []=(int index, int value) => buffer[offset + index] = value;

  /// Copy data from [other] to this buffer, at [start] offset from the
  /// current read position, and [length] number of bytes. [offset] is
  /// the offset in [other] to start reading.
  void memcpy(int start, int length, dynamic other, [int offset = 0]) {
    if (other is InputBuffer) {
      buffer.setRange(this.offset + start, this.offset + start + length,
          other.buffer, other.offset + offset);
    } else {
      buffer.setRange(this.offset + start, this.offset + start + length,
          other as List<int>, offset);
    }
  }

  /// Set a range of bytes in this buffer to [value], at [start] offset from the
  ///current read position, and [length] number of bytes.
  void memset(int start, int length, int value) {
    buffer.fillRange(offset + start, offset + start + length, value);
  }

  /// Return a InputStream to read a subset of this stream. It does not
  /// move the read position of this stream. [position] is specified relative
  /// to the start of the buffer. If [position] is not specified, the current
  /// read position is used. If [length] is not specified, the remainder of this
  /// stream is used.
  InputBuffer subset(int count, {int position, int offset = 0}) {
    int pos = position != null ? start + position : this.offset;
    pos += offset;

    return InputBuffer(buffer,
        bigEndian: bigEndian, offset: pos, length: count);
  }

  /// Returns the position of the given [value] within the buffer, starting
  /// from the current read position with the given [offset]. The position
  /// returned is relative to the start of the buffer, or -1 if the [value]
  /// was not found.
  int indexOf(int value, [int offset = 0]) {
    for (int i = this.offset + offset, end = this.offset + length;
        i < end;
        ++i) {
      if (buffer[i] == value) {
        return i - this.start;
      }
    }
    return -1;
  }

  /// Read [count] bytes from an [offset] of the current read position, without
  /// moving the read position.
  InputBuffer peekBytes(int count, [int offset = 0]) {
    return subset(count, offset: offset);
  }

  /// Move the read position by [count] bytes.
  void skip(int count) {
    offset += count;
  }

  /// Read a single byte.
  int readByte() {
    return buffer[offset++];
  }

  int readInt8() {
    return uint8ToInt8(readByte());
  }

  /// Read [count] bytes from the stream.
  InputBuffer readBytes(int count) {
    InputBuffer bytes = subset(count);
    offset += bytes.length;
    return bytes;
  }

  /// Read a null-terminated string, or if [len] is provided, that number of
  /// bytes returned as a string.
  String readString([int len]) {
    if (len == null) {
      List<int> codes = [];
      while (!isEOS) {
        int c = readByte();
        if (c == 0) {
          return String.fromCharCodes(codes);
        }
        codes.add(c);
      }
      throw ImageException('EOF reached without finding string terminator');
    }

    InputBuffer s = readBytes(len);
    Uint8List bytes = s.toUint8List();
    String str = String.fromCharCodes(bytes);
    return str;
  }

  /// Read a 16-bit word from the stream.
  int readUint16() {
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    if (bigEndian) {
      return (b1 << 8) | b2;
    }
    return (b2 << 8) | b1;
  }

  /// Read a 16-bit word from the stream.
  int readInt16() {
    return uint16ToInt16(readUint16());
  }

  /// Read a 24-bit word from the stream.
  int readUint24() {
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    int b3 = buffer[offset++] & 0xff;
    if (bigEndian) {
      return b3 | (b2 << 8) | (b1 << 16);
    }
    return b1 | (b2 << 8) | (b3 << 16);
  }

  /// Read a 32-bit word from the stream.
  int readUint32() {
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    int b3 = buffer[offset++] & 0xff;
    int b4 = buffer[offset++] & 0xff;
    if (bigEndian) {
      return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
    }
    return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
  }

  /// Read a signed 32-bit integer from the stream.
  int readInt32() {
    return uint32ToInt32(readUint32());
  }

  /// Read a 32-bit float.
  double readFloat32() {
    return uint32ToFloat32(readUint32());
  }

  /// Read a 64-bit float.
  double readFloat64() {
    return uint64ToFloat64(readUint64());
  }

  /// Read a 64-bit word form the stream.
  int readUint64() {
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    int b3 = buffer[offset++] & 0xff;
    int b4 = buffer[offset++] & 0xff;
    int b5 = buffer[offset++] & 0xff;
    int b6 = buffer[offset++] & 0xff;
    int b7 = buffer[offset++] & 0xff;
    int b8 = buffer[offset++] & 0xff;
    if (bigEndian) {
      return (b1 << 56) |
          (b2 << 48) |
          (b3 << 40) |
          (b4 << 32) |
          (b5 << 24) |
          (b6 << 16) |
          (b7 << 8) |
          b8;
    }
    return (b8 << 56) |
        (b7 << 48) |
        (b6 << 40) |
        (b5 << 32) |
        (b4 << 24) |
        (b3 << 16) |
        (b2 << 8) |
        b1;
  }

  List<int> toList([int offset = 0, int length = 0]) {
    if (buffer is Uint8List) {
      return toUint8List(offset, length);
    }
    int s = start + this.offset + offset;
    int e = (length <= 0) ? end : s + length;
    return buffer.sublist(s, e);
  }

  Uint8List toUint8List([int offset = 0, int length]) {
    int len = length != null ? length : this.length - offset;
    if (buffer is Uint8List) {
      Uint8List b = buffer as Uint8List;
      return Uint8List.view(
          b.buffer, b.offsetInBytes + this.offset + offset, len);
    }
    return Uint8List.fromList(
        buffer.sublist(this.offset + offset, this.offset + offset + len));
  }

  Uint32List toUint32List([int offset = 0]) {
    if (buffer is Uint8List) {
      Uint8List b = buffer as Uint8List;
      return Uint32List.view(
          b.buffer, b.offsetInBytes + this.offset + offset);
    }
    return Uint32List.view(toUint8List().buffer);
  }
}
*/
