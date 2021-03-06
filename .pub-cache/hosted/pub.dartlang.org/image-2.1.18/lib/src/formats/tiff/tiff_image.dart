import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../color.dart';
import '../../image.dart';
import '../../image_exception.dart';
import '../../formats/jpeg_decoder.dart';
import '../../hdr/half.dart';
import '../../hdr/hdr_image.dart';
import '../../internal/bit_operators.dart';
import '../../util/input_buffer.dart';
import 'tiff_bit_reader.dart';
import 'tiff_entry.dart';
import 'tiff_fax_decoder.dart';
import 'tiff_lzw_decoder.dart';

class TiffImage {
  Map<int, TiffEntry> tags = {};
  int width;
  int height;
  int photometricType;
  int compression = 1;
  int bitsPerSample = 1;
  int samplesPerPixel = 1;
  int sampleFormat = FORMAT_UINT;
  int imageType = TYPE_UNSUPPORTED;
  bool isWhiteZero = false;
  int predictor = 1;
  int chromaSubH;
  int chromaSubV;
  bool tiled = false;
  int tileWidth;
  int tileHeight;
  List<int> tileOffsets;
  List<int> tileByteCounts;
  int tilesX;
  int tilesY;
  int tileSize;
  int fillOrder = 1;
  int t4Options = 0;
  int t6Options = 0;
  int extraSamples;
  List<int> colorMap;

  // Starting index in the [colorMap] for the red channel.
  int colorMapRed;

  // Starting index in the [colorMap] for the green channel.
  int colorMapGreen;

  // Starting index in the [colorMap] for the blue channel.
  int colorMapBlue;
  Image image;
  HdrImage hdrImage;

