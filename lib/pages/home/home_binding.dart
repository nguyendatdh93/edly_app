import 'package:edly/pages/home/home_controller.dart';
import 'package:get/get.dart';

/// Binding khai báo nơi khởi tạo controller cho màn home.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
