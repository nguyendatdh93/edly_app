import 'package:edupen/pages/sign_up/sign_up_controller.dart';
import 'package:get/get.dart';

/// Binding khai báo nơi khởi tạo controller cho màn đăng ký.
class SignUpBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<SignUpController>(() => SignUpController());
  }
}
