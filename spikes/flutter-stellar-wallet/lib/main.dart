import 'package:flutter/material.dart';
import 'freighter_bridge_web.dart';
import 'wallet_service.dart';

void main() => runApp(const MaterialApp(home: SpikePage()));

class SpikePage extends StatefulWidget {
  const SpikePage({super.key});
  @override
  State<SpikePage> createState() => _SpikePageState();
}

class _SpikePageState extends State<SpikePage> {
  late final FreighterWallet wallet = FreighterWallet(FreighterWebBridge());
  final xdr = TextEditingController();
  String output = 'Not connected';
  Future<void> run(Future<String> Function() action) async {
    try {
      output = await action();
    } catch (e) {
      output = '$e';
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Puls3 Stellar wallet spike')),
    body: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Text(
            'Testnet-only engineering harness. Never paste a secret key.',
          ),
          FilledButton(
            onPressed: () => run(() async => (await wallet.connect()).address),
            child: const Text('Connect Freighter'),
          ),
          TextField(
            controller: xdr,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Server-prepared transaction or auth-entry XDR',
            ),
          ),
          Wrap(
            spacing: 12,
            children: [
              FilledButton(
                onPressed: () => run(() => wallet.signTransaction(xdr.text)),
                child: const Text('Sign transaction'),
              ),
              OutlinedButton(
                onPressed: () => run(() => wallet.signAuthEntry(xdr.text)),
                child: const Text('Sign auth entry'),
              ),
            ],
          ),
          SelectableText(output),
        ],
      ),
    ),
  );
}
