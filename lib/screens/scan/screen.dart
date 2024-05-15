import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:scanner/state/products/state.dart';
import 'package:scanner/state/scan/logic.dart';
import 'package:scanner/state/scan/state.dart';
import 'package:scanner/utils/currency.dart';
import 'package:scanner/utils/strings.dart';
import 'package:scanner/widget/qr/qr.dart';

enum MenuOption { withdraw, readCardBalance }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late ScanLogic _logic;

  bool _copied = false;

  @override
  void initState() {
    super.initState();

    _logic = ScanLogic(context);

    WidgetsBinding.instance.addObserver(_logic);

    // wait for first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logic.init();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_logic);

    super.dispose();
  }

  void handleRedeem() async {
    await _logic.redeem();
  }

  void handleCopy() {
    if (_copied) {
      return;
    }

    _logic.copyVendorAddress();

    setState(() {
      _copied = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _copied = false;
      });
    });
  }

  void handleWithdraw(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    TextEditingController codeController = TextEditingController();

    final codeValue = await showModalBottomSheet<String>(
      context: context,
      builder: (modalContext) => Container(
        height: height * 0.75,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code',
              ),
              maxLines: 1,
              maxLength: 6,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ),
              textInputAction: TextInputAction.done,
            ),
            OutlinedButton.icon(
              onPressed: () {
                modalContext.pop(codeController.text);
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (codeValue == null ||
        codeValue.isEmpty ||
        codeValue.length != 6 ||
        codeValue != '123987') {
      return;
    }

    final qrValue = await showModalBottomSheet<String>(
      context: context,
      builder: (modalContext) => SizedBox(
        height: height / 2,
        width: width,
        child: MobileScanner(
          // fit: BoxFit.contain,
          controller: MobileScannerController(
            detectionSpeed: DetectionSpeed.normal,
            facing: CameraFacing.back,
            torchEnabled: false,
            formats: <BarcodeFormat>[BarcodeFormat.qrCode],
          ),
          onDetect: (capture) {
            final List<Barcode> barcodes = capture.barcodes;
            for (final barcode in barcodes) {
              debugPrint('Barcode found! ${barcode.rawValue}');
              modalContext.pop(barcode.rawValue);
              break;
            }
          },
        ),
      ),
    );

    if (qrValue == null) {
      return;
    }

    final success = await _logic.withdraw(qrValue);
    if (!mounted) {
      return;
    }
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to withdraw'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Withdrawing funds...'),
      ),
    );
  }

  void handleMenuItemPress(BuildContext context, MenuOption item) {
    switch (item) {
      case MenuOption.withdraw:
        handleWithdraw(context);
        break;
      case MenuOption.readCardBalance:
        handleReadNFC();
        break;
    }
  }

  void handleTopUp() async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final address = await _logic.read(
      message: 'Scan to display top up link',
      successMessage: 'Card scanned',
    );
    if (address == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    showModalBottomSheet<String>(
      context: context,
      builder: (modalContext) => Container(
        height: height * 0.75,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Scan to top up your wallet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            QR(
              data:
                  'https://topup.citizenspring.earth/WOLU.base?account=$address&redirectUrl=https://nfcwallet.xyz',
              size: width - 80,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 60,
              child: Text(
                'https://topup.citizenspring.earth/WOLU.base?account=$address',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void handleReadNFC() async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final address = await _logic.read(
      message: 'Scan to display balance',
      successMessage: 'Card scanned',
    );
    if (address == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    final balance = context.read<ScanState>().nfcBalance;

    showModalBottomSheet<String>(
      context: context,
      builder: (modalContext) => Container(
        height: height * 0.75,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Your card',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            QR(data: address, size: width - 80),
            const SizedBox(height: 16),
            Text(
              'Balance: ${balance ?? '0.0'} WOLU',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Address: ${formatLongText(address)}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<ScanState>().loading;

    final ready = context.watch<ScanState>().ready;

    final vendorAddress = context.watch<ScanState>().vendorAddress;
    final vendorBalance = context.watch<ScanState>().vendorBalance;
    final redeemBalance = context.watch<ScanState>().redeemBalance;
    final redeemAmount = context.watch<ScanState>().redeemAmount;

    final insufficientBalance = context.watch<ScanState>().insufficientBalance;

    final config = context.select((ScanState s) => s.config);

    final status = context.select((ScanState s) => s.status);
    final statusError = context.select((ScanState s) => s.statusError);

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: !loading ? const Text('Faucet') : null,
          actions: [
            PopupMenuButton<MenuOption>(
              onSelected: (MenuOption item) {
                handleMenuItemPress(context, item);
              },
              itemBuilder: (BuildContext context) =>
                  <PopupMenuEntry<MenuOption>>[
                const PopupMenuItem<MenuOption>(
                  value: MenuOption.withdraw,
                  child: Text('Withdraw'),
                ),
                const PopupMenuItem<MenuOption>(
                  value: MenuOption.readCardBalance,
                  child: Text('Read card balance'),
                ),
              ],
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                if (loading)
                  const Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Preparing faucet...',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!loading && vendorAddress != null)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          QR(data: vendorAddress),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: handleCopy,
                            icon: _copied
                                ? const Icon(Icons.check)
                                : const Icon(Icons.copy),
                            label: Text(
                              formatLongText(vendorAddress),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Balance',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${config?.token.symbol ?? ''} $vendorBalance',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!loading && vendorAddress != null)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Opacity(
                              opacity: ready ? 1 : 0.5,
                              child: FilledButton(
                                onPressed: ready ? handleRedeem : null,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.nfc),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Redeem $redeemAmount ${config?.token.symbol ?? ''}',
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...(switch (status) {
                            ScanStateType.loading => [
                                const Text(
                                  'Loading',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ScanStateType.ready => [
                                Text(
                                  insufficientBalance
                                      ? 'Faucet empty'
                                      : 'Ready',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ScanStateType.notReady => [
                                const Text(
                                  'Not ready',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ScanStateType.readingNFC => [
                                const Text(
                                  'Reading tag...',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ScanStateType.error => [
                                const Text(
                                  'An error occurred',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  statusError,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            _ => [
                                Text(
                                  switch (status) {
                                    ScanStateType.verifying => 'Redeemed',
                                    ScanStateType.verified => 'Confirmed',
                                    _ => 'Redeeming...',
                                  },
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      height: 20,
                                      width: 20,
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.greenAccent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 500),
                                      height: 20,
                                      width: 20,
                                      decoration: BoxDecoration(
                                        color: status == ScanStateType.redeeming
                                            ? Colors.greenAccent.withOpacity(0)
                                            : Colors.greenAccent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.greenAccent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 500),
                                      height: 20,
                                      width: 20,
                                      decoration: BoxDecoration(
                                        color: status ==
                                                    ScanStateType.redeeming ||
                                                status ==
                                                    ScanStateType.verifying
                                            ? Colors.greenAccent.withOpacity(0)
                                            : Colors.greenAccent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.greenAccent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Current balance: $redeemBalance',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ]
                          }),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
