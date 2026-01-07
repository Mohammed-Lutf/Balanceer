import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../config/theme.dart';
import '../../models/custom_category_model.dart';
import '../../services/sync_service.dart';

class ManageCategoriesScreen extends StatefulWidget {
  final SyncService syncService;
  final String userId;

  const ManageCategoriesScreen({
    super.key,
    required this.syncService,
    required this.userId,
  });

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<CustomCategoryModel> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    final categories = await widget.syncService.getCustomCategories(widget.userId);
    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفئات المخصصة'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? _buildEmptyState()
              : _buildCategoriesList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddCategorySheet,
        backgroundColor: AppTheme.primaryColor,
        icon: const Icon(Iconsax.add),
        label: const Text(
          'إضافة فئة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.category,
              size: 48,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد فئات مخصصة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'أضف فئات جديدة لتنظيم نفقاتك بشكل أفضل',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ).animate().fadeIn().scale(),
    );
  }

  Widget _buildCategoriesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Color(category.colorValue).withOpacity(0.3),
            ),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Color(category.colorValue).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconData(category.iconName),
                color: Color(category.colorValue),
              ),
            ),
            title: Text(
              category.name,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            trailing: IconButton(
              icon: const Icon(Iconsax.trash, color: AppTheme.accentRed),
              onPressed: () => _confirmDelete(category),
            ),
          ),
        ).animate().fadeIn(delay: (index * 50).ms).slideX();
      },
    );
  }

  void _showAddCategorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddCategorySheet(
        onAdd: (name, icon, color) async {
          final newCategory = CustomCategoryModel.create(
            userId: widget.userId,
            name: name,
            iconName: icon,
            colorValue: color.value,
          );
          await widget.syncService.addCustomCategory(newCategory);
          _loadCategories();
          if (mounted) Navigator.pop(context);
        },
      ),
    );
  }

  void _confirmDelete(CustomCategoryModel category) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBackground,
        title: const Text('حذف الفئة'),
        content: Text('هل أنت متأكد من حذف فئة "${category.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.syncService.deleteCustomCategory(category.id);
              _loadCategories();
            },
            child: const Text(
              'حذف',
              style: TextStyle(color: AppTheme.accentRed, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    // Map string names to Iconsax data
    switch (iconName) {
      case 'money': return Iconsax.money;
      case 'card': return Iconsax.card;
      case 'shopping_cart': return Iconsax.shopping_cart;
      case 'bag_2': return Iconsax.bag_2;
      case 'coffee': return Iconsax.coffee;
      case 'cake': return Iconsax.cake;
      case 'gift': return Iconsax.gift;
      case 'home': return Iconsax.home;
      case 'car': return Iconsax.car;
      case 'airplane': return Iconsax.airplane;
      case 'heart': return Iconsax.heart;
      case 'health': return Iconsax.health;
      case 'book': return Iconsax.book;
      case 'music': return Iconsax.music;
      case 'game': return Iconsax.game;
      case 'pet': return Iconsax.pet;
      case 'mobile': return Iconsax.mobile;
      case 'wifi': return Iconsax.wifi;
      case 'flash': return Iconsax.flash;
      case 'lamp': return Iconsax.lamp;
      case 'brush': return Iconsax.brush;
      case 'scissor': return Iconsax.scissor;
      case 'weight': return Iconsax.weight;
      case 'medal': return Iconsax.medal;
      case 'crown': return Iconsax.crown;
      case 'emoji_happy': return Iconsax.emoji_happy;
      case 'emoji_sad': return Iconsax.emoji_sad;
      case 'shopping_bag': return Iconsax.shopping_bag;
      case 'ticket': return Iconsax.ticket;
      case 'cup': return Iconsax.cup;
      default: return Iconsax.category;
    }
  }
}

class _AddCategorySheet extends StatefulWidget {
  final Function(String, String, Color) onAdd;

  const _AddCategorySheet({required this.onAdd});

  @override
  State<_AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends State<_AddCategorySheet> {
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedIcon = CategoryIcons.availableIcons[0];
  int _selectedColorValue = CategoryColors.availableColors[0];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.scaffoldBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 24,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'فئة جديدة',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'اسم الفئة',
                  hintText: 'مثلاً: اشتراكات، صيانة، ...',
                  prefixIcon: Icon(Iconsax.text),
                ),
                validator: (value) => 
                    value?.trim().isEmpty == true ? 'يرجى إدخال اسم الفئة' : null,
              ),
              const SizedBox(height: 24),
              const Text('ختر أيقونة:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 60,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CategoryIcons.availableIcons.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final iconName = CategoryIcons.availableIcons[index];
                    final isSelected = _selectedIcon == iconName;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedIcon = iconName),
                      child: Container(
                        width: 50,
                        decoration: BoxDecoration(
                          color: isSelected 
                              ? Color(_selectedColorValue).withOpacity(0.2) 
                              : AppTheme.surfaceColor,
                          shape: BoxShape.circle,
                          border: isSelected 
                              ? Border.all(color: Color(_selectedColorValue), width: 2) 
                              : null,
                        ),
                        child: Icon(
                          _getIconData(iconName),
                          color: isSelected ? Color(_selectedColorValue) : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text('ختر لوناً:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: CategoryColors.availableColors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final colorValue = CategoryColors.availableColors[index];
                    final isSelected = _selectedColorValue == colorValue;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColorValue = colorValue),
                      child: Container(
                        width: 40,
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          shape: BoxShape.circle,
                          border: isSelected 
                              ? Border.all(color: Colors.white, width: 3) 
                              : null,
                          boxShadow: isSelected 
                              ? [BoxShadow(color: Color(colorValue).withOpacity(0.5), blurRadius: 8)] 
                              : null,
                        ),
                        child: isSelected 
                            ? const Icon(Icons.check, color: Colors.white, size: 20) 
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onAdd(
                      _nameController.text.trim(),
                      _selectedIcon,
                      Color(_selectedColorValue),
                    );
                  }
                },
                child: const Text('حفظ الفئة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Duplicate helper for local scope
  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'money': return Iconsax.money;
      case 'card': return Iconsax.card;
      case 'shopping_cart': return Iconsax.shopping_cart;
      case 'bag_2': return Iconsax.bag_2;
      case 'coffee': return Iconsax.coffee;
      case 'cake': return Iconsax.cake;
      case 'gift': return Iconsax.gift;
      case 'home': return Iconsax.home;
      case 'car': return Iconsax.car;
      case 'airplane': return Iconsax.airplane;
      case 'heart': return Iconsax.heart;
      case 'health': return Iconsax.health;
      case 'book': return Iconsax.book;
      case 'music': return Iconsax.music;
      case 'game': return Iconsax.game;
      case 'pet': return Iconsax.pet;
      case 'mobile': return Iconsax.mobile;
      case 'wifi': return Iconsax.wifi;
      case 'flash': return Iconsax.flash;
      case 'lamp': return Iconsax.lamp;
      case 'brush': return Iconsax.brush;
      case 'scissor': return Iconsax.scissor;
      case 'weight': return Iconsax.weight;
      case 'medal': return Iconsax.medal;
      case 'crown': return Iconsax.crown;
      case 'emoji_happy': return Iconsax.emoji_happy;
      case 'emoji_sad': return Iconsax.emoji_sad;
      case 'shopping_bag': return Iconsax.shopping_bag;
      case 'ticket': return Iconsax.ticket;
      case 'cup': return Iconsax.cup;
      default: return Iconsax.category;
    }
  }
}
