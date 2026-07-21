import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/api_service.dart';
import '../data/controllers/menu_controller.dart';
import '../data/models/menu_item.dart';

enum _MenuFilter { all, available, soldOut }

extension on _MenuFilter {
  String get label => switch (this) {
    _MenuFilter.all => 'All items',
    _MenuFilter.available => 'Available',
    _MenuFilter.soldOut => 'Sold out',
  };
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  late final RestaurantMenuController _menu;
  final _search = TextEditingController();
  final Set<int> _togglingIds = <int>{};
  _MenuFilter _filter = _MenuFilter.all;

  @override
  void initState() {
    super.initState();
    _menu = Get.isRegistered<RestaurantMenuController>()
        ? Get.find<RestaurantMenuController>()
        : Get.put(RestaurantMenuController(Get.find<ApiService>()));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<FoodMenuItem> _visibleItems(List<FoodMenuItem> items) {
    final query = _search.text.trim().toLowerCase();
    return items.where((item) {
      final matchesFilter = switch (_filter) {
        _MenuFilter.all => true,
        _MenuFilter.available => item.available,
        _MenuFilter.soldOut => !item.available,
      };
      if (!matchesFilter || query.isEmpty) return matchesFilter;
      return '${item.name} ${item.description ?? ''}'.toLowerCase().contains(
        query,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Menu'),
            Text(
              'Items, prices, and availability',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh menu',
            onPressed: () => _menu.load(),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, _menu),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add item'),
      ),
      body: Obx(() {
        if (_menu.loading.value && _menu.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_menu.error.value != null && _menu.items.isEmpty) {
          return _CenteredState(
            icon: Icons.cloud_off,
            title: 'Could not load the menu',
            message: _menu.error.value!,
            action: ElevatedButton(
              onPressed: _menu.load,
              child: const Text('Retry'),
            ),
          );
        }

        final allItems = _menu.items.toList();
        final items = _visibleItems(allItems);
        return Column(
          children: [
            _MenuOverview(items: allItems),
            _MenuTools(
              controller: _search,
              selected: _filter,
              onSearchChanged: (_) => setState(() {}),
              onFilterChanged: (filter) => setState(() => _filter = filter),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => _menu.load(silent: true),
                child: items.isEmpty
                    ? _CenteredState(
                        icon: allItems.isEmpty
                            ? Icons.restaurant_menu_rounded
                            : Icons.search_off_rounded,
                        title: allItems.isEmpty
                            ? 'Build your menu'
                            : 'No matching items',
                        message: allItems.isEmpty
                            ? 'Add your first item with a food photo, price, and description.'
                            : 'Try another search or availability filter.',
                        scrollable: true,
                        action: allItems.isEmpty
                            ? FilledButton.icon(
                                onPressed: () => _openForm(context, _menu),
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('Add first item'),
                              )
                            : TextButton.icon(
                                onPressed: () {
                                  _search.clear();
                                  setState(() => _filter = _MenuFilter.all);
                                },
                                icon: const Icon(Icons.filter_alt_off_outlined),
                                label: const Text('Clear filters'),
                              ),
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = items[i];
                          return _MenuTile(
                            item: item,
                            toggling: _togglingIds.contains(item.id),
                            onEdit: () => _openForm(context, _menu, item: item),
                            onToggle: () => _toggle(item),
                            onDelete: () =>
                                _confirmDelete(context, _menu, item),
                          );
                        },
                      ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _toggle(FoodMenuItem item) async {
    setState(() => _togglingIds.add(item.id));
    final error = await _menu.toggle(item.id);
    if (!mounted) return;
    setState(() => _togglingIds.remove(item.id));
    _toast(
      error ?? (item.available ? 'Marked sold out' : 'Marked available'),
      error == null,
    );
  }

  Future<void> _openForm(
    BuildContext context,
    RestaurantMenuController menu, {
    FoodMenuItem? item,
  }) async {
    final nameC = TextEditingController(text: item?.name ?? '');
    final priceC = TextEditingController(
      text: item != null ? item.price.toStringAsFixed(2) : '',
    );
    final descC = TextEditingController(text: item?.description ?? '');
    final arC = TextEditingController(text: item?.arModelUrl ?? '');
    final arIosC = TextEditingController(text: item?.arIosModelUrl ?? '');
    XFile? selectedImage;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setFormState) => FractionallySizedBox(
          heightFactor: .92,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: Form(
              key: formKey,
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item == null ? 'Add menu item' : 'Edit menu item',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    'A clear photo and description help customers decide faster.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final source = await showModalBottomSheet<ImageSource>(
                        context: ctx,
                        builder: (sourceContext) => SafeArea(
                          child: Wrap(
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.photo_camera_outlined,
                                ),
                                title: const Text('Take food photo'),
                                onTap: () => Navigator.pop(
                                  sourceContext,
                                  ImageSource.camera,
                                ),
                              ),
                              ListTile(
                                leading: const Icon(
                                  Icons.photo_library_outlined,
                                ),
                                title: const Text('Choose from gallery'),
                                onTap: () => Navigator.pop(
                                  sourceContext,
                                  ImageSource.gallery,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                      if (source != null) {
                        final picked = await ImagePicker().pickImage(
                          source: source,
                          imageQuality: 85,
                          maxWidth: 1600,
                        );
                        if (picked != null) {
                          setFormState(() => selectedImage = picked);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 170,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: selectedImage != null
                          ? Image.file(
                              File(selectedImage!.path),
                              width: double.infinity,
                              fit: BoxFit.cover,
                            )
                          : item?.imageUrl != null
                          ? Image.network(
                              item!.imageUrl!,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const _PhotoPrompt(),
                            )
                          : const _PhotoPrompt(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameC,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Item name',
                      prefixIcon: Icon(Icons.fastfood_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceC,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      prefixText: 'ETB ',
                    ),
                    validator: (v) {
                      final p = double.tryParse((v ?? '').trim());
                      return (p == null || p <= 0)
                          ? 'Enter a valid price'
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descC,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Ingredients, portion, or what makes it special',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('3D and AR links'),
                    subtitle: const Text('Optional restaurant-hosted models'),
                    children: [
                      TextFormField(
                        controller: arC,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Android GLB or GLTF URL',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: arIosC,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'iPhone USDZ URL',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Obx(
                    () => FilledButton.icon(
                      onPressed: menu.saving.value
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              final error = await menu.save(
                                id: item?.id,
                                name: nameC.text.trim(),
                                description: descC.text.trim(),
                                price: double.parse(priceC.text.trim()),
                                image: selectedImage,
                                arModelUrl: arC.text.trim(),
                                arIosModelUrl: arIosC.text.trim(),
                              );
                              if (ctx.mounted && error == null) {
                                Navigator.pop(ctx);
                              }
                              _toast(
                                error ??
                                    (item == null
                                        ? 'Item added'
                                        : 'Item updated'),
                                error == null,
                              );
                            },
                      icon: menu.saving.value
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              item == null
                                  ? Icons.add_rounded
                                  : Icons.save_outlined,
                            ),
                      label: Text(item == null ? 'Add item' : 'Save changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    nameC.dispose();
    priceC.dispose();
    descC.dispose();
    arC.dispose();
    arIosC.dispose();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RestaurantMenuController menu,
    FoodMenuItem item,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete item?'),
        content: Text('Remove "${item.name}" from your menu?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
    if (yes == true) {
      final error = await menu.remove(item.id);
      _toast(error ?? 'Item deleted', error == null);
    }
  }

  void _toast(String message, bool ok) {
    Get.snackbar(
      ok ? 'Done' : 'Something went wrong',
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: ok ? AppColors.primary : AppColors.danger,
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
    );
  }
}

class _MenuOverview extends StatelessWidget {
  const _MenuOverview({required this.items});

  final List<FoodMenuItem> items;

  @override
  Widget build(BuildContext context) {
    final available = items.where((item) => item.available).length;
    final soldOut = items.length - available;
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(
          children: [
            _MenuMetric(label: 'Total', value: '${items.length}'),
            const SizedBox(width: 8),
            _MenuMetric(label: 'Available', value: '$available'),
            const SizedBox(width: 8),
            _MenuMetric(label: 'Sold out', value: '$soldOut'),
          ],
        ),
      ),
    );
  }
}

class _MenuMetric extends StatelessWidget {
  const _MenuMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuTools extends StatelessWidget {
  const _MenuTools({
    required this.controller,
    required this.selected,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  final TextEditingController controller;
  final _MenuFilter selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_MenuFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search menu items',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _MenuFilter.values.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final filter = _MenuFilter.values[index];
                return ChoiceChip(
                  label: Text(filter.label),
                  selected: selected == filter,
                  onSelected: (_) => onFilterChanged(filter),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.item,
    required this.toggling,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });

  final FoodMenuItem item;
  final bool toggling;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: item.imageUrl != null
                    ? Image.network(
                        item.imageUrl!,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _MenuPlaceholder(),
                      )
                    : const _MenuPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: item.available ? 1 : .64,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if ((item.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Text(
                            money(item.price),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: scheme.primary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.available ? 'Available' : 'Sold out',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: item.available
                                      ? AppColors.success
                                      : AppColors.danger,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: toggling
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: item.available,
                        onChanged: (_) => onToggle(),
                      ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Item options',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit item')),
                  PopupMenuItem(value: 'delete', child: Text('Delete item')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuPlaceholder extends StatelessWidget {
  const _MenuPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Icon(
        Icons.fastfood_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PhotoPrompt extends StatelessWidget {
  const _PhotoPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.add_a_photo_outlined,
            size: 36,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          const Text('Add a food photo'),
        ],
      ),
    );
  }
}

class _CenteredState extends StatelessWidget {
  const _CenteredState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.scrollable = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
    if (!scrollable) return content;
    return LayoutBuilder(
      builder: (_, constraints) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: constraints.maxHeight, child: content)],
      ),
    );
  }
}
