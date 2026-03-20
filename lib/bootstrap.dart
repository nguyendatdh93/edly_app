import 'package:edly/app.dart';
import 'package:edly/core/config/flavor_config.dart';
import 'package:flutter/material.dart';

void bootstrapApp(AppFlavor flavor) {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initialize(flavor);
  runApp(const EdlyApp());
}
