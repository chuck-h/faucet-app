import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:scanner/screens/types_keyboard.dart';
import 'package:scanner/screens/keyboard_aux.dart';
import 'package:scanner/router/bottom_tabs.dart';
import 'package:scanner/services/nats/nats.dart';
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
import 'package:virtual_keyboard_custom_layout/virtual_keyboard_custom_layout.dart';


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
    final FocusNode _focusNode = FocusNode();

    final codeValue = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) => Container(
        height: height * 0.75,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            TextField(
              controller: codeController,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                labelText: 'Code',
              ),
              maxLines: 1,
              maxLength: 6,
              autocorrect: false,
              autofocus: true,
              enableSuggestions: false,
              /*keyboardType: const TextInputType.numberWithOptions(
                decimal: false,
                signed: false,
              ), */
              textInputAction: TextInputAction.done,
            ),
            OutlinedButton.icon(
              onPressed: () {
                modalContext.pop(codeController.text);
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Confirm'),
            ),
            MyVirtualKeyboard(),
          ],
        ),
      ),
      
    );

    if (codeValue == null ||
        codeValue.isEmpty ||
        codeValue.length != 6 ||
        codeValue != '123987') { // TODO: get unlock code from .env
      return false;
    }

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
      isScrollControlled: true,
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
      isScrollControlled: true,
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
      isScrollControlled: true,
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
      isScrollControlled: true,
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

  void handleWifiSetup(BuildContext context) async {
    await handleWifiEntry();
  }


  Future<void> handleWifiEntry() async {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    final ssidController = TextEditingController();
    final pwdController = TextEditingController();

    final FocusNode amountFocusNode = FocusNode();

    // ---------------- for virtual keyboard ----------------------------

    bool shiftEnabled = false;
    // is true will show the numeric keyboard.
    bool isNumericMode = false;

    // key variables to utilize the keyboard with the class KeyboardAux
    var isKeyboardVisible = false;
    var controllerKeyboard = TextEditingController();
    TypeLayout typeLayout = TypeLayout.numeric;


    final confirm = await showModalBottomSheet<bool?>(
      context: context,
      isScrollControlled: true,
      builder: (modalContext) {
        final keyboardHeight = 300.0;
        final config = modalContext.watch<ScanState>().config;
        return StatefulBuilder(builder: (BuildContext context, StateSetter wSetState) {
        return GestureDetector(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            isKeyboardVisible = false;
          },
          child: Container(
            height: 220 + keyboardHeight,
            width: width,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Wifi Configuration',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {
                        modalContext.pop(true);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Set',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ],
                ),
                TextField(
                  keyboardType: TextInputType.none,
                  controller: ssidController,
                  onTap: () {
                      wSetState(() {
                      isKeyboardVisible = true;
                      controllerKeyboard = ssidController;
                      typeLayout = TypeLayout.alphanum;
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'SSID',
                  ),
                  maxLines: 1,
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => amountFocusNode.requestFocus(),
                ),
                TextField(
                  keyboardType: TextInputType.none,
                  controller: pwdController,
                  onTap: () {
                    wSetState(() {
                      isKeyboardVisible = true;
                      controllerKeyboard = pwdController;
                      typeLayout = TypeLayout.alphanum;
                    });
                  },                  
                  decoration: InputDecoration(
                    labelText: 'Password',
                  ),
                  maxLines: 1,
                  maxLength: 25,
                  //obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  focusNode: amountFocusNode,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [],
                ),
                //const Spacer(),
                Expanded (
                  child: Container(),
                ),
                if (isKeyboardVisible)
                    KeyboardAux(
                      alwaysCaps: false,
                      controller: controllerKeyboard,
                      typeLayout: typeLayout,
                      typeKeyboard: VirtualKeyboardType.Custom,
                    ),
                  
              ],
            ),
          ),
        );
        });
      },
    );

    if (confirm != true) {
      //_logic.clearForm();
      return;
    }
    final ns = NatsService();
    //TODO: scramble pwd with key from .env [valid chars are 0x20-0x7e]
    await ns.client.pubString("local.wifisetup", "${ssidController.text}\t${pwdController.text}");
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
                                  FilledButton.icon(
                                    onPressed: () =>
                                        handleWifiSetup(context),
                                    icon: const Icon(Icons.edit),
                                    style: const ButtonStyle(
                                      backgroundColor:
                                          WidgetStatePropertyAll(Colors.black),
                                    ),
                                    label: const Text(
                                      'Set wifi connection',
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

class MyVirtualKeyboard extends StatefulWidget {
  const MyVirtualKeyboard({super.key});

  @override
  MyVirtualKeyboardState createState() => MyVirtualKeyboardState();
}

class MyVirtualKeyboardState extends State<MyVirtualKeyboard> {
  final MyTextInputControl _inputControl = MyTextInputControl();

  @override
  void initState() {
    super.initState();
    _inputControl.register();
  }

  @override
  void dispose() {
    super.dispose();
    _inputControl.unregister();
  }

  void _handleKeyPress(String key) {
    _inputControl.processUserInput(key);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _inputControl.visible,
      builder: (_, bool visible, __) {
        return Visibility(
          visible: visible,
          child: FocusScope(
            canRequestFocus: false,
            child: TextFieldTapRegion(
              child: Wrap(          
                //mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  for (final String key in <String>
                    ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫',])
                    ElevatedButton(
                      child: Text(key,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          //color: disabled ? Colors.grey : null,
                        ),
                      ),
                      onPressed: () => _handleKeyPress(key),
                    ),
                ],
              
             )  
            ),
          ),
        );
      },
    );
  }
}

class MyTextInputControl with TextInputControl {
  TextEditingValue _editingState = TextEditingValue.empty;
  final ValueNotifier<bool> _visible = ValueNotifier<bool>(false);

  /// The input control's visibility state for updating the visual presentation.
  ValueListenable<bool> get visible => _visible;

  /// Register the input control.
  void register() => TextInput.setInputControl(this);

  /// Restore the original platform input control.
  void unregister() => TextInput.restorePlatformInputControl();

  @override
  void show() => _visible.value = true;

  @override
  void hide() => _visible.value = false;

  @override
  void setEditingState(TextEditingValue value) => _editingState = value;

  /// Process user input.
  ///
  /// Updates the internal editing state by inserting the input text,
  /// and by replacing the current selection if any.
  void processUserInput(String input) {
    _editingState = _editingState.copyWith(
      text: _insertText(input),
      selection: _replaceSelection(input),
    );

    // Request the attached client to update accordingly.
    TextInput.updateEditingValue(_editingState);
  }

  String _insertText(String input) {
    final String text = _editingState.text;
    final TextSelection selection = _editingState.selection;
    if (input == '⌫') {
      final start = selection.start;
      if (start == 0) {
        return text;
      }
      return text.replaceRange(start-1, start, '');
    }
    return text.replaceRange(selection.start, selection.end, input);
  }

  TextSelection _replaceSelection(String input) {
    final TextSelection selection = _editingState.selection;
    if (input == '⌫') {
      return TextSelection.collapsed(offset: selection.start==0 ? 0 : selection.start-1);
    }
    return TextSelection.collapsed(offset: selection.start + input.length);
  }
}