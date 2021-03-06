import 'package:example/main.dart';
import 'package:fl_mlkit_text_recognize/fl_mlkit_text_recognize.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_waya/flutter_waya.dart';

class FlMlKitTextRecognizePage extends StatefulWidget {
  const FlMlKitTextRecognizePage({Key? key}) : super(key: key);

  @override
  State<FlMlKitTextRecognizePage> createState() =>
      _FlMlKitTextRecognizePageState();
}

class _FlMlKitTextRecognizePageState extends State<FlMlKitTextRecognizePage>
    with TickerProviderStateMixin {
  List<String> types =
      RecognizedLanguage.values.builder((item) => item.toString());

  late AnimationController animationController;
  AnalysisTextModel? model;

  ValueNotifier<bool> flashState = ValueNotifier<bool>(false);
  double maxRatio = 10;
  ValueNotifier<double> ratio = ValueNotifier<double>(1);

  ValueNotifier<FlMlKitTextRecognizeController?> textRecognizeController =
      ValueNotifier<FlMlKitTextRecognizeController?>(null);

  ///  The first rendering is null ，Using the rear camera
  CameraInfo? currentCamera;
  bool isBackCamera = true;

  ValueNotifier<bool> hasPreview = ValueNotifier<bool>(false);
  ValueNotifier<bool> canScan = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    animationController = AnimationController(vsync: this);
  }

  void listener() {
    if (!mounted) return;
    if (hasPreview.value != textRecognizeController.value!.hasPreview) {
      hasPreview.value = textRecognizeController.value!.hasPreview;
    }
    if (canScan.value != textRecognizeController.value!.canScan) {
      canScan.value = textRecognizeController.value!.canScan;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExtendedScaffold(
        onWillPop: () async {
          return false;
        },
        body: Stack(children: <Widget>[
          FlMlKitTextRecognize(
              recognizedLanguage: RecognizedLanguage.latin,
              frequency: 1000,
              camera: currentCamera,
              onCreateView: (FlMlKitTextRecognizeController controller) {
                textRecognizeController.value = controller;
                textRecognizeController.value!.addListener(listener);
              },
              onFlashChanged: (FlashState state) {
                showToast('$state');
                flashState.value = state == FlashState.on;
              },
              onZoomChanged: (CameraZoomState zoom) {
                showToast('zoom ratio:${zoom.zoomRatio}');
                maxRatio = zoom.maxZoomRatio ?? 10;
                ratio.value = zoom.zoomRatio ?? 1;
              },
              resolution: CameraResolution.veryHigh,
              autoScanning: true,
              fit: BoxFit.fitWidth,
              uninitialized: Container(
                  color: Colors.black,
                  alignment: Alignment.center,
                  child: const Text('Camera not initialized',
                      style: TextStyle(color: Colors.blueAccent))),
              onDataChanged: (AnalysisTextModel data) {
                if (data.text != null && data.text!.isNotEmpty) {
                  model = data;
                  animationController.reset();
                }
              }),
          AnimatedBuilder(
              animation: animationController,
              builder: (_, __) =>
                  model != null ? _RectBox(model!) : const SizedBox()),
          Universal(
              alignment: Alignment.bottomCenter,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[buildRatioSlider, buildFlashState]),
          Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                  width: 150,
                  height: 300,
                  child: ListWheel(
                      options: WheelOptions(
                          useMagnifier: true,
                          magnification: 1.5,
                          onChanged: (int index) {
                            textRecognizeController.value
                                ?.setRecognizedLanguage(
                                    RecognizedLanguage.values[index])
                                .then((value) {
                              showToast('setRecognizedLanguage:$value');
                            });
                          }),
                      childDelegateType: ListWheelChildDelegateType.builder,
                      itemBuilder: (_, int index) => Align(
                          alignment: Alignment.center,
                          child: BText(types[index].split('.')[1],
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      itemCount: types.length))),
          Positioned(
              right: 12,
              left: 12,
              top: getStatusBarHeight + 12,
              child: ValueListenableBuilder<FlMlKitTextRecognizeController?>(
                  valueListenable: textRecognizeController,
                  builder: (_, FlMlKitTextRecognizeController? controller, __) {
                    return controller == null
                        ? const SizedBox()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                                const BackButton(
                                    color: Colors.white, onPressed: pop),
                                Row(children: [
                                  ElevatedIcon(
                                      icon: Icons.flip_camera_ios,
                                      onPressed: switchCamera),
                                  const SizedBox(width: 12),
                                  previewButton(controller),
                                  const SizedBox(width: 12),
                                  canScanButton(controller),
                                ])
                              ]);
                  })),
        ]));
  }

  Widget get buildFlashState {
    return ValueListenableBuilder(
        valueListenable: flashState,
        builder: (_, bool state, __) {
          return IconBox(
              size: 30,
              color: state ? Colors.white : Colors.white.withOpacity(0.6),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 40),
              icon: state ? Icons.flash_on : Icons.flash_off,
              onTap: () {
                textRecognizeController.value
                    ?.setFlashMode(state ? FlashState.off : FlashState.on);
              });
        });
  }

  Widget get buildRatioSlider {
    return ValueListenableBuilder(
        valueListenable: ratio,
        builder: (_, double ratio, __) {
          return CupertinoSlider(
              value: ratio.floorToDouble(),
              min: 1,
              max: maxRatio,
              divisions: maxRatio.toInt(),
              onChanged: (double value) {
                textRecognizeController.value
                    ?.setZoomRatio(value.floorToDouble());
              });
        });
  }

  Widget canScanButton(FlMlKitTextRecognizeController scanningController) {
    return ValueListenableBuilder(
        valueListenable: canScan,
        builder: (_, bool value, __) {
          return ElevatedText(
              text: value ? 'pause' : 'start',
              onPressed: () async {
                value
                    ? await scanningController.pauseScan()
                    : await scanningController.startScan();
                model = null;
                animationController.reset();
              });
        });
  }

  Widget previewButton(FlMlKitTextRecognizeController scanningController) {
    return ValueListenableBuilder(
        valueListenable: hasPreview,
        builder: (_, bool hasPreview, __) {
          return ElevatedText(
              text: !hasPreview ? 'start' : 'stop',
              onPressed: () async {
                if (!hasPreview) {
                  if (scanningController.previousCamera != null) {
                    await scanningController
                        .startPreview(scanningController.previousCamera!);
                  }
                } else {
                  await scanningController.stopPreview();
                }
              });
        });
  }

  Future<void> switchCamera() async {
    if (textRecognizeController.value == null) return;
    for (final CameraInfo cameraInfo
        in textRecognizeController.value!.cameras!) {
      if (cameraInfo.lensFacing ==
          (isBackCamera ? CameraLensFacing.front : CameraLensFacing.back)) {
        currentCamera = cameraInfo;
        break;
      }
    }
    await textRecognizeController.value!.switchCamera(currentCamera!);
    isBackCamera = !isBackCamera;
  }

  @override
  void dispose() {
    super.dispose();
    animationController.dispose();
    textRecognizeController.dispose();
    hasPreview.dispose();
    canScan.dispose();
    ratio.dispose();
    flashState.dispose();
  }
}

