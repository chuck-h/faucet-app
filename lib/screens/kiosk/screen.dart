import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:scanner/router/bottom_tabs.dart';
import 'package:scanner/services/web3/utils.dart';
import 'package:scanner/state/app/logic.dart';
import 'package:scanner/state/app/state.dart';
import 'package:scanner/state/profile/logic.dart';
import 'package:scanner/state/profile/state.dart';
import 'package:scanner/state/scan/logic.dart';
import 'package:scanner/state/scan/state.dart';
import 'package:scanner/utils/strings.dart';
import 'package:scanner/widget/nfc_overlay.dart';
import 'package:scanner/widget/profile_chip.dart';
import 'package:scanner/widget/qr/qr.dart';

class KioskScreen extends StatefulWidget {
  const KioskScreen({super.key});

  @override
  State<KioskScreen> createState() => _KioskScreenState();
}

class _KioskScreenState extends State<KioskScreen> {
  final ScanLogic _scanLogic = ScanLogic();
  late AppLogic _appLogic;
  late ProfileLogic _profileLogic;

  bool _locked = true;
  bool _copied = false;

  @override
  void initState() {
    super.initState();

    _appLogic = AppLogic(context);
    _profileLogic = ProfileLogic(context);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // make initial requests here
      onLoad();
    });
  }

  void onLoad() {
    _profileLogic.loadProfile();
  }

  void handleCopy() {
    if (_copied) {
      return;
    }

    _scanLogic.copyVendorAddress();

    setState(() {
      _copied = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      setState(() {
        _copied = false;
      });
    });
  }

  Future<bool> handleCodeVerification() async {
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
              autofocus: true,
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

    /* quick hack for rpi testing
     *  modal bottom sheet keyboard doesn't display
    if (codeValue == null ||
        codeValue.isEmpty ||
        codeValue.length != 6 ||
        codeValue != '123987') {
      return false;
    }
    */
    return true;
  }

  void handleFaucetTopUp() async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final config = context.read<ScanState>().config;
    if (config == null) {
      return;
    }

    _scanLogic.listenToBalance();

    await showModalBottomSheet<void>(
      context: context,
      builder: (modalContext) {
        final vendorAddress = modalContext.watch<ScanState>().vendorAddress;
        final vendorBalance = modalContext.watch<ScanState>().vendorBalance;

        return Container(
          height: height,
          width: width,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Faucet',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              QR(
                data: vendorAddress ?? '0x',
                size: width - 120,
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: handleCopy,
                icon:
                    _copied ? const Icon(Icons.check) : const Icon(Icons.copy),
                label: Text(
                  formatLongText(vendorAddress ?? '0x'),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Balance: ',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$vendorBalance ${config.token.symbol}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    _scanLogic.stopListenToBalance();
  }

  void handleReadNFC() async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final address = await _scanLogic.read(
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
    final config = context.read<ScanState>().config;

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
              'Balance: ${balance ?? '0.0'} ${config?.token.symbol ?? ''}',
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

  void handleModifyAmount(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    TextEditingController amountController = TextEditingController();

    final amountValue = await showModalBottomSheet<String>(
      context: context,
      builder: (modalContext) => Container(
        height: height * 0.75,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            TextField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Amount',
              ),
              autofocus: true,
              maxLines: 1,
              autocorrect: false,
              enableSuggestions: false,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: false,
              ),
              textInputAction: TextInputAction.done,
            ),
            OutlinedButton.icon(
              onPressed: () {
                modalContext.pop(amountController.text);
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );

    if (amountValue == null || amountValue.isEmpty) {
      return;
    }

    _scanLogic.updateRedeemAmount(amountValue);
  }

  void handleWithdraw(BuildContext context) async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

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

    final success = await _scanLogic.withdraw(qrValue);
    if (!context.mounted) {
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

  void handleSetProfile() async {
    GoRouter.of(context).push('/kiosk/profile');
  }

  void handleUnlockAdminSection() async {
    final ok = await handleCodeVerification();
    if (!ok) {
      return;
    }

    setState(() {
      _locked = false;
    });
  }

  void handleMenuItemPress(BuildContext context, AppMode mode) {
    setState(() {
      _locked = true;
    });

    _appLogic.changeAppMode(mode);
  }

  void handleCancelScan() {
    _scanLogic.cancelScan();
  }

  @override
  Widget build(BuildContext context) {
    final mode = context.select((AppState s) => s.mode);

    final profile = context.watch<ProfileState>();

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              "Kiosk",
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: ProfileChip(
                                    name: profile.name.isEmpty
                                        ? 'Anonymous Kiosk'
                                        : profile.name,
                                    username: profile.username.isEmpty
                                        ? null
                                        : profile.username,
                                    image: profile.imageSmall.isEmpty
                                        ? null
                                        : profile.imageSmall,
                                    address: profile.account.isEmpty
                                        ? null
                                        : formatHexAddress(
                                            profile.account,
                                          ),
                                    onEdit: _locked ? null : handleSetProfile,
                                  ),
                                ),
                                const SizedBox(
                                  height: 40,
                                ),
                                FilledButton.icon(
                                  onPressed: handleFaucetTopUp,
                                  icon: const Icon(Icons.download),
                                  label: const Text(
                                    'Top up faucet',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                                FilledButton.icon(
                                  onPressed: handleReadNFC,
                                  icon: const Icon(Icons.nfc_rounded),
                                  label: const Text(
                                    'Read card balance',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_locked)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              ),
                              child: FilledButton.icon(
                                onPressed: handleUnlockAdminSection,
                                icon: const Icon(Icons.lock_open),
                                style: const ButtonStyle(
                                  backgroundColor:
                                      WidgetStatePropertyAll(Colors.black),
                                ),
                                label: const Text(
                                  'Unlock Admin Controls',
                                  style: TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          ),
                        if (!_locked)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  FilledButton.icon(
                                    onPressed: () =>
                                        handleModifyAmount(context),
                                    icon: const Icon(Icons.edit),
                                    style: const ButtonStyle(
                                      backgroundColor:
                                          WidgetStatePropertyAll(Colors.black),
                                    ),
                                    label: const Text(
                                      'Edit redeem amount',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  FilledButton.icon(
                                    onPressed: () => handleWithdraw(context),
                                    icon: const Icon(Icons.upload),
                                    style: const ButtonStyle(
                                      backgroundColor:
                                          WidgetStatePropertyAll(Colors.black),
                                    ),
                                    label: const Text(
                                      'Withdraw faucet',
                                      style: TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  const SizedBox(
                                    height: 60,
                                  ),
                                  const Text(
                                    'App Mode',
                                    style: TextStyle(fontSize: 24),
                                  ),
                                  const SizedBox(
                                    height: 8,
                                  ),
                                  PopupMenuButton<AppMode>(
                                    onSelected: (AppMode item) {
                                      handleMenuItemPress(context, item);
                                    },
                                    itemBuilder: (BuildContext context) =>
                                        AppMode.values
                                            .map<PopupMenuEntry<AppMode>>(
                                              (m) => PopupMenuItem<AppMode>(
                                                value: m,
                                                child: Text(m.label),
                                              ),
                                            )
                                            .toList(),
                                    child: Container(
                                      height: 40,
                                      // width: 180,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.grey,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              mode.label,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          const Icon(Icons.arrow_drop_down),
                                          const SizedBox(width: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: CustomBottomAppBar(
            logic: _scanLogic,
          ),
        ),
        NfcOverlay(
          onCancel: handleCancelScan,
        ),
      ],
    );
  }
}