  TiffImage(InputBuffer p) {
    var p3 = InputBuffer.from(p);

    var numDirEntries = p.readUint16();
    for (var i = 0; i < numDirEntries; ++i) {
      var tag = p.readUint16();
      var type = p.readUint16();
      var numValues = p.readUint32();
      var entry = TiffEntry(tag, type, numValues);

      // The value for the tag is either stored in another location,
      // or within the tag itself (if the size fits in 4 bytes).
      // We're not reading the data here, just storing offsets.
      if (entry.numValues * entry.typeSize > 4) {
        entry.valueOffset = p.readUint32();
      } else {
        entry.valueOffset = p.offset;
        p.offset += 4;
      }

      tags[entry.tag] = entry;

      if (entry.tag == TAG_IMAGE_WIDTH) {
        width = entry.readValue(p3);
      } else if (entry.tag == TAG_IMAGE_LENGTH) {
        height = entry.readValue(p3);
      } else if (entry.tag == TAG_PHOTOMETRIC_INTERPRETATION) {
        photometricType = entry.readValue(p3);
      } else if (entry.tag == TAG_COMPRESSION) {
        compression = entry.readValue(p3);
      } else if (entry.tag == TAG_BITS_PER_SAMPLE) {
        bitsPerSample = entry.readValue(p3);
      } else if (entry.tag == TAG_SAMPLES_PER_PIXEL) {
        samplesPerPixel = entry.readValue(p3);
      } else if (entry.tag == TAG_PREDICTOR) {
        predictor = entry.readValue(p3);
      } else if (entry.tag == TAG_SAMPLE_FORMAT) {
        sampleFormat = entry.readValue(p3);
      } else if (entry.tag == TAG_COLOR_MAP) {
        colorMap = entry.readValues(p3);
        colorMapRed = 0;
        colorMapGreen = colorMap.length ~/ 3;
        colorMapBlue = colorMapGreen * 2;
      }
    }

    if (width == null ||
        height == null ||
        bitsPerSample == null ||
        compression == null) {
      return;
    }

    if (colorMap != null && bitsPerSample == 8) {
      for (var i = 0, len = colorMap.length; i < len; ++i) {
        colorMap[i] >>= 8;
      }
    }

    if (photometricType == 0) {
      isWhiteZero = true;
    }

    if (hasTag(TAG_TILE_OFFSETS)) {
      tiled = true;
      // Image is in tiled format
      tileWidth = _readTag(p3, TAG_TILE_WIDTH);
      tileHeight = _readTag(p3, TAG_TILE_LENGTH);
      tileOffsets = _readTagList(p3, TAG_TILE_OFFSETS);
      tileByteCounts = _readTagList(p3, TAG_TILE_BYTE_COUNTS);
    } else {
      tiled = false;

      tileWidth = _readTag(p3, TAG_TILE_WIDTH, width);
      if (!hasTag(TAG_ROWS_PER_STRIP)) {
        tileHeight = _readTag(p3, TAG_TILE_LENGTH, height);
      } else {
        var l = _readTag(p3, TAG_ROWS_PER_STRIP);
        var infinity = 1;
        infinity = (infinity << 32) - 1;
        if (l == infinity) {
          // 2^32 - 1 (effectively infinity, entire image is 1 strip)
          tileHeight = height;
        } else {
          tileHeight = l;
        }
      }

      tileOffsets = _readTagList(p3, TAG_STRIP_OFFSETS);
      tileByteCounts = _readTagList(p3, TAG_STRIP_BYTE_COUNTS);
    }

    // Calculate number of tiles and the tileSize in bytes
    tilesX = (width + tileWidth - 1) ~/ tileWidth;
    tilesY = (height + tileHeight - 1) ~/ tileHeight;
    tileSize = tileWidth * tileHeight * samplesPerPixel;

    fillOrder = _readTag(p3, TAG_FILL_ORDER, 1);
    t4Options = _readTag(p3, TAG_T4_OPTIONS, 0);
    t6Options = _readTag(p3, TAG_T6_OPTIONS, 0);
    extraSamples = _readTag(p3, TAG_EXTRA_SAMPLES, 0);

    // Determine which kind of image we are dealing with.
    switch (photometricType) {
      case 0: // WhiteIsZero
      case 1: // BlackIsZero
        if (bitsPerSample == 1 && samplesPerPixel == 1) {
          imageType = TYPE_BILEVEL;
        } else if (bitsPerSample == 4 && samplesPerPixel == 1) {
          imageType = TYPE_GRAY_4BIT;
        } else if (bitsPerSample % 8 == 0) {
          if (samplesPerPixel == 1) {
            imageType = TYPE_GRAY;
          } else if (samplesPerPixel == 2) {
            imageType = TYPE_GRAY_ALPHA;
          } else {
            imageType = TYPE_GENERIC;
          }
        }
        break;
      case 2: // RGB
        if (bitsPerSample % 8 == 0) {
          if (samplesPerPixel == 3) {
            imageType = TYPE_RGB;
          } else if (samplesPerPixel == 4) {
            imageType = TYPE_RGB_ALPHA;
          } else {
            imageType = TYPE_GENERIC;
          }
        }
        break;
      case 3: // RGB Palette
        if (samplesPerPixel == 1 &&
            (bitsPerSample == 4 || bitsPerSample == 8 || bitsPerSample == 16)) {
          imageType = TYPE_PALETTE;
        }
        break;
      case 4: // Transparency mask
        if (bitsPerSample == 1 && samplesPerPixel == 1) {
          imageType = TYPE_BILEVEL;
        }
        break;
      case 6: // YCbCr
        if (compression == COMPRESSION_JPEG &&
            bitsPerSample == 8 &&
            samplesPerPixel == 3) {
          imageType = TYPE_RGB;
        } else {
          if (hasTag(TAG_YCBCR_SUBSAMPLING)) {
            var v = tags[TAG_YCBCR_SUBSAMPLING].readValues(p3);
            chromaSubH = v[0];
            chromaSubV = v[1];
          } else {
            chromaSubH = 2;
            chromaSubV = 2;
          }

          if (chromaSubH * chromaSubV == 1) {
            imageType = TYPE_GENERIC;
          } else if (bitsPerSample == 8 && samplesPerPixel == 3) {
            imageType = TYPE_YCBCR_SUB;
          }
        }
        break;
      default: // Other including CMYK, CIE L*a*b*, unknown.
        if (bitsPerSample % 8 == 0) {
          imageType = TYPE_GENERIC;
        }
        break;
    }
  }

  bool get isValid =>
      width != null &&
      height != null &&
      samplesPerPixel != null &&
      bitsPerSample != null &&
      compression != null;

  Image decode(InputBuffer p) {
    image = Image(width, height);
    for (var tileY = 0, ti = 0; tileY < tilesY; ++tileY) {
      for (var tileX = 0; tileX < tilesX; ++tileX, ++ti) {
        _decodeTile(p, tileX, tileY);
      }
    }
    return image;
  }

