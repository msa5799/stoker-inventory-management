import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final Function(String) onBarcodeDetected;
  final String title;
  final String subtitle;

  const BarcodeScannerWidget({
    super.key,
    required this.onBarcodeDetected,
    this.title = 'Barkod Tarayıcı',
    this.subtitle = 'Barkodu kameranın önüne tutun',
  });

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isDetected = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isDetected) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final barcode = barcodes.first;
      if (barcode.rawValue != null) {
        setState(() {
          _isDetected = true;
        });
        
        // Vibration feedback
        // HapticFeedback.lightImpact();
        
        // Callback'i çağır
        widget.onBarcodeDetected(barcode.rawValue!);
        
        // Kısa bir delay sonra geri dön
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
        Navigator.pop(context, barcode.rawValue!);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => cameraController.toggleTorch(),
            icon: ValueListenableBuilder(
              valueListenable: cameraController.torchState,
              builder: (context, state, child) {
                switch (state) {
                  case TorchState.off:
                    return const Icon(Icons.flash_off, color: Colors.grey);
                  case TorchState.on:
                    return const Icon(Icons.flash_on, color: Colors.yellow);
                }
              },
            ),
          ),
          IconButton(
            onPressed: () => cameraController.switchCamera(),
            icon: ValueListenableBuilder(
              valueListenable: cameraController.cameraFacingState,
              builder: (context, state, child) {
                switch (state) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front);
                  case CameraFacing.back:
                    return const Icon(Icons.camera_rear);
                }
              },
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
          
          // Overlay
          Container(
            decoration: ShapeDecoration(
              shape: QrScannerOverlayShape(
                borderColor: Theme.of(context).primaryColor,
                borderRadius: 10,
                borderLength: 30,
                borderWidth: 10,
                cutOutSize: 250,
              ),
            ),
          ),
          
          // Instructions
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Barkod otomatik olarak algılanacaktır',
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          
          // Manual input button
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: () => _showManualInputDialog(),
              icon: const Icon(Icons.keyboard),
              label: const Text('Manuel Giriş'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualInputDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Barkod Manuel Giriş'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Barkod Numarası',
            hintText: 'Barkod numarasını girin',
          ),
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final barcode = controller.text.trim();
              if (barcode.isNotEmpty) {
                Navigator.pop(context); // Dialog'u kapat
                
                // Callback'i çağır
                widget.onBarcodeDetected(barcode);
                
                // Ana barcode scanner ekranını kapat ve barkodu döndür
                Future.delayed(Duration(milliseconds: 100), () {
                  if (mounted) {
                Navigator.pop(context, barcode);
                  }
                });
              }
            },
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}

// Custom overlay shape for QR scanner
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    double? cutOutSize,
  }) : cutOutSize = cutOutSize ?? 250;

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path _getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(rect.left, rect.top, rect.left + borderRadius, rect.top)
        ..lineTo(rect.right, rect.top);
    }

    return _getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderHeightSize = height / 2;
    final cutOutWidth = cutOutSize < width ? cutOutSize : width - borderWidth;
    final cutOutHeight = cutOutSize < height ? cutOutSize : height - borderWidth;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final cutOutRect = Rect.fromLTWH(
      rect.left + (width - cutOutWidth) / 2 + borderWidth,
      rect.top + (height - cutOutHeight) / 2 + borderWidth,
      cutOutWidth - borderWidth * 2,
      cutOutHeight - borderWidth * 2,
    );

    canvas
      ..saveLayer(
        rect,
        backgroundPaint,
      )
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndCorners(
          cutOutRect,
          topLeft: Radius.circular(borderRadius),
          topRight: Radius.circular(borderRadius),
          bottomLeft: Radius.circular(borderRadius),
          bottomRight: Radius.circular(borderRadius),
        ),
        Paint()..blendMode = BlendMode.clear,
      )
      ..restore();

    // Draw corner borders
    final borderOffset = borderWidth / 2;
    final _cutOutRect = Rect.fromLTWH(
      cutOutRect.left - borderOffset,
      cutOutRect.top - borderOffset,
      cutOutRect.width + borderWidth,
      cutOutRect.height + borderWidth,
    );

    final _borderLength = borderLength > _cutOutRect.width / 2 + borderWidth * 2
        ? borderWidthSize / 2
        : borderLength;
    final _borderHeight = borderLength > _cutOutRect.height / 2 + borderWidth * 2
        ? borderHeightSize / 2
        : borderLength;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(_cutOutRect.left, _cutOutRect.top + _borderHeight)
        ..lineTo(_cutOutRect.left, _cutOutRect.top + borderRadius)
        ..quadraticBezierTo(_cutOutRect.left, _cutOutRect.top,
            _cutOutRect.left + borderRadius, _cutOutRect.top)
        ..lineTo(_cutOutRect.left + _borderLength, _cutOutRect.top),
      boxPaint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(_cutOutRect.right - _borderLength, _cutOutRect.top)
        ..lineTo(_cutOutRect.right - borderRadius, _cutOutRect.top)
        ..quadraticBezierTo(_cutOutRect.right, _cutOutRect.top,
            _cutOutRect.right, _cutOutRect.top + borderRadius)
        ..lineTo(_cutOutRect.right, _cutOutRect.top + _borderHeight),
      boxPaint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(_cutOutRect.right, _cutOutRect.bottom - _borderHeight)
        ..lineTo(_cutOutRect.right, _cutOutRect.bottom - borderRadius)
        ..quadraticBezierTo(_cutOutRect.right, _cutOutRect.bottom,
            _cutOutRect.right - borderRadius, _cutOutRect.bottom)
        ..lineTo(_cutOutRect.right - _borderLength, _cutOutRect.bottom),
      boxPaint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(_cutOutRect.left + _borderLength, _cutOutRect.bottom)
        ..lineTo(_cutOutRect.left + borderRadius, _cutOutRect.bottom)
        ..quadraticBezierTo(_cutOutRect.left, _cutOutRect.bottom,
            _cutOutRect.left, _cutOutRect.bottom - borderRadius)
        ..lineTo(_cutOutRect.left, _cutOutRect.bottom - _borderHeight),
      boxPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
} 