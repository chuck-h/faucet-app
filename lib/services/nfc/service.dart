import 'dart:async';
import 'dart:convert';

import 'package:scanner/services/nats/nats.dart';
import 'package:scanner/utils/delay.dart';


class NFCService {
  Future<String> readSerialNumber(
      {String? message, String? successMessage}) async {
    final completer = Completer<String>();
    try {
      var ns = NatsService();
      var sub = ns.client.sub("local.nfcreadhex");
      await displayMessage(message);
      var rvbytes = (await sub.stream.timeout(const Duration(seconds: 10)).first).byte;
      ns.client.unSub(sub);
      completer.complete(utf8.decode(rvbytes));
    } on TimeoutException {
      completer.completeError(Exception("Waiting too long"));
    } catch (e) {
      completer.completeError(Exception("NFC nats error"));
    }
    return completer.future;
  }

  Future<void> displayMessage(String? message) async {
    final ns = NatsService();
    await ns.client.pubString("local.nfcpadshow", message ?? ""); //null message blanks screen
  }

  Future<void> stop() async {

  }
}