  HdrImage decodeHdr(InputBuffer p) {
    hdrImage = HdrImage.create(
        width,
        height,
        samplesPerPixel,
        sampleFormat == FORMAT_UINT
            ? HdrImage.UINT
            : bitsPerSample == 16
                ? HdrImage.HALF
                : bitsPerSample == 32
                    ? HdrImage.FLOAT
                    : bitsPerSample == 64
                        ? HdrImage.FLOAT64
                        : HdrImage.FLOAT);
    for (var tileY = 0, ti = 0; tileY < tilesY; ++tileY) {
      for (var tileX = 0; tileX < tilesX; ++tileX, ++ti) {
        _decodeTile(p, tileX, tileY);
      }
    }
    return hdrImage;
  }

  bool hasTag(int tag) => tags.containsKey(tag);

  void _decodeTile(InputBuffer p, int tileX, int tileY) {
    // Read the data, uncompressing as needed. There are four cases:
    // bilevel, palette-RGB, 4-bit grayscale, and everything else.
    if (imageType == TYPE_BILEVEL) {
      _decodeBilevelTile(p, tileX, tileY);
      return;
    }

    var tileIndex = tileY * tilesX + tileX;
    p.offset = tileOffsets[tileIndex];

    var outX = tileX * tileWidth;
    var outY = tileY * tileHeight;

    var byteCount = tileByteCounts[tileIndex];
    var bytesInThisTile = tileWidth * tileHeight * samplesPerPixel;
    if (bitsPerSample == 16) {
      bytesInThisTile *= 2;
    } else if (bitsPerSample == 32) {
      bytesInThisTile *= 4;
    }

    InputBuffer bdata;
    if (bitsPerSample == 8 ||
        bitsPerSample == 16 ||
        bitsPerSample == 32 ||
        bitsPerSample == 64) {
      if (compression == COMPRESSION_NONE) {
        bdata = p;
      } else if (compression == COMPRESSION_LZW) {
        bdata = InputBuffer(Uint8List(bytesInThisTile));
        final decoder = LzwDecoder();
        try {
          decoder.decode(
              InputBuffer.from(p, offset: 0, length: byteCount), bdata.buffer);
        } catch (e) {
          print(e);
        }
        // Horizontal Differencing Predictor
        if (predictor == 2) {
          int count;
          for (var j = 0; j < tileHeight; j++) {
            count = samplesPerPixel * (j * tileWidth + 1);
            for (var i = samplesPerPixel, len = tileWidth * samplesPerPixel;
                i < len;
                i++) {
              bdata[count] += bdata[count - samplesPerPixel];
              count++;
            }
          }
        }
      } else if (compression == COMPRESSION_PACKBITS) {
        bdata = InputBuffer(Uint8List(bytesInThisTile));
        _decodePackbits(p, bytesInThisTile, bdata.buffer);
      } else if (compression == COMPRESSION_DEFLATE) {
        var data = p.toList(0, byteCount);
        var outData = Inflate(data).getBytes();
        bdata = InputBuffer(outData);
      } else if (compression == COMPRESSION_ZIP) {
        var data = p.toList(0, byteCount);
        var outData = ZLibDecoder().decodeBytes(data);
        bdata = InputBuffer(outData);
      } else if (compression == COMPRESSION_OLD_JPEG) {
        image ??= Image(width, height);
        var data = p.toList(0, byteCount);
        var tile = JpegDecoder().decodeImage(data);
        _jpegToImage(tile, image, outX, outY, tileWidth, tileHeight);
        if (hdrImage != null) {
          hdrImage = HdrImage.fromImage(image);
        }
        return;
      } else {
        throw ImageException('Unsupported Compression Type: $compression');
      }

      if (bdata == null) {
        return;
      }

      var pi = 0;
      for (var y = 0, py = outY; y < tileHeight && py < height; ++y, ++py) {
        for (var x = 0, px = outX; x < tileWidth && px < width; ++x, ++px) {
          if (samplesPerPixel == 1) {
            if (sampleFormat == TiffImage.FORMAT_FLOAT) {
              var sample = 0.0;
              if (bitsPerSample == 32) {
                sample = bdata.readFloat32();
              } else if (bitsPerSample == 64) {
                sample = bdata.readFloat64();
              } else if (bitsPerSample == 16) {
                sample = Half.HalfToDouble(bdata.readUint16());
              }
              if (hdrImage != null) {
                hdrImage.setRed(px, py, sample);
              }
              if (image != null) {
                final gray = (sample * 255).clamp(0, 255).toInt();
                int c;
                if (photometricType == 3 && colorMap != null) {
                  c = getColor(
                      colorMap[colorMapRed + gray],
                      colorMap[colorMapGreen + gray],
                      colorMap[colorMapBlue + gray]);
                } else {
                  c = getColor(gray, gray, gray, 255);
                }
                image.setPixel(px, py, c);
              }
            } else {
              var gray = bdata[pi++];
              var gray16 = gray;
              // down-sample 16-bit to 8-bit..
              if (bitsPerSample == 16) {
                if (!p.bigEndian) {
                  gray = bdata[pi++];
                  gray16 = gray << 8 | gray16;
                } else {
                  gray16 = gray16 << 8 | bdata[pi++];
                }
              }

              if (photometricType == 0) {
                gray = 255 - gray;
                gray16 = 0xffff - gray16;
              }

              if (hdrImage != null) {
                var fg = gray16 / 0xffff;
                hdrImage.setRed(px, py, fg);
              }

              if (image != null) {
                int c;
                if (photometricType == 3 && colorMap != null) {
                  c = getColor(
                      colorMap[colorMapRed + gray],
                      colorMap[colorMapGreen + gray],
                      colorMap[colorMapBlue + gray]);
                } else {
                  c = getColor(gray, gray, gray, 255);
                }

                image.setPixel(px, py, c);
              }
            }
          } else if (samplesPerPixel == 2) {
            var gray = bdata[pi++];
            var gray16 = gray;
            if (bitsPerSample == 16) {
              gray16 = gray16 << 8 | bdata[pi++];
            }
            var alpha = bdata[pi++];
            var alpha16 = alpha;
            if (bitsPerSample == 16) {
              alpha16 = alpha16 << 8 | bdata[pi++];
            }

            if (hdrImage != null) {
              var fg = gray16 / 0xffff;
              var fa = alpha16 / 0xffff;
              hdrImage.setRed(px, py, fg);
              hdrImage.setGreen(px, py, fg);
            }

            if (image != null) {
              var c = getColor(gray, gray, gray, alpha);
              image.setPixel(px, py, c);
            }
          } else if (samplesPerPixel == 3) {
            if (sampleFormat == FORMAT_FLOAT) {
              var r = 0.0;
              var g = 0.0;
              var b = 0.0;
              if (bitsPerSample == 32) {
                r = bdata.readFloat32();
                g = bdata.readFloat32();
                b = bdata.readFloat32();
              } else if (bitsPerSample == 64) {
                r = bdata.readFloat64();
                g = bdata.readFloat64();
                b = bdata.readFloat64();
              } else if (bitsPerSample == 16) {
                r = Half.HalfToDouble(bdata.readUint16());
                g = Half.HalfToDouble(bdata.readUint16());
                b = Half.HalfToDouble(bdata.readUint16());
              }
              if (hdrImage != null) {
                hdrImage.setRed(px, py, r);
                hdrImage.setGreen(px, py, g);
                hdrImage.setBlue(px, py, b);
              }
              if (image != null) {
                final ri = (r * 255).clamp(0, 255).toInt();
                final gi = (g * 255).clamp(0, 255).toInt();
                final bi = (b * 255).clamp(0, 255).toInt();
                final c = getColor(ri, gi, bi, 255);
                image.setPixel(px, py, c);
              }
            } else {
              var r = bdata[pi++];
              var r16 = r;
              if (bitsPerSample == 16) {
                r16 = r16 << 8 | bdata[pi++];
              }

              var g = bdata[pi++];
              var g16 = r;
              if (bitsPerSample == 16) {
                g16 = g16 << 8 | bdata[pi++];
              }

              var b = bdata[pi++];
              var b16 = r;
              if (bitsPerSample == 16) {
                b16 = b16 << 8 | bdata[pi++];
              }

              if (hdrImage != null) {
                hdrImage.setRed(px, py, r16 / 0xffff);
                hdrImage.setGreen(px, py, g16 / 0xffff);
                hdrImage.setBlue(px, py, b16 / 0xffff);
              }

              if (image != null) {
                var c = getColor(r, g, b, 255);
                image.setPixel(px, py, c);
              }
            }
          } else if (samplesPerPixel >= 4) {
            if (sampleFormat == FORMAT_FLOAT) {
              var r = 0.0;
              var g = 0.0;
              var b = 0.0;
              var a = 0.0;
              if (bitsPerSample == 32) {
                r = bdata.readFloat32();
                g = bdata.readFloat32();
                b = bdata.readFloat32();
                a = bdata.readFloat32();
              } else if (bitsPerSample == 64) {
                r = bdata.readFloat64();
                g = bdata.readFloat64();
                b = bdata.readFloat64();
                a = bdata.readFloat64();
              } else if (bitsPerSample == 16) {
                r = Half.HalfToDouble(bdata.readUint16());
                g = Half.HalfToDouble(bdata.readUint16());
                b = Half.HalfToDouble(bdata.readUint16());
                a = Half.HalfToDouble(bdata.readUint16());
              }
              if (hdrImage != null) {
                hdrImage.setRed(px, py, r);
                hdrImage.setGreen(px, py, g);
                hdrImage.setBlue(px, py, b);
                hdrImage.setAlpha(px, py, a);
              }
              if (image != null) {
                final ri = (r * 255).clamp(0, 255).toInt();
                final gi = (g * 255).clamp(0, 255).toInt();
                final bi = (b * 255).clamp(0, 255).toInt();
                final ai = (a * 255).clamp(0, 255).toInt();
                final c = getColor(ri, gi, bi, ai);
                image.setPixel(px, py, c);
              }
            } else {
              var r = bdata[pi++];
              var r16 = r;
              if (bitsPerSample == 16) {
                r16 = r16 << 8 | bdata[pi++];
              }

              var g = bdata[pi++];
              var g16 = g;
              if (bitsPerSample == 16) {
                g16 = g16 << 8 | bdata[pi++];
              }

              var b = bdata[pi++];
              var b16 = b;
              if (bitsPerSample == 16) {
                b16 = b16 << 8 | bdata[pi++];
              }

              var a = bdata[pi++];
              var a16 = a;
              if (bitsPerSample == 16) {
                a16 = a16 << 8 | bdata[pi++];
              }

              if (hdrImage != null) {
                hdrImage.setRed(px, py, r16 / 0xffff);
                hdrImage.setGreen(px, py, g16 / 0xffff);
                hdrImage.setBlue(px, py, b16 / 0xffff);
                hdrImage.setAlpha(px, py, a16 / 0xffff);
              }

              if (image != null) {
                var c = getColor(r, g, b, a);
                image.setPixel(px, py, c);
              }
            }
          }
        }
      }
    } else {
      throw ImageException('Unsupported bitsPerSample: $bitsPerSample');
    }
  }

