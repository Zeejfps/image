part of image;


class TiffDecoder extends Decoder {
  /**
   * Is the given file a valid TIFF image?
   */
  bool isValidFile(List<int> data) {
    return _readHeader(new MemPtr(data)) != null;
  }

  Image decodeImage(List<int> data, {int frame: 0}) {
    MemPtr ptr = new MemPtr(data);

    TiffInfo info = _readHeader(ptr);
    if (info == null) {
      return null;
    }

    for (TiffImage d in info.images) {
      print('IMAGE');
      print('  width: ${d.width}');
      print('  height: ${d.height}');
      print('  photometricType: ${d.photometricType}');
      print('  compression: ${d.compression}');
      print('  bitsPerSample: ${d.bitsPerSample}');
      print('  samplesPerPixel: ${d.samplesPerPixel}');
      print('  imageType: ${d.imageType}');
    }

    return null;
  }

  Animation decodeAnimation(List<int> data) {
    Image image = decodeImage(data);
    if (image == null) {
      return null;
    }

    Animation anim = new Animation();
    anim.addFrame(image);

    return anim;
  }

  /**
   * Read the TIFF header and IFD blocks.
   */
  TiffInfo _readHeader(MemPtr p) {
    TiffInfo info = new TiffInfo();
    info.byteOrder = p.readUint16();
    if (info.byteOrder != TIFF_LITTLE_ENDIAN &&
        info.byteOrder != TIFF_BIG_ENDIAN) {
      return null;
    }

    if (info.byteOrder == TIFF_BIG_ENDIAN) {
      p.byteOrder = BIG_ENDIAN;
    } else {
      p.byteOrder = LITTLE_ENDIAN;
    }

    info.signature = p.readUint16();
    if (info.signature != TIFF_SIGNATURE) {
      return null;
    }

    int offset = p.readUint32();
    info.ifdOffset = offset;

    MemPtr p2 = new MemPtr.from(p);
    p2.offset = offset;

    while (offset != 0) {
      TiffImage img = new TiffImage(p2);
      info.images.add(img);

      offset = p2.readUint32();;
      if (offset != 0) {
        p2.offset = offset;
      }
    }

    return info;
  }

  static const int TIFF_SIGNATURE = 42;
  static const int TIFF_LITTLE_ENDIAN = 0x4949;
  static const int TIFF_BIG_ENDIAN = 0x4d4d;

}
