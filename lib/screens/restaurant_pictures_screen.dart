import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../data/controllers/auth_controller.dart';

class RestaurantPicturesScreen extends StatefulWidget {
  const RestaurantPicturesScreen({super.key});
  @override
  State<RestaurantPicturesScreen> createState() =>
      _RestaurantPicturesScreenState();
}

class _RestaurantPicturesScreenState extends State<RestaurantPicturesScreen> {
  final auth = Get.find<AuthController>();
  XFile? logo;
  XFile? cover;
  Future<void> pick(bool isLogo) async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (file != null) {
      setState(() {
        if (isLogo) {
          logo = file;
        } else {
          cover = file;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Restaurant pictures')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Make your storefront memorable',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        const Text(
          'Use a clear logo and a wide cover photo of your food or restaurant.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        _picker(
          'Restaurant logo',
          'Square image recommended',
          logo,
          auth.restaurant.value?.logoUrl,
          true,
        ),
        const SizedBox(height: 20),
        _picker(
          'Cover photo',
          'Wide image recommended',
          cover,
          auth.restaurant.value?.coverImageUrl,
          false,
        ),
        const SizedBox(height: 28),
        Obx(
          () => SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: auth.busy.value
                  ? null
                  : () async {
                      final error = await auth.updatePictures(
                        logo: logo,
                        cover: cover,
                      );
                      if (!mounted) return;
                      Get.snackbar(
                        error == null ? 'Pictures updated' : 'Upload failed',
                        error ??
                            'Customers can now see your new restaurant pictures.',
                        backgroundColor: error == null
                            ? AppColors.primary
                            : AppColors.danger,
                        colorText: Colors.white,
                      );
                    },
              child: auth.busy.value
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Save pictures'),
            ),
          ),
        ),
      ],
    ),
  );
  Widget _picker(
    String title,
    String hint,
    XFile? file,
    String? network,
    bool isLogo,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      InkWell(
        onTap: () => pick(isLogo),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: isLogo ? 150 : 190,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.scaffold,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: file != null
              ? Image.file(File(file.path), fit: BoxFit.cover)
              : network != null
              ? Image.network(network, fit: BoxFit.cover)
              : Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined, size: 38),
                      const SizedBox(height: 8),
                      Text(hint),
                    ],
                  ),
                ),
        ),
      ),
    ],
  );
}
