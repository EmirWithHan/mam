import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import '../theme/app_colors.dart';

/// Utility to crop an image file using the system image cropper.
///
/// Returns the cropped [File] or `null` when the user cancels.
Future<File?> cropImage(
  String sourcePath, {
  CropAspectRatioPreset? initialAspectRatio,
}) async {
  try {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      compressQuality: 88,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Fotoğrafı Düzenle',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary,
          backgroundColor: AppColors.background,
          initAspectRatio: initialAspectRatio ?? CropAspectRatioPreset.original,
          lockAspectRatio: false,
          aspectRatioPresets: const [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.original,
          ],
        ),
        IOSUiSettings(
          title: 'Fotoğrafı Düzenle',
          doneButtonTitle: 'Tamam',
          cancelButtonTitle: 'İptal',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
          aspectRatioPickerButtonHidden: false,
          aspectRatioPresets: const [
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
            CropAspectRatioPreset.original,
          ],
        ),
      ],
    );

    if (croppedFile == null) return null;
    return File(croppedFile.path);
  } catch (e) {
    debugPrint('Error cropping image: $e');
    return File(sourcePath);
  }
}
