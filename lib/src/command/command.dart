import 'dart:math';
import 'dart:typed_data';

import '../color/channel.dart';
import '../color/color.dart';
import '../color/format.dart';
import '../draw/blend_mode.dart';
import '../exif/exif_data.dart';
import '../filter/dither_image.dart';
import '../filter/noise.dart';
import '../filter/pixelate.dart';
import '../filter/quantize.dart';
import '../filter/separable_kernel.dart';
import '../font/bitmap_font.dart';
import '../formats/png_encoder.dart';
import '../image/icc_profile.dart';
import '../image/image.dart';
import '../image/interpolation.dart';
import '../image/palette.dart';
import '../transform/flip.dart';
import '../transform/trim.dart';
import '../util/_internal.dart';
import '../util/point.dart';
import '../util/quantizer.dart';
import 'draw/composite_image_cmd.dart';
import 'draw/draw_char_cmd.dart';
import 'draw/draw_circle_cmd.dart';
import 'draw/draw_line_cmd.dart';
import 'draw/draw_pixel_cmd.dart';
import 'draw/draw_polygon_cmd.dart';
import 'draw/draw_rect_cmd.dart';
import 'draw/draw_string_cmd.dart';
import 'draw/fill_circle_cmd.dart';
import 'draw/fill_cmd.dart';
import 'draw/fill_flood_cmd.dart';
import 'draw/fill_polygon_cmd.dart';
import 'draw/fill_rect_cmd.dart';
import 'executor.dart';
import 'filter/adjust_color_cmd.dart';
import 'filter/billboard_cmd.dart';
import 'filter/bleach_bypass_cmd.dart';
import 'filter/bulge_distortion_cmd.dart';
import 'filter/bump_to_normal_cmd.dart';
import 'filter/chromatic_aberration_cmd.dart';
import 'filter/color_halftone_cmd.dart';
import 'filter/color_offset_cmd.dart';
import 'filter/contrast_cmd.dart';
import 'filter/convolution_cmd.dart';
import 'filter/copy_image_channels_cmd.dart';
import 'filter/dither_image_cmd.dart';
import 'filter/dot_screen_cmd.dart';
import 'filter/drop_shadow_cmd.dart';
import 'filter/edge_glow_cmd.dart';
import 'filter/emboss_cmd.dart';
import 'filter/filter_cmd.dart';
import 'filter/gamma_cmd.dart';
import 'filter/gaussian_blur_cmd.dart';
import 'filter/grayscale_cmd.dart';
import 'filter/hdr_to_ldr_cmd.dart';
import 'filter/hexagon_pixelate_cmd.dart';
import 'filter/invert_cmd.dart';
import 'filter/luminance_threshold_cmd.dart';
import 'filter/monochrome_cmd.dart';
import 'filter/noise_cmd.dart';
import 'filter/normalize_cmd.dart';
import 'filter/pixelate_cmd.dart';
import 'filter/quantize_cmd.dart';
import 'filter/reinhard_tonemap_cmd.dart';
import 'filter/remap_colors_cmd.dart';
import 'filter/scale_rgba_cmd.dart';
import 'filter/separable_convolution_cmd.dart';
import 'filter/sepia_cmd.dart';
import 'filter/sketch_cmd.dart';
import 'filter/smooth_cmd.dart';
import 'filter/sobel_cmd.dart';
import 'filter/stretch_distortion_cmd.dart';
import 'filter/vignette_cmd.dart';
import 'formats/bmp_cmd.dart';
import 'formats/cur_cmd.dart';
import 'formats/decode_image_cmd.dart';
import 'formats/decode_image_file_cmd.dart';
import 'formats/decode_named_image_cmd.dart';
import 'formats/exr_cmd.dart';
import 'formats/gif_cmd.dart';
import 'formats/ico_cmd.dart';
import 'formats/jpg_cmd.dart';
import 'formats/png_cmd.dart';
import 'formats/psd_cmd.dart';
import 'formats/pvr_cmd.dart';
import 'formats/tga_cmd.dart';
import 'formats/tiff_cmd.dart';
import 'formats/webp_cmd.dart';
import 'formats/write_to_file_cmd.dart';
import 'image/add_frames_cmd.dart';
import 'image/convert_cmd.dart';
import 'image/copy_image_cmd.dart';
import 'image/create_image_cmd.dart';
import 'image/image_cmd.dart';
import 'transform/bake_orientation_cmd.dart';
import 'transform/copy_crop_circle_cmd.dart';
import 'transform/copy_crop_cmd.dart';
import 'transform/copy_flip_cmd.dart';
import 'transform/copy_rectify_cmd.dart';
import 'transform/copy_resize_cmd.dart';
import 'transform/copy_resize_crop_square_cmd.dart';
import 'transform/copy_rotate_cmd.dart';
import 'transform/flip_cmd.dart';
import 'transform/trim_cmd.dart';

