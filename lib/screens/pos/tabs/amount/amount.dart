import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scanner/services/config/config.dart';
import 'package:scanner/state/amount/logic.dart';
import 'package:scanner/state/amount/selectors.dart';
import 'package:scanner/state/amount/state.dart';
import 'package:scanner/state/scan/state.dart';

class AmountTab extends StatefulWidget {
  final Config config;

  const AmountTab({super.key, required this.config});

  @override
  AmountTabState createState() => AmountTabState();
}

class AmountTabState extends State<AmountTab> {
  late AmountLogic _logic;

  @override
  void initState() {
    super.initState();

    _logic = AmountLogic(context);
  }

  final List<String> keys = [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '',
    '0',
    '⌫',
  ];

  bool shouldDisableKey(String key, List<String> pressedKeys) {
    if (pressedKeys.every((k) => k == '0')) {
      return [
        '',
        '0',
        '⌫',
      ].contains(key);
    }

    return false;
  }

  void handleKeyPress(String key) {
    // Handle key press
    if (key == '') {
      return;
    }
    _logic.keyPress(key);
  }

  void h(int i, String v) {}

  @override
  Widget build(BuildContext context) {
    final config = widget.config;

    final pressedKeys = context.watch<AmountState>().pressedKeys;

    final amount = context.select(selectFormattedAmount);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 0, // Set toolbar height to 0 to remove the title
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Column(
            children: [
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                      child: Text(
                        config?.token.symbol ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      amount,
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    Text(
                      config?.token.symbol ?? '',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [ Container( 
                    width: MediaQuery.of(context).size.width * 0.75,
                    child:
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 4.0,
                      crossAxisSpacing: 16.0,
                      padding: const EdgeInsets.all(16.0),
                      children: keys.map(
                        (key) {
                          final disabled = shouldDisableKey(key, pressedKeys);

                          return TextButton(
                            onPressed: disabled
                                ? null
                                : () {
                                    // Handle button press
                                    handleKeyPress(key);
                                  },
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                            child: Text(
                              key,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: disabled ? Colors.grey : null,
                              ),
                            ),
                          );
                        },
                      ).toList(),
                    ),
                  ),
                  ],
                ),
              ),
              const SizedBox(
                height: 60,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
