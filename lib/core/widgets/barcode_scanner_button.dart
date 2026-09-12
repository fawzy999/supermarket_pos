import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// شاشة مسح باركود عامة - بترجع النص الممسوح عند النجاح
/// الاستخدام:
///   final barcode = await Navigator.push(context,
///     MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()));
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('امسح الباركود')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}

/// زرار جاهز يفتح شاشة المسح ويرجع القيمة مباشرة لحقل نصي
class BarcodeScanButton extends StatelessWidget {
  final void Function(String barcode) onScanned;

  const BarcodeScanButton({super.key, required this.onScanned});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.qr_code_scanner),
      tooltip: 'مسح باركود',
      onPressed: () async {
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
        );
        if (result != null) onScanned(result);
      },
    );
  }
}