/// Base class for commands that create, load, manipulate, and save images.
/// Commands are not executed until either the [execute] or [executeThread]
/// methods are called.
class Command {
  Command? input;
  Command? firstSubCommand;
  Command? _subCommand;
  bool dirty = true;

  /// Output Image generated by the command.
  Image? outputImage;

  /// Output bytes generated by the command.
  Uint8List? outputBytes;
  Object? outputObject;

  Command([this.input]);

  // Image commands

  /// Use a specific Image.
  void image(Image image) {
    subCommand = ImageCmd(subCommand, image);
  }

  /// Create an Image.
  void createImage(
      {required int width,
      required int height,
      Format format = Format.uint8,
      int numChannels = 3,
      bool withPalette = false,
      Format paletteFormat = Format.uint8,
      Palette? palette,
      ExifData? exif,
      IccProfile? iccp,
      Map<String, String>? textData}) {
    subCommand = CreateImageCmd(subCommand,
        width: width,
        height: height,
        format: format,
        numChannels: numChannels,
        withPalette: withPalette,
        paletteFormat: paletteFormat,
        palette: palette,
        exif: exif,
        iccp: iccp,
        textData: textData);
  }

  /// Convert an image by changing its format or number of channels.
  void convert(
      {int? numChannels,
      Format? format,
      num? alpha,
      bool withPalette = false}) {
    subCommand = ConvertCmd(subCommand,
        numChannels: numChannels,
        format: format,
        alpha: alpha,
        withPalette: withPalette);
  }

  /// Create a copy of the current image.
  void copy() {
    subCommand = CopyImageCmd(subCommand);
  }

  /// Add animation frames to an image.
  void addFrames(int count, AddFramesFunction callback) {
    subCommand = AddFramesCmd(subCommand, count, callback);
  }

  /// Call a callback for each frame of an animation.
  ///
  /// This is really the same thing as the filter Command, but makes the intent
  /// a bit clearer.
  void forEachFrame(FilterFunction callback) {
    subCommand = FilterCmd(subCommand, callback);
  }

  // Formats Commands

  void decodeImage(Uint8List data) {
    subCommand = DecodeImageCmd(subCommand, data);
  }

  void decodeNamedImage(String path, Uint8List data) {
    subCommand = DecodeNamedImageCmd(subCommand, path, data);
  }

  void decodeImageFile(String path) {
    subCommand = DecodeImageFileCmd(subCommand, path);
  }

  void writeToFile(String path) {
    subCommand = WriteToFileCmd(subCommand, path);
  }

  // Bmp
  void decodeBmp(Uint8List data) {
    subCommand = DecodeBmpCmd(subCommand, data);
  }

  void decodeBmpFile(String path) {
    subCommand = DecodeBmpFileCmd(subCommand, path);
  }

  void encodeBmp() {
    subCommand = EncodeBmpCmd(subCommand);
  }

  void encodeBmpFile(String path) {
    subCommand = EncodeBmpFileCmd(subCommand, path);
  }

  // Cur
  void encodeCur() {
    subCommand = EncodeCurCmd(subCommand);
  }

  void encodeCurFile(String path) {
    subCommand = EncodeCurFileCmd(subCommand, path);
  }

  // Exr
  void decodeExr(Uint8List data) {
    subCommand = DecodeExrCmd(subCommand, data);
  }

  void decodeExrFile(String path) {
    subCommand = DecodeExrFileCmd(subCommand, path);
  }

  // Gif
  void decodeGif(Uint8List data) {
    subCommand = DecodeGifCmd(subCommand, data);
  }

  void decodeGifFile(String path) {
    subCommand = DecodeGifFileCmd(subCommand, path);
  }

  void encodeGif(
      {int samplingFactor = 10,
      DitherKernel dither = DitherKernel.floydSteinberg,
      bool ditherSerpentine = false}) {
    subCommand = EncodeGifCmd(subCommand,
        samplingFactor: samplingFactor,
        dither: dither,
        ditherSerpentine: ditherSerpentine);
  }

  void encodeGifFile(String path,
      {int samplingFactor = 10,
      DitherKernel dither = DitherKernel.floydSteinberg,
      bool ditherSerpentine = false}) {
    subCommand = EncodeGifFileCmd(subCommand, path,
        samplingFactor: samplingFactor,
        dither: dither,
        ditherSerpentine: ditherSerpentine);
  }

  // Ico
  void decodeIco(Uint8List data) {
    subCommand = DecodeIcoCmd(subCommand, data);
  }

  void decodeIcoFile(String path) {
    subCommand = DecodeIcoFileCmd(subCommand, path);
  }

  void encodeIco() {
    subCommand = EncodeIcoCmd(subCommand);
  }

  void encodeIcoFile(String path) {
    subCommand = EncodeIcoFileCmd(subCommand, path);
  }

  // Jpeg
  void decodeJpg(Uint8List data) {
    subCommand = DecodeJpgCmd(subCommand, data);
  }

  void decodeJpgFile(String path) {
    subCommand = DecodeJpgFileCmd(subCommand, path);
  }

  void encodeJpg({int quality = 100}) {
    subCommand = EncodeJpgCmd(subCommand, quality: quality);
  }

  void encodeJpgFile(String path, {int quality = 100}) {
    subCommand = EncodeJpgFileCmd(subCommand, path, quality: quality);
  }

  // Png
  void decodePng(Uint8List data) {
    subCommand = DecodePngCmd(subCommand, data);
  }

  void decodePngFile(String path) {
    subCommand = DecodePngFileCmd(subCommand, path);
  }

  void encodePng({int level = 6, PngFilter filter = PngFilter.paeth}) {
    subCommand = EncodePngCmd(subCommand, level: level, filter: filter);
  }

  void encodePngFile(String path,
      {int level = 6, PngFilter filter = PngFilter.paeth}) {
    subCommand =
        EncodePngFileCmd(subCommand, path, level: level, filter: filter);
  }

  // Psd
  void decodePsd(Uint8List data) {
    subCommand = DecodePsdCmd(subCommand, data);
  }

  void decodePsdFile(String path) {
    subCommand = DecodePsdFileCmd(subCommand, path);
  }

  // Pvr
  void decodePvr(Uint8List data) {
    subCommand = DecodePvrCmd(subCommand, data);
  }

  void decodePvrFile(String path) {
    subCommand = DecodePvrFileCmd(subCommand, path);
  }

  void encodePvr() {
    subCommand = EncodePvrCmd(subCommand);
  }

  void encodePvrFile(String path) {
    subCommand = EncodePvrFileCmd(subCommand, path);
  }

  // Tga
  void decodeTga(Uint8List data) {
    subCommand = DecodeTgaCmd(subCommand, data);
  }

  void decodeTgaFile(String path) {
    subCommand = DecodeTgaFileCmd(subCommand, path);
  }

  void encodeTga() {
    subCommand = EncodeTgaCmd(subCommand);
  }

  void encodeTgaFile(String path) {
    subCommand = EncodeTgaFileCmd(subCommand, path);
  }

  // Tiff
  void decodeTiff(Uint8List data) {
    subCommand = DecodeTiffCmd(subCommand, data);
  }

  void decodeTiffFile(String path) {
    subCommand = DecodeTiffFileCmd(subCommand, path);
  }

  void encodeTiff() {
    subCommand = EncodeTiffCmd(subCommand);
  }

  void encodeTiffFile(String path) {
    subCommand = EncodeTiffFileCmd(subCommand, path);
  }

  // WebP
  void decodeWebP(Uint8List data) {
    subCommand = DecodeWebPCmd(subCommand, data);
  }

  void decodeWebPFile(String path) {
    subCommand = DecodeWebPFileCmd(subCommand, path);
  }

  // Draw Commands

