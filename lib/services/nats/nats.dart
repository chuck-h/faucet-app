import 'dart:async';

import 'package:scanner/utils/delay.dart';
import 'package:dart_nats/dart_nats.dart';


class NatsService {
  static final NatsService _instance = NatsService._internal();
  factory NatsService() => _instance;
  static var _client = Client();
  NatsService._internal();

  Client get client => _client;

  Future<void> init({String servers = 'nats://localhost:4222'}) async {
    try {
      await _client.connect(Uri.parse(servers),
        timeout: 1, retryInterval: 1);
    } 
    catch (e) {
      print('nats connect error at ${servers}');
    }
    
  }

}
