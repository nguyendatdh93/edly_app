import 'package:edly/core/network/app_exception.dart';
import 'package:edly/pages/home/home_models.dart';
import 'package:edly/pages/ielts_packages/ielts_packages_models.dart';
import 'package:edly/pages/ielts_packages/ielts_packages_repository.dart';
import 'package:flutter/foundation.dart';

class IeltsPackagesController extends ChangeNotifier {
  IeltsPackagesController({IeltsPackagesRepository? repository})
    : _repository = repository ?? IeltsPackagesRepository.instance;

  final IeltsPackagesRepository _repository;

  IeltsPackagesData? data;
  bool isLoading = false;
  String? errorMessage;
  String? selectedSectionSlug;

  List<IeltsCollectionSection> get sections => data?.sections ?? const [];

  List<HomeCourseItem> get visibleCourses {
    final current = selectedSection;
    if (current != null) {
      return current.courses;
    }
    return data?.allCourses ?? const [];
  }

  IeltsCollectionSection? get selectedSection {
    final slug = selectedSectionSlug;
    if (slug == null || slug.isEmpty) {
      return null;
    }
    for (final section in sections) {
      if (section.slug == slug) {
        return section;
      }
    }
    return null;
  }

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      data = await _repository.fetchIeltsPackages();
    } on AppException catch (error) {
      errorMessage = error.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectSection(String? slug) {
    selectedSectionSlug = slug;
    notifyListeners();
  }
}