  void drawChar(String char,
      {required BitmapFont font,
      required int x,
      required int y,
      Color? color,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = DrawCharCmd(subCommand, char,
        font: font,
        x: x,
        y: y,
        color: color,
        mask: mask,
        maskChannel: maskChannel);
  }

  void drawCircle(
      {required int x,
      required int y,
      required int radius,
      required Color color,
      bool antialias = false,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = DrawCircleCmd(subCommand,
        x: x,
        y: y,
        radius: radius,
        color: color,
        antialias: antialias,
        mask: mask,
        maskChannel: maskChannel);
  }

  void compositeImage(Command? src,
      {int? dstX,
      int? dstY,
      int? dstW,
      int? dstH,
      int? srcX,
      int? srcY,
      int? srcW,
      int? srcH,
      BlendMode blend = BlendMode.alpha,
      bool center = false,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = CompositeImageCmd(subCommand, src,
        dstX: dstX,
        dstY: dstY,
        dstW: dstW,
        dstH: dstH,
        srcX: srcX,
        srcY: srcY,
        srcW: srcW,
        srcH: srcH,
        blend: blend,
        center: center,
        mask: mask,
        maskChannel: maskChannel);
  }

  void drawLine(
      {required int x1,
      required int y1,
      required int x2,
      required int y2,
      required Color color,
      bool antialias = false,
      num thickness = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = DrawLineCmd(subCommand,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: color,
        antialias: antialias,
        thickness: thickness,
        mask: mask,
        maskChannel: maskChannel);
  }

  void drawPixel(int x, int y, Color color,
      {Command? mask, Channel maskChannel = Channel.luminance}) {
    subCommand = DrawPixelCmd(subCommand, x, y, color,
        mask: mask, maskChannel: maskChannel);
  }

  void drawPolygon(
      {required List<Point> vertices,
      required Color color,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = DrawPolygonCmd(subCommand,
        vertices: vertices, color: color, mask: mask, maskChannel: maskChannel);
  }

  void drawRect(
      {required int x1,
      required int y1,
      required int x2,
      required int y2,
      required Color color,
      num radius = 0,
      num thickness = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = DrawRectCmd(subCommand,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: color,
        radius: radius,
        thickness: thickness,
        mask: mask,
        maskChannel: maskChannel);
  }

  void drawString(String string,
      {required BitmapFont font,
      required int x,
      required int y,
      Color? color,
      bool wrap = false,
      bool rightJustify = false,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = DrawStringCmd(subCommand, string,
        font: font,
        x: x,
        y: y,
        color: color,
        wrap: wrap,
        rightJustify: rightJustify,
        mask: mask,
        maskChannel: maskChannel);
  }

  void fill(
      {required Color color,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand =
        FillCmd(subCommand, color: color, mask: mask, maskChannel: maskChannel);
  }

  void fillCircle(
      {required int x,
      required int y,
      required int radius,
      required Color color,
      bool antialias = false,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = FillCircleCmd(subCommand,
        x: x,
        y: y,
        radius: radius,
        color: color,
        antialias: antialias,
        mask: mask,
        maskChannel: maskChannel);
  }

  void fillFlood(
      {required int x,
      required int y,
      required Color color,
      num threshold = 0.0,
      bool compareAlpha = false,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = FillFloodCmd(subCommand,
        x: x,
        y: y,
        color: color,
        threshold: threshold,
        compareAlpha: compareAlpha,
        mask: mask,
        maskChannel: maskChannel);
  }

  void fillPolygon(
      {required List<Point> vertices,
      required Color color,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = FillPolygonCmd(subCommand,
        vertices: vertices, color: color, mask: mask, maskChannel: maskChannel);
  }

  void fillRect(
      {required int x1,
      required int y1,
      required int x2,
      required int y2,
      required Color color,
      num radius = 0,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = FillRectCmd(subCommand,
        x1: x1,
        y1: y1,
        x2: x2,
        y2: y2,
        color: color,
        radius: radius,
        mask: mask,
        maskChannel: maskChannel);
  }

  // Filter Commands

  void adjustColor(
      {Color? blacks,
      Color? whites,
      Color? mids,
      num? contrast,
      num? saturation,
      num? brightness,
      num? gamma,
      num? exposure,
      num? hue,
      num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = AdjustColorCmd(subCommand,
        blacks: blacks,
        whites: whites,
        mids: mids,
        contrast: contrast,
        saturation: saturation,
        brightness: brightness,
        gamma: gamma,
        exposure: exposure,
        hue: hue,
        amount: amount,
        mask: mask,
        maskChannel: maskChannel);
  }

  void billboard(
      {num grid = 10,
      num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = BillboardCmd(subCommand,
        grid: grid, amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void bleachBypass(
      {num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = BleachBypassCmd(subCommand,
        amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void bulgeDistortion(
      {int? centerX,
      int? centerY,
      num? radius,
      num scale = 0.5,
      Interpolation interpolation = Interpolation.nearest,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = BulgeDistortionCmd(subCommand,
        centerX: centerX,
        centerY: centerY,
        radius: radius,
        scale: scale,
        interpolation: interpolation,
        mask: mask,
        maskChannel: maskChannel);
  }

  void bumpToNormal({num strength = 2}) {
    subCommand = BumpToNormalCmd(subCommand, strength: strength);
  }

  void chromaticAberration(
      {int shift = 5, Command? mask, Channel maskChannel = Channel.luminance}) {
    subCommand = ChromaticAberrationCmd(subCommand,
        shift: shift, mask: mask, maskChannel: maskChannel);
  }

  void colorHalftone(
      {num amount = 1,
      int? centerX,
      int? centerY,
      num angle = 180,
      num size = 5,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = ColorHalftoneCmd(subCommand,
        amount: amount,
        centerX: centerX,
        centerY: centerY,
        angle: angle,
        size: size,
        mask: mask,
        maskChannel: maskChannel);
  }

  void colorOffset(
      {num red = 0,
      num green = 0,
      num blue = 0,
      num alpha = 0,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = ColorOffsetCmd(subCommand,
        red: red,
        green: green,
        blue: blue,
        alpha: alpha,
        mask: mask,
        maskChannel: maskChannel);
  }

  void contrast(
      {required num contrast,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = ContrastCmd(subCommand,
        contrast: contrast, mask: mask, maskChannel: maskChannel);
  }

  void convolution(
      {required List<num> filter,
      num div = 1.0,
      num offset = 0,
      num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = ConvolutionCmd(subCommand,
        filter: filter,
        div: div,
        offset: offset,
        amount: amount,
        mask: mask,
        maskChannel: maskChannel);
  }

  void copyImageChannels(
      {required Command? from,
      bool scaled = false,
      Channel? red,
      Channel? green,
      Channel? blue,
      Channel? alpha,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = CopyImageChannelsCmd(subCommand,
        from: from,
        scaled: scaled,
        red: red,
        green: green,
        blue: blue,
        alpha: alpha,
        mask: mask,
        maskChannel: maskChannel);
  }

  void ditherImage(
      {Quantizer? quantizer,
      DitherKernel kernel = DitherKernel.floydSteinberg,
      bool serpentine = false}) {
    subCommand = DitherImageCmd(subCommand,
        quantizer: quantizer, kernel: kernel, serpentine: serpentine);
  }

  void dotScreen(
      {num angle = 180,
      num size = 5.75,
      int? centerX,
      int? centerY,
      num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = DotScreenCmd(subCommand,
        angle: angle,
        size: size,
        centerX: centerX,
        centerY: centerY,
        amount: amount,
        mask: mask,
        maskChannel: maskChannel);
  }

  void dropShadow(int hShadow, int vShadow, int blur, {Color? shadowColor}) {
    subCommand = DropShadowCmd(subCommand, hShadow, vShadow, blur,
        shadowColor: shadowColor);
  }

  void edgeGlow(
      {num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = EdgeGlowCmd(subCommand,
        amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void emboss(
      {num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = EmbossCmd(subCommand,
        amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void gamma(
      {required num gamma,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = GammaCmd(subCommand,
        gamma: gamma, mask: mask, maskChannel: maskChannel);
  }

  void gaussianBlur(
      {required int radius,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = GaussianBlurCmd(subCommand,
        radius: radius, mask: mask, maskChannel: maskChannel);
  }

  void grayscale(
      {num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = GrayscaleCmd(subCommand,
        amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void hdrToLdr({num? exposure}) {
    subCommand = HdrToLdrCmd(subCommand, exposure: exposure);
  }

  void hexagonPixelate(
      {int? centerX,
      int? centerY,
      int size = 5,
      num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = HexagonPixelateCmd(subCommand,
        centerX: centerX,
        centerY: centerY,
        size: size,
        amount: amount,
        mask: mask,
        maskChannel: maskChannel);
  }

  void invert({Command? mask, Channel maskChannel = Channel.luminance}) {
    subCommand = InvertCmd(subCommand, mask: mask, maskChannel: maskChannel);
  }

  void luminanceThreshold(
      {num threshold = 0.5,
      bool outputColor = false,
      num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = LuminanceThresholdCmd(subCommand,
        threshold: threshold,
        outputColor: outputColor,
        amount: amount,
        mask: mask,
        maskChannel: maskChannel);
  }

  void monochrome(
      {Color? color,
      num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = MonochromeCmd(subCommand,
        color: color, amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void noise(num sigma,
      {NoiseType type = NoiseType.gaussian,
      Random? random,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = NoiseCmd(subCommand, sigma,
        type: type, random: random, mask: mask, maskChannel: maskChannel);
  }

  void normalize(
      {required num min,
      required num max,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = NormalizeCmd(subCommand,
        min: min, max: max, mask: mask, maskChannel: maskChannel);
  }

  void pixelate(
      {required int size,
      PixelateMode mode = PixelateMode.upperLeft,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = PixelateCmd(subCommand,
        size: size, mode: mode, mask: mask, maskChannel: maskChannel);
  }

  void quantize(
      {int numberOfColors = 256,
      QuantizeMethod method = QuantizeMethod.neuralNet,
      DitherKernel dither = DitherKernel.none,
      bool ditherSerpentine = false}) {
    subCommand = QuantizeCmd(subCommand,
        numberOfColors: numberOfColors,
        method: method,
        dither: dither,
        ditherSerpentine: ditherSerpentine);
  }

  void reinhardTonemap(
      {Command? mask, Channel maskChannel = Channel.luminance}) {
    subCommand =
        ReinhardTonemapCmd(subCommand, mask: mask, maskChannel: maskChannel);
  }

  void remapColors(
      {Channel red = Channel.red,
      Channel green = Channel.green,
      Channel blue = Channel.blue,
      Channel alpha = Channel.alpha}) {
    subCommand = RemapColorsCmd(subCommand,
        red: red, green: green, blue: blue, alpha: alpha);
  }

  void scaleRgba(
      {required Color scale,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = ScaleRgbaCmd(subCommand,
        scale: scale, mask: mask, maskChannel: maskChannel);
  }

  void separableConvolution(
      {required SeparableKernel kernel,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = SeparableConvolutionCmd(subCommand,
        kernel: kernel, mask: mask, maskChannel: maskChannel);
  }

  void sepia(
      {num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = SepiaCmd(subCommand,
        amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void sketch(
      {num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = SketchCmd(subCommand,
        amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void smooth(
      {required num weight,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = SmoothCmd(subCommand,
        weight: weight, mask: mask, maskChannel: maskChannel);
  }

  void sobel(
      {num amount = 1,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = SobelCmd(subCommand,
        amount: amount, mask: mask, maskChannel: maskChannel);
  }

  void stretchDistortion(
      {int? centerX,
      int? centerY,
      Interpolation interpolation = Interpolation.nearest,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = StretchDistortionCmd(subCommand,
        centerX: centerX,
        centerY: centerY,
        interpolation: interpolation,
        mask: mask,
        maskChannel: maskChannel);
  }

  void vignette(
      {num start = 0.3,
      num end = 0.75,
      Color? color,
      num amount = 0.8,
      Command? mask,
      Channel maskChannel = Channel.luminance}) {
    subCommand = VignetteCmd(subCommand,
        start: start,
        end: end,
        color: color,
        amount: amount,
        mask: mask,
        maskChannel: maskChannel);
  }

  /// Run an arbitrary function on the image within the Command graph.
  /// A FilterFunction is in the `form Image function(Image)`. A new Image
  /// can be returned, replacing the given Image; or the given Image can be
  /// returned.
  ///
  /// @example
  /// final image = Command()
  /// ..createImage(width: 256, height: 256)
  /// ..filter((image) {
  ///   for (final pixel in image) {
  ///     pixel.r = pixel.x;
  ///     pixel.g = pixel.y;
  ///   }
  ///   return image;
  /// })
  /// ..getImage();
  void filter(FilterFunction filter) {
    subCommand = FilterCmd(subCommand, filter);
  }

  // Transform Commands

  void bakeOrientation() {
    subCommand = BakeOrientationCmd(subCommand);
  }

  void copyCropCircle({int? radius, int? centerX, int? centerY}) {
    subCommand = CopyCropCircleCmd(subCommand,
        radius: radius, centerX: centerX, centerY: centerY);
  }

  void copyCrop(
      {required int x,
      required int y,
      required int width,
      required int height,
      num radius = 0}) {
    subCommand = CopyCropCmd(subCommand,
        x: x, y: y, width: width, height: height, radius: radius);
  }

  void copyFlip({required FlipDirection direction}) {
    subCommand = CopyFlipCmd(subCommand, direction: direction);
  }

  void copyRectify(
      {required Point topLeft,
      required Point topRight,
      required Point bottomLeft,
      required Point bottomRight,
      Interpolation interpolation = Interpolation.nearest}) {
    subCommand = CopyRectifyCmd(subCommand,
        topLeft: topLeft,
        topRight: topRight,
        bottomLeft: bottomLeft,
        bottomRight: bottomRight,
        interpolation: interpolation);
  }

  void copyResize(
      {int? width,
      int? height,
      Interpolation interpolation = Interpolation.nearest}) {
    subCommand = CopyResizeCmd(subCommand,
        width: width, height: height, interpolation: interpolation);
  }

  void copyResizeCropSquare(
      {required int size,
      num radius = 0,
      Interpolation interpolation = Interpolation.nearest}) {
    subCommand = CopyResizeCropSquareCmd(subCommand,
        size: size, radius: radius, interpolation: interpolation);
  }

  void copyRotate(
      {required num angle,
      Interpolation interpolation = Interpolation.nearest}) {
    subCommand =
        CopyRotateCmd(subCommand, angle: angle, interpolation: interpolation);
  }

  void flip({required FlipDirection direction}) {
    subCommand = FlipCmd(subCommand, direction: direction);
  }

  void trim({TrimMode mode = TrimMode.transparent, Trim sides = Trim.all}) {
    subCommand = TrimCmd(subCommand, mode: mode, sides: sides);
  }

  //

  Future<Command> execute() async {
    await subCommand.executeIfDirty();
    if (_subCommand != null) {
      outputImage = _subCommand!.outputImage;
      outputBytes = _subCommand!.outputBytes;
      outputObject = _subCommand!.outputObject;
    }
    return this;
  }

  Future<Command> executeThread() async {
    final cmdOrThis = subCommand;
    if (cmdOrThis.dirty) {
      await executeCommandAsync(cmdOrThis).then((value) {
        cmdOrThis
          ..dirty = false
          ..outputImage = value.image
          ..outputBytes = value.bytes
          ..outputObject = value.object;
        if (_subCommand != null) {
          outputImage = _subCommand!.outputImage;
          outputBytes = _subCommand!.outputBytes;
          outputObject = _subCommand!.outputObject;
        }
      });
    }
    return this;
  }

  Future<Image?> getImage() async {
    await execute();
    return subCommand.outputImage;
  }

  Future<Image?> getImageThread() async {
    await executeThread();
    return outputImage;
  }

  Future<Uint8List?> getBytes() async {
    await execute();
    return outputBytes;
  }

  Future<Uint8List?> getBytesThread() async {
    await executeThread();
    return outputBytes;
  }

  @internal
  Future<void> executeIfDirty() async {
    if (dirty) {
      dirty = false;
      await executeCommand();
    }
  }

  @internal
  Future<void> executeCommand() async {}

  @internal
  Command get subCommand => _subCommand ?? this;

  @internal
  set subCommand(Command? cmd) {
    _subCommand = cmd;
    firstSubCommand ??= cmd;
  }

  void setDirty() {
    dirty = true;
    var cmd = _subCommand;
    while (cmd != null) {
      cmd.dirty = true;
      cmd = cmd.input;
    }
  }
}
