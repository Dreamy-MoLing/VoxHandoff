import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Opens the QR scanner used by the M6 onboarding flow.
Future<String?> showQrPairingScanner(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute<String>(builder: (_) => const QrPairingScannerPage()),
    );

/// A scanner that keeps the camera stopped until the user explicitly starts it.
class QrPairingScannerPage extends StatefulWidget {
  const QrPairingScannerPage({this.controller, super.key});

  /// Injectable for widget tests; production callers use the default controller.
  @visibleForTesting
  final MobileScannerController? controller;

  @override
  State<QrPairingScannerPage> createState() => _QrPairingScannerPageState();
}

class _QrPairingScannerPageState extends State<QrPairingScannerPage> {
  late final MobileScannerController _controller =
      widget.controller ??
      MobileScannerController(
        autoStart: false,
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
  late final bool _ownsController = widget.controller == null;

  bool _isStarting = false;
  bool _isScanning = false;
  bool _hasReturnedResult = false;
  String? _errorMessage;

  Future<void> _startScanning() async {
    if (_isStarting || _isScanning || _hasReturnedResult) return;
    setState(() {
      _errorMessage = null;
      _isStarting = true;
    });
    try {
      await _controller.start();
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _isScanning = true;
      });
    } on MobileScannerException catch (error) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _isScanning = false;
        _errorMessage = _permissionSafeMessage(error);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _isScanning = false;
        _errorMessage = '相机暂时不可用，请检查权限后重试。';
      });
    }
  }

  Future<void> _stopScanning() async {
    if (!_isScanning && !_isStarting) return;
    await _controller.stop();
    if (!mounted) return;
    setState(() {
      _isStarting = false;
      _isScanning = false;
    });
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_hasReturnedResult) return;
    String? rawValue;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        rawValue = value;
        break;
      }
    }
    if (rawValue == null) return;

    _hasReturnedResult = true;
    unawaited(_controller.stop());
    if (mounted) Navigator.of(context).pop(rawValue);
  }

  String _permissionSafeMessage(MobileScannerException error) {
    final message = error.errorDetails?.message?.toLowerCase() ?? '';
    if (message.contains('permission') ||
        message.contains('authorized') ||
        message.contains('denied')) {
      return '需要相机权限才能扫描二维码。请在系统设置中允许后重试。';
    }
    return '相机暂时不可用，请检查权限后重试。';
  }

  @override
  void dispose() {
    unawaited(_controller.stop());
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描主机二维码'),
        leading: CloseButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _handleDetection,
                    errorBuilder: (context, error) => ColoredBox(
                      color: Colors.black,
                      child: Center(
                        child: Text(
                          '相机暂时不可用',
                          style: TextStyle(color: colors.onSurface),
                        ),
                      ),
                    ),
                  ),
                  if (!_isScanning && !_isStarting)
                    ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: _ScannerIntro(
                        errorMessage: _errorMessage,
                        onStart: _startScanning,
                      ),
                    ),
                  if (_isStarting)
                    ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: _isScanning
                  ? OutlinedButton.icon(
                      onPressed: _stopScanning,
                      icon: const Icon(Icons.stop_circle_outlined),
                      label: const Text('停止扫描'),
                    )
                  : Text(
                      '二维码只用于找到并认证这台主机，扫描后还需要主机确认。',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerIntro extends StatelessWidget {
  const _ScannerIntro({required this.errorMessage, required this.onStart});

  final String? errorMessage;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_scanner,
            size: 72,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 20),
          Text(
            '扫描电脑端显示的 VoxHandoff 二维码',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Text(
            '只有点击开始扫描后才会请求相机权限。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('开始扫描'),
          ),
        ],
      ),
    ),
  );
}
