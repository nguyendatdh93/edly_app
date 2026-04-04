import 'package:edupen/app.dart';
import 'package:edupen/core/config/flavor_config.dart';
import 'package:flutter/material.dart';

void bootstrapApp(AppFlavor flavor) {
  WidgetsFlutterBinding.ensureInitialized();
  FlavorConfig.initialize(flavor);
  runApp(const EdlyApp());
}
