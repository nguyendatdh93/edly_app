import 'package:edupen/core/network/app_exception.dart';
import 'package:edupen/pages/home/home_models.dart';
import 'package:edupen/pages/sat_packages/sat_packages_models.dart';
import 'package:edupen/pages/sat_packages/sat_packages_repository.dart';
import 'package:flutter/foundation.dart';

class SatPackagesController extends ChangeNotifier {
  SatPackagesController({SatPackagesRepository? repository})
    : _repository = repository ?? SatPackagesRepository.instance;

  final SatPackagesRepository _repository;

  SatPackagesData? data;
  bool isLoading = false;
  String? errorMessage;
  String? selectedSectionSlug;

  List<SatCollectionSection> get sections => data?.sections ?? const [];

  List<HomeCourseItem> get visibleCourses {
    final current = selectedSection;
    if (current != null) {
      return current.courses;
    }
    return data?.allCourses ?? const [];
  }

  SatCollectionSection? get selectedSection {
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
      data = await _repository.fetchSatPackages();
    } on AppException catch (error) {
      errorMessage = error.message;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectSection(String? slug) {
    final normalized = slug?.trim();
    if (normalized == null || normalized.isEmpty) {
      selectedSectionSlug = null;
      notifyListeners();
      return;
    }

    for (final section in sections) {
      if (section.slug.toLowerCase() == normalized.toLowerCase()) {
        selectedSectionSlug = section.slug;
        notifyListeners();
        return;
      }
    }

    for (final section in sections) {
      final signature = '${section.slug} ${section.title}'.toLowerCase();
      if (signature.contains(normalized.toLowerCase())) {
        selectedSectionSlug = section.slug;
        notifyListeners();
        return;
      }
    }

    selectedSectionSlug = null;
    notifyListeners();
  }
}
