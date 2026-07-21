import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:startup_launch/core/extensions/l10n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Text(context.l10n.homeTitle),
        actions: [
          IconButton(
            onPressed: () {
              context.push('/settings');
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: Center(child: Text(context.l10n.appName)),
    );
  }
}
