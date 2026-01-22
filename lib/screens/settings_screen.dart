import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class SettingsScreen extends HookWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(8.0),
      child: Column(
        children: <Widget>[
          Card(
            child: ListTile(
              leading: Icon(Icons.notifications_sharp),
              title: Text('Settings 1'),
              subtitle: Text('This is a notification'),
            ),
          ),
          Card(
            child: ListTile(
              leading: Icon(Icons.notifications_sharp),
              title: Text('Settings 2'),
              subtitle: Text('This is a notification'),
            ),
          ),
        ],
      ),
    );
  }
}
