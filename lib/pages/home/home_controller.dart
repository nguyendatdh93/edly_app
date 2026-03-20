import 'package:get/get.dart';

/// Controller giữ state đơn giản cho home preview.
class HomeController extends GetxController {
  final RxInt currentSlide = 0.obs;

  void setSlide(int index) {
    currentSlide.value = index;
  }
}
