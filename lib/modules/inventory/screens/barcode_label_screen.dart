import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:barcode_widget/barcode_widget.dart';
import '../models/product.dart';
import '../services/barcode_label_service.dart';

class BarcodeLabelScreen extends StatefulWidget {
  final Product product;

  const BarcodeLabelScreen({super.key, required this.product});

  @override
  State<BarcodeLabelScreen> createState() => _BarcodeLabelScreenState();
}

class _BarcodeLabelScreenState extends State<BarcodeLabelScreen> {
  final _labelService = BarcodeLabelService();
  bool _busy = false;

  Future<void> _printLabel() async {
    setState(() => _busy = true);
    try {
      final file = await _labelService.generateLabel(widget.product);
      final bytes = await file.readAsBytes();
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareLabel() async {
    setState(() => _busy = true);
    try {
      final file = await _labelService.generateLabel(widget.product);
      await Share.shareXFiles([XFile(file.path)], text: 'ملصق باركود ${widget.product.name}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حصل خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final barcode = widget.product.barcode ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('باركود الصنف')),
      body: Stack(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('${widget.product.salePrice.toStringAsFixed(2)} ج'),
                  const SizedBox(height: 16),
                  if (barcode.isNotEmpty)
                    BarcodeWidget(
                      barcode: Barcode.ean13(),
                      data: barcode,
                      width: 220,
                      height: 90,
                      drawText: true,
                    ),
                ],
              ),
            ),
          ),
          if (_busy)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator())),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _shareLabel,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('مشاركة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _printLabel,
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('طباعة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