  void _jpegToImage(Image tile, Image image, int outX, int outY, int tileWidth,
      int tileHeight) {
    var width = tileWidth;
    var height = tileHeight;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixel(x + outX, y + outY, tile.getPixel(x, y));
      }
    }
    /*Uint8List data = jpeg.getData(width, height);
    List components = jpeg.components;

    int i = 0;
    int j = 0;
    switch (components.length) {
      case 1: // Luminance
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            int Y = data[i++];
            image.setPixel(x + outX, y + outY, getColor(Y, Y, Y, 255));
          }
        }
        break;
      case 3: // RGB
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            int R = data[i++];
            int G = data[i++];
            int B = data[i++];

            int c = getColor(R, G, B, 255);
            image.setPixel(x + outX, y + outY, c);
          }
        }
        break;
      case 4: // CMYK
        for (int y = 0; y < height; y++) {
          for (int x = 0; x < width; x++) {
            int C = data[i++];
            int M = data[i++];
            int Y = data[i++];
            int K = data[i++];

            int R = 255 - _clamp(C * (1 - K ~/ 255) + K);
            int G = 255 - _clamp(M * (1 - K ~/ 255) + K);
            int B = 255 - _clamp(Y * (1 - K ~/ 255) + K);

            image.setPixel(x + outX, y + outY, getColor(R, G, B, 255));
          }
        }
        break;
      default:
        throw 'Unsupported color mode';
    }*/
  }

  /*int _clamp(int i) {
    return i < 0 ? 0 : i > 255 ? 255 : i;
  }*/

  void _decodeBilevelTile(InputBuffer p, int tileX, int tileY) {
    var tileIndex = tileY * tilesX + tileX;
    p.offset = tileOffsets[tileIndex];

    var outX = tileX * tileWidth;
    var outY = tileY * tileHeight;

    var byteCount = tileByteCounts[tileIndex];

    InputBuffer bdata;
    if (compression == COMPRESSION_PACKBITS) {
      // Since the decompressed data will still be packed
      // 8 pixels into 1 byte, calculate bytesInThisTile
      int bytesInThisTile;
      if ((tileWidth % 8) == 0) {
        bytesInThisTile = (tileWidth ~/ 8) * tileHeight;
      } else {
        bytesInThisTile = (tileWidth ~/ 8 + 1) * tileHeight;
      }
      bdata = InputBuffer(Uint8List(tileWidth * tileHeight));
      _decodePackbits(p, bytesInThisTile, bdata.buffer);
    } else if (compression == COMPRESSION_LZW) {
      bdata = InputBuffer(Uint8List(tileWidth * tileHeight));

      var decoder = LzwDecoder();
      decoder.decode(InputBuffer.from(p, length: byteCount), bdata.buffer);

      // Horizontal Differencing Predictor
      if (predictor == 2) {
        int count;
        for (var j = 0; j < height; j++) {
          count = samplesPerPixel * (j * width + 1);
          for (var i = samplesPerPixel; i < width * samplesPerPixel; i++) {
            bdata[count] += bdata[count - samplesPerPixel];
            count++;
          }
        }
      }
    } else if (compression == COMPRESSION_CCITT_RLE) {
      bdata = InputBuffer(Uint8List(tileWidth * tileHeight));
      try {
        TiffFaxDecoder(fillOrder, tileWidth, tileHeight)
            .decode1D(bdata, p, 0, tileHeight);
      } catch (_) {}
    } else if (compression == COMPRESSION_CCITT_FAX3) {
      bdata = InputBuffer(Uint8List(tileWidth * tileHeight));
      try {
        TiffFaxDecoder(fillOrder, tileWidth, tileHeight)
            .decode2D(bdata, p, 0, tileHeight, t4Options);
      } catch (_) {}
    } else if (compression == COMPRESSION_CCITT_FAX4) {
      bdata = InputBuffer(Uint8List(tileWidth * tileHeight));
      try {
        TiffFaxDecoder(fillOrder, tileWidth, tileHeight)
            .decodeT6(bdata, p, 0, tileHeight, t6Options);
      } catch (_) {}
    } else if (compression == COMPRESSION_ZIP) {
      var data = p.toList(0, byteCount);
      var outData = ZLibDecoder().decodeBytes(data);
      bdata = InputBuffer(outData);
    } else if (compression == COMPRESSION_DEFLATE) {
      var data = p.toList(0, byteCount);
      var outData = Inflate(data).getBytes();
      bdata = InputBuffer(outData);
    } else if (compression == COMPRESSION_NONE) {
      bdata = p;
    } else {
      throw ImageException('Unsupported Compression Type: $compression');
    }

    if (bdata == null) {
      return;
    }

    var br = TiffBitReader(bdata);
    final white = isWhiteZero ? 0xff000000 : 0xffffffff;
    final black = isWhiteZero ? 0xffffffff : 0xff000000;

    for (var y = 0, py = outY; y < tileHeight; ++y, ++py) {
      for (var x = 0, px = outX; x < tileWidth; ++x, ++px) {
        if (br.readBits(1) == 0) {
          image.setPixel(px, py, black);
        } else {
          image.setPixel(px, py, white);
        }
      }
      br.flushByte();
    }
  }

  // Uncompress packbits compressed image data.
  void _decodePackbits(InputBuffer data, int arraySize, List<int> dst) {
    var srcCount = 0;
    var dstCount = 0;

    while (dstCount < arraySize) {
      var b = uint8ToInt8(data[srcCount++]);
      if (b >= 0 && b <= 127) {
        // literal run packet
        for (var i = 0; i < (b + 1); ++i) {
          dst[dstCount++] = data[srcCount++];
        }
      } else if (b <= -1 && b >= -127) {
        // 2 byte encoded run packet
        var repeat = data[srcCount++];
        for (var i = 0; i < (-b + 1); ++i) {
          dst[dstCount++] = repeat;
        }
      } else {
        // no-op packet. Do nothing
        srcCount++;
      }
    }
  }

  int _readTag(InputBuffer p, int type, [int defaultValue = 0]) {
    if (!hasTag(type)) {
      return defaultValue;
    }
    return tags[type].readValue(p);
  }

  List<int> _readTagList(InputBuffer p, int type) {
    if (!hasTag(type)) {
      return null;
    }
    return tags[type].readValues(p);
  }

  // Compression types
  static const COMPRESSION_NONE = 1;
  static const COMPRESSION_CCITT_RLE = 2;
  static const COMPRESSION_CCITT_FAX3 = 3;
  static const COMPRESSION_CCITT_FAX4 = 4;
  static const COMPRESSION_LZW = 5;
  static const COMPRESSION_OLD_JPEG = 6;
  static const COMPRESSION_JPEG = 7;
  static const COMPRESSION_NEXT = 32766;
  static const COMPRESSION_CCITT_RLEW = 32771;
  static const COMPRESSION_PACKBITS = 32773;
  static const COMPRESSION_THUNDERSCAN = 32809;
  static const COMPRESSION_IT8CTPAD = 32895;
  static const COMPRESSION_IT8LW = 32896;
  static const COMPRESSION_IT8MP = 32897;
  static const COMPRESSION_IT8BL = 32898;
  static const COMPRESSION_PIXARFILM = 32908;
  static const COMPRESSION_PIXARLOG = 32909;
  static const COMPRESSION_DEFLATE = 32946;
  static const COMPRESSION_ZIP = 8;
  static const COMPRESSION_DCS = 32947;
  static const COMPRESSION_JBIG = 34661;
  static const COMPRESSION_SGILOG = 34676;
  static const COMPRESSION_SGILOG24 = 34677;
  static const COMPRESSION_JP2000 = 34712;

  // Image types
  static const TYPE_UNSUPPORTED = -1;
  static const TYPE_BILEVEL = 0;
  static const TYPE_GRAY_4BIT = 1;
  static const TYPE_GRAY = 2;
  static const TYPE_GRAY_ALPHA = 3;
  static const TYPE_PALETTE = 4;
  static const TYPE_RGB = 5;
  static const TYPE_RGB_ALPHA = 6;
  static const TYPE_YCBCR_SUB = 7;
  static const TYPE_GENERIC = 8;

  // Sample Formats
  static const FORMAT_UINT = 1;
  static const FORMAT_INT = 2;
  static const FORMAT_FLOAT = 3;

  // Tag types
  static const TAG_ARTIST = 315;
  static const TAG_BITS_PER_SAMPLE = 258;
  static const TAG_CELL_LENGTH = 265;
  static const TAG_CELL_WIDTH = 264;
  static const TAG_COLOR_MAP = 320;
  static const TAG_COMPRESSION = 259;
  static const TAG_DATE_TIME = 306;
  static const TAG_EXIF_IFD = 34665;
  static const TAG_EXTRA_SAMPLES = 338;
  static const TAG_FILL_ORDER = 266;
  static const TAG_FREE_BYTE_COUNTS = 289;
  static const TAG_FREE_OFFSETS = 288;
  static const TAG_GRAY_RESPONSE_CURVE = 291;
  static const TAG_GRAY_RESPONSE_UNIT = 290;
  static const TAG_HOST_COMPUTER = 316;
  static const TAG_ICC_PROFILE = 34675;
  static const TAG_IMAGE_DESCRIPTION = 270;
  static const TAG_IMAGE_LENGTH = 257;
  static const TAG_IMAGE_WIDTH = 256;
  static const TAG_IPTC = 33723;
  static const TAG_MAKE = 271;
  static const TAG_MAX_SAMPLE_VALUE = 281;
  static const TAG_MIN_SAMPLE_VALUE = 280;
  static const TAG_MODEL = 272;
  static const TAG_NEW_SUBFILE_TYPE = 254;
  static const TAG_ORIENTATION = 274;
  static const TAG_PHOTOMETRIC_INTERPRETATION = 262;
  static const TAG_PHOTOSHOP = 34377;
  static const TAG_PLANAR_CONFIGURATION = 284;
  static const TAG_PREDICTOR = 317;
  static const TAG_RESOLUTION_UNIT = 296;
  static const TAG_ROWS_PER_STRIP = 278;
  static const TAG_SAMPLES_PER_PIXEL = 277;
  static const TAG_SOFTWARE = 305;
  static const TAG_STRIP_BYTE_COUNTS = 279;
  static const TAG_STRIP_OFFSETS = 273;
  static const TAG_SUBFILE_TYPE = 255;
  static const TAG_T4_OPTIONS = 292;
  static const TAG_T6_OPTIONS = 293;
  static const TAG_THRESHOLDING = 263;
  static const TAG_TILE_WIDTH = 322;
  static const TAG_TILE_LENGTH = 323;
  static const TAG_TILE_OFFSETS = 324;
  static const TAG_TILE_BYTE_COUNTS = 325;
  static const TAG_SAMPLE_FORMAT = 339;
  static const TAG_XMP = 700;
  static const TAG_X_RESOLUTION = 282;
  static const TAG_Y_RESOLUTION = 283;
  static const TAG_YCBCR_COEFFICIENTS = 529;
  static const TAG_YCBCR_SUBSAMPLING = 530;
  static const TAG_YCBCR_POSITIONING = 531;

  static const Map<int, String> TAG_NAME = {
    TAG_ARTIST: 'artist',
    TAG_BITS_PER_SAMPLE: 'bitsPerSample',
    TAG_CELL_LENGTH: 'cellLength',
    TAG_CELL_WIDTH: 'cellWidth',
    TAG_COLOR_MAP: 'colorMap',
    TAG_COMPRESSION: 'compression',
    TAG_DATE_TIME: 'dateTime',
    TAG_EXIF_IFD: 'exifIFD',
    TAG_EXTRA_SAMPLES: 'extraSamples',
    TAG_FILL_ORDER: 'fillOrder',
    TAG_FREE_BYTE_COUNTS: 'freeByteCounts',
    TAG_FREE_OFFSETS: 'freeOffsets',
    TAG_GRAY_RESPONSE_CURVE: 'grayResponseCurve',
    TAG_GRAY_RESPONSE_UNIT: 'grayResponseUnit',
    TAG_HOST_COMPUTER: 'hostComputer',
    TAG_ICC_PROFILE: 'iccProfile',
    TAG_IMAGE_DESCRIPTION: 'imageDescription',
    TAG_IMAGE_LENGTH: 'imageLength',
    TAG_IMAGE_WIDTH: 'imageWidth',
    TAG_IPTC: 'iptc',
    TAG_MAKE: 'make',
    TAG_MAX_SAMPLE_VALUE: 'maxSampleValue',
    TAG_MIN_SAMPLE_VALUE: 'minSampleValue',
    TAG_MODEL: 'model',
    TAG_NEW_SUBFILE_TYPE: 'newSubfileType',
    TAG_ORIENTATION: 'orientation',
    TAG_PHOTOMETRIC_INTERPRETATION: 'photometricInterpretation',
    TAG_PHOTOSHOP: 'photoshop',
    TAG_PLANAR_CONFIGURATION: 'planarConfiguration',
    TAG_PREDICTOR: 'predictor',
    TAG_RESOLUTION_UNIT: 'resolutionUnit',
    TAG_ROWS_PER_STRIP: 'rowsPerStrip',
    TAG_SAMPLES_PER_PIXEL: 'samplesPerPixel',
    TAG_SOFTWARE: 'software',
    TAG_STRIP_BYTE_COUNTS: 'stripByteCounts',
    TAG_STRIP_OFFSETS: 'stropOffsets',
    TAG_SUBFILE_TYPE: 'subfileType',
    TAG_T4_OPTIONS: 't4Options',
    TAG_T6_OPTIONS: 't6Options',
    TAG_THRESHOLDING: 'thresholding',
    TAG_TILE_WIDTH: 'tileWidth',
    TAG_TILE_LENGTH: 'tileLength',
    TAG_TILE_OFFSETS: 'tileOffsets',
    TAG_TILE_BYTE_COUNTS: 'tileByteCounts',
    TAG_XMP: 'xmp',
    TAG_X_RESOLUTION: 'xResolution',
    TAG_Y_RESOLUTION: 'yResolution',
    TAG_YCBCR_COEFFICIENTS: 'yCbCrCoefficients',
    TAG_YCBCR_SUBSAMPLING: 'yCbCrSubsampling',
    TAG_YCBCR_POSITIONING: 'yCbCrPositioning',
    TAG_SAMPLE_FORMAT: 'sampleFormat'
  };
}
