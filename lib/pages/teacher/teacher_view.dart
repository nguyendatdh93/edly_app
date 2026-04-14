import 'package:flutter/material.dart';

class TeacherView extends StatelessWidget {
  const TeacherView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trang giáo viên'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nội dung dành cho giáo viên sẽ được cập nhật tại đây.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