class _RectBox extends StatelessWidget {
  const _RectBox(this.model, {Key? key}) : super(key: key);
  final AnalysisTextModel model;

  @override
  Widget build(BuildContext context) {
    final List<TextBlock> blocks = model.textBlocks ?? <TextBlock>[];
    final List<Widget> children = <Widget>[];
    for (final TextBlock block in blocks) {
      children.add(boundingBox(block.boundingBox!));
      children.add(corners(block.corners!));
    }
    return Universal(expand: true, isStack: true, children: children);
  }

  Widget boundingBox(Rect rect) {
    final double w = model.width! / getDevicePixelRatio;
    final double h = model.height! / getDevicePixelRatio;
    return Universal(
        alignment: Alignment.center,
        child: CustomPaint(size: Size(w, h), painter: _LinePainter(rect)));
  }

  Widget corners(List<Offset> corners) {
    final double w = model.width! / getDevicePixelRatio;
    final double h = model.height! / getDevicePixelRatio;
    return Universal(
        alignment: Alignment.center,
        child: CustomPaint(size: Size(w, h), painter: _BoxPainter(corners)));
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final Path path = Path();
    final double left = (rect.left) / getDevicePixelRatio;
    final double top = (rect.top) / getDevicePixelRatio;

    final double width = rect.width / getDevicePixelRatio;
    final double height = rect.height / getDevicePixelRatio;

    path.moveTo(left, top);
    path.lineTo(left + width, top);
    path.lineTo(left + width, height + top);
    path.lineTo(left, height + top);
    path.lineTo(left, top);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.corners);

  final List<Offset> corners;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset o0 = Offset(corners[0].dx / getDevicePixelRatio,
        corners[0].dy / getDevicePixelRatio);
    final Offset o1 = Offset(corners[1].dx / getDevicePixelRatio,
        corners[1].dy / getDevicePixelRatio);
    final Offset o2 = Offset(corners[2].dx / getDevicePixelRatio,
        corners[2].dy / getDevicePixelRatio);
    final Offset o3 = Offset(corners[3].dx / getDevicePixelRatio,
        corners[3].dy / getDevicePixelRatio);
    final Paint paint = Paint()
      ..color = Colors.blue.withOpacity(0.4)
      ..strokeWidth = 2;
    final Path path = Path();
    path.moveTo(o0.dx, o0.dy);
    path.lineTo(o1.dx, o1.dy);
    path.lineTo(o2.dx, o2.dy);
    path.lineTo(o3.dx, o3.dy);
    path.lineTo(o0.dx, o0.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
