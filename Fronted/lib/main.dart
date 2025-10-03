import 'dart:async';
import 'dart:io'; // Needed for File
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart'; // For saving images

// Global variable to store available cameras
late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent system UI immersive mode
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error initializing cameras: $e');
    cameras = [];
  }

  runApp(const ShopLensApp());
}

class ShopLensApp extends StatelessWidget {
  const ShopLensApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(scaffoldBackgroundColor: Colors.black),
      debugShowCheckedModeBanner: false,
      home: cameras.isNotEmpty ? CameraScreen() : const NoCameraScreen(),
    );
  }
}

class NoCameraScreen extends StatelessWidget {
  const NoCameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          "No camera found on device.",
          style: TextStyle(color: Colors.redAccent, fontSize: 18),
        ),
      ),
    );
  }
}

// Footer height for camera controls
const double _kControlPanelHeight = 160.0;

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  double _zoomLevel = 1.0;
  double _minZoom = 1.0;
  double _maxZoom = 5.0;
  bool _isFlashOn = false;
  int _cameraIndex = 0;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera(_cameraIndex);
  }

  Future<void> _initCamera(int index) async {
    if (cameras.isEmpty) return;

    _controller = CameraController(
      cameras[index],
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    try {
      await _controller.initialize();
      _minZoom = await _controller.getMinZoomLevel();
      _maxZoom = await _controller.getMaxZoomLevel();
      await _controller.setZoomLevel(_minZoom);
      _zoomLevel = _minZoom;
    } on CameraException catch (e) {
      print('Camera initialization error: $e');
    }

    if (mounted) setState(() {});
  }

  Future<void> _toggleFlash() async {
    if (!_controller.value.isInitialized) return;
    _isFlashOn = !_isFlashOn;
    await _controller
        .setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    if (cameras.length <= 1) return;
    _cameraIndex = (_cameraIndex + 1) % cameras.length;
    await _initCamera(_cameraIndex);
  }

  Future<void> _takePicture() async {
    if (!_controller.value.isInitialized || _controller.value.isTakingPicture) {
      print("Camera not ready or already taking a picture.");
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final image = await _controller.takePicture();
      print("Captured: ${image.path}");

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PreviewScreen(imagePath: image.path),
          ),
        );
      }
    } on CameraException catch (e) {
      print("Error capturing image: $e");
    }
    setState(() => _isCapturing = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.cyanAccent)),
      );
    }

    final size = MediaQuery.of(context).size;
    final mediaPadding = MediaQuery.of(context).padding;
    final cameraAreaHeight =
        size.height - mediaPadding.top - mediaPadding.bottom - _kControlPanelHeight;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera Preview
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: cameraAreaHeight,
            child: CameraPreview(_controller),
          ),

          // Futuristic overlay
          Positioned(
            top: mediaPadding.top,
            left: 0,
            right: 0,
            height: cameraAreaHeight,
            child: FuturisticOverlay(
              cameraAreaHeight: cameraAreaHeight,
              topPadding: mediaPadding.top,
            ),
          ),

          // Top instructions
          Positioned(
            top: mediaPadding.top + 15,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                gradient: LinearGradient(
                  colors: [
                    Colors.cyanAccent.withOpacity(0.2),
                    Colors.blueAccent.withOpacity(0.3)
                  ],
                ),
                border: Border.all(color: Colors.cyanAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.6),
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.qr_code_scanner, color: Colors.cyanAccent),
                  SizedBox(width: 8),
                  Text(
                    "🔍 ShopLens Scanner\nAlign the product inside the frame",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      shadows: [
                        Shadow(
                          blurRadius: 10,
                          color: Colors.blueAccent,
                          offset: Offset(1, 1),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer controls
          Positioned(
            bottom: mediaPadding.bottom,
            left: 0,
            right: 0,
            child: Container(
              height: _kControlPanelHeight,
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                children: [
                  // Zoom Slider
                  Row(
                    children: [
                      const Icon(Icons.zoom_out, color: Colors.cyanAccent),
                      Expanded(
                        child: Slider(
                          value: _zoomLevel,
                          min: _minZoom,
                          max: _maxZoom,
                          activeColor: Colors.cyanAccent,
                          inactiveColor: Colors.cyanAccent.withOpacity(0.3),
                          onChanged: (value) async {
                            setState(() => _zoomLevel = value);
                            await _controller.setZoomLevel(value);
                          },
                        ),
                      ),
                      const Icon(Icons.zoom_in, color: Colors.cyanAccent),
                    ],
                  ),
                  const Spacer(),
                  // Flash - Capture - Switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isFlashOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.cyanAccent,
                          size: 32,
                        ),
                        onPressed: _toggleFlash,
                      ),
                      GestureDetector(
                        onTap: _isCapturing ? null : _takePicture,
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: _isCapturing
                                ? Colors.cyanAccent.withOpacity(0.5)
                                : Colors.cyanAccent,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.cyanAccent.withOpacity(0.7),
                                blurRadius: 20,
                                spreadRadius: 5,
                              )
                            ],
                          ),
                          child: const Icon(Icons.camera, color: Colors.black, size: 32),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cameraswitch,
                            color: Colors.cyanAccent, size: 32),
                        onPressed: _switchCamera,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Preview Screen with Retake and Save
class PreviewScreen extends StatelessWidget {
  final String imagePath;

  const PreviewScreen({required this.imagePath, super.key});

  Future<void> _saveImage(BuildContext context) async {
    try {
      final directory = await getTemporaryDirectory();
      final fileName = 'ShopLens_${DateTime.now().millisecondsSinceEpoch}.png';
      final newPath = '${directory.path}/$fileName';
      final imageFile = File(imagePath);
      await imageFile.copy(newPath);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image saved successfully!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save image.")),
      );
      print("Save error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text("Captured Image"),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Image.file(
                File(imagePath),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Retake
                  },
                  child: const Text("Retake"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                  ),
                  onPressed: () => _saveImage(context), // Save
                  child: const Text("Save"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Futuristic overlay widget
class FuturisticOverlay extends StatefulWidget {
  final double cameraAreaHeight;
  final double topPadding;

  const FuturisticOverlay({
    required this.cameraAreaHeight,
    required this.topPadding,
    super.key,
  });

  @override
  _FuturisticOverlayState createState() => _FuturisticOverlayState();
}

class _FuturisticOverlayState extends State<FuturisticOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);

    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double frameSize = 280;

    return IgnorePointer(
      child: Stack(
        children: [
          // Glowing frame
          Center(
            child: Container(
              width: frameSize,
              height: frameSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.cyanAccent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.cyanAccent.withOpacity(0.6),
                    blurRadius: 20,
                    spreadRadius: 2,
                  )
                ],
              ),
            ),
          ),
          // Laser line
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              final centerOfCameraArea = widget.cameraAreaHeight / 2;
              final topPosition = centerOfCameraArea -
                  (frameSize / 2) +
                  (frameSize * _animation.value);

              return Positioned(
                top: widget.topPadding + topPosition,
                left: MediaQuery.of(context).size.width / 2 - frameSize / 2,
                child: Container(
                  width: frameSize,
                  height: 2,
                  color: Colors.cyanAccent,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
