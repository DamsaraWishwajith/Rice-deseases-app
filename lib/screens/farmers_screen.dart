import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../theme/app_colors.dart';
import '../widgets/card_widget.dart';
import '../widgets/top_bar.dart';
import '../widgets/input_field.dart';
import '../widgets/button_widget.dart';
import '../widgets/tag_widget.dart';
import 'package:image_picker/image_picker.dart';
import '../models/disease_rec.dart';
import '../models/farmer.dart';
import '../models/supervisor.dart';
import '../services/disease_service.dart';
import 'dart:io';

import 'package:flutter/foundation.dart';

class FarmersScreen extends StatefulWidget {
  final List<Farmer> farmers;
  final Supervisor supervisor;
  final VoidCallback onRefresh;

  const FarmersScreen(
      {super.key,
      required this.farmers,
      required this.supervisor,
      required this.onRefresh});

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  String _subPage = 'list';
  Farmer? _selectedFarmer;
  bool _isSaving = false;
  String _error = '';
  int _scanStep = 0;
  Map<String, dynamic>? _scanResult;
  String? _analyzedImagePath;
  final Map<String, String> _form = {
    'name': '',
    'phone': '',
    'location': '',
    'district': '',
    'area': '',
    'variety': '',
  };
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  List<Farmer> _filteredFarmers = [];

  @override
  void initState() {
    super.initState();
    _form['district'] = widget.supervisor.district;
    _filteredFarmers = List.from(widget.farmers);
    _searchController.addListener(_filterFarmers);
  }

  @override
  void didUpdateWidget(covariant FarmersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmers != widget.farmers) {
      _filterFarmers();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterFarmers() {
    setState(() {
      _filteredFarmers = widget.farmers
          .where((f) =>
              f.name
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              (f.location
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase())))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: SafeArea(
            child: _buildMainContent(),
          ),
        ),
        if (_subPage == 'scanning') _buildScanningOverlay(),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_subPage == 'add') return _buildAddScreen();
    if (_subPage == 'detail' && _selectedFarmer != null) ;
    return _buildListScreen();
  }

  Widget _buildListScreen() {
    return Column(
      children: [
        TopBar(
          title: 'Farmers',
          right: GestureDetector(
            onTap: () => setState(() => _subPage = 'add'),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.forest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                  child: Text('+',
                      style: TextStyle(fontSize: 22, color: Colors.white))),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.8),
                    border: Border.all(
                        color: AppColors.border.withOpacity(0.9), width: 1.0),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.forest.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2)),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search farmers...',
                      hintStyle: TextStyle(color: AppColors.sub, fontSize: 14),
                      prefixIcon: Text('🔍', style: TextStyle(fontSize: 15)),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => widget.onRefresh(),
                    child: ListView.separated(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _filteredFarmers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final f = _filteredFarmers[index];
                        final rec =
                            diseaseRecs[f.disease] ?? diseaseRecs['Healthy']!;
                        return CardWidget(
                          onTap: () => setState(() {
                            _selectedFarmer = f;
                            _subPage = 'detail';
                          }),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: AppColors.greenPale,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                    child: Text('👤',
                                        style: TextStyle(fontSize: 20))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(f.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                            color: AppColors.text)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📍 ${f.location.isEmpty ? f.district : f.location} · ${f.variety}',
                                      style: const TextStyle(
                                          fontSize: 14, color: AppColors.sub),
                                    ),
                                  ],
                                ),
                              ),
                              if (f.disease != 'None')
                                TagWidget(text: f.disease, color: rec.color),
                              const SizedBox(width: 8),
                              const Text('›',
                                  style: TextStyle(
                                      fontSize: 20, color: AppColors.sub)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddScreen() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
                title: 'Add Farmer',
                onBack: () => setState(() => _subPage = 'list')),
            Expanded(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InputField(
                            label: 'Full Name',
                            icon: '✏️',
                            value: _form['name']!,
                            onChanged: (v) => _form['name'] = v,
                            placeholder: 'e.g. Kamal Perera',
                          ),
                          InputField(
                            label: 'Phone Number',
                            icon: '📞',
                            type: 'tel',
                            value: _form['phone']!,
                            onChanged: (v) => _form['phone'] = v,
                            placeholder: '07X-XXXXXXX',
                          ),
                          InputField(
                            label: 'Location / Village',
                            icon: '📍',
                            value: _form['location']!,
                            onChanged: (v) => _form['location'] = v,
                            placeholder: 'e.g. Anuradhapura North',
                          ),
                          InputField(
                            label: 'District',
                            icon: '🗺️',
                            value: _form['district']!,
                            enabled: false,
                            onChanged: (v) => _form['district'] = v,
                            options: const [
                              'Anuradhapura',
                              'Polonnaruwa',
                              'Kurunegala',
                              'Kandy',
                              'Galle',
                              'Hambantota',
                              'Matale',
                              'Jaffna',
                              'Batticaloa'
                            ],
                          ),
                          InputField(
                            label: 'Area Size (acres)',
                            icon: '📐',
                            value: _form['area']!,
                            onChanged: (v) => _form['area'] = v,
                            placeholder: 'e.g. 3.5',
                          ),
                          InputField(
                            label: 'Rice Variety',
                            icon: '🌾',
                            value: _form['variety']!,
                            onChanged: (v) => _form['variety'] = v,
                            options: const [
                              'Suwandel',
                              'Nadu',
                              'Rathu Heenati',
                              'Bg 300',
                              'Bg 360',
                              'At 307',
                              'Ld 365',
                              'Bg 250',
                              'Pachchaperumal'
                            ],
                          ),
                          if (_error.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.dangerPale,
                                border: Border.all(
                                    color: AppColors.danger.withOpacity(0.27)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: [
                                  const Text('⚠️ ',
                                      style: TextStyle(fontSize: 13)),
                                  Expanded(
                                    child: Text(
                                      _error,
                                      style: const TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          ButtonWidget(
                            text: _isSaving ? 'Please wait...' : 'Save Farmer',
                            onPressed: _isSaving ? () {} : _handleStoreFarmer,
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleStoreFarmer() async {
    if (_form['name']!.isEmpty ||
        _form['phone']!.isEmpty ||
        _form['district']!.isEmpty) {
      setState(() => _error = 'Name, Phone and District are required.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = '';
    });

    try {
      final response = await http
          .post(
            Uri.parse('http://192.168.8.184:8000/api/farmers'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'supervisor_id': widget.supervisor.id,
              'name': _form['name'],
              'phone': _form['phone'],
              'location': _form['location'],
              'district': _form['district'],
              'area': _form['area'],
              'variety': _form['variety'],
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Farmer registered successfully!'),
              backgroundColor: AppColors.green,
            ),
          );

          widget.onRefresh();

          _form.forEach((key, value) {
            _form[key] = '';
          });

          setState(() {
            _subPage = 'list';
          });
        }
      } else {
        try {
          final data = jsonDecode(response.body);
          if (!mounted) return;
          setState(() => _error = data['message'] ?? 'Failed to save farmer.');
        } catch (_) {
          if (!mounted) return;
          setState(
              () => _error = 'Server error (Status: ${response.statusCode})');
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (e.toString().contains('TimeoutException')) {
        setState(() => _error = 'Request timed out. Check your connection.');
      } else {
        setState(() => _error = 'Connection error. Is server running?');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildDetailScreen() {
    final f = _selectedFarmer!;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
                title: 'Farmer Profile',
                onBack: () => setState(() => _subPage = 'list')),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 100),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.forest, AppColors.green],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.forest.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Center(
                                    child: Text('👤',
                                        style: TextStyle(fontSize: 26))),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      f.name,
                                      style: const TextStyle(
                                        fontFamily: 'DM Serif Display',
                                        fontSize: 28,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '📞 ${f.phone}',
                                      style: const TextStyle(
                                          color: Colors.white60, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildInfoTile('📍 Location',
                                  f.location.isEmpty ? f.district : f.location),
                              const SizedBox(width: 10),
                              _buildInfoTile('🌾 Variety', f.variety),
                              const SizedBox(width: 10),
                              _buildInfoTile('📐 Area', f.area),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: CardWidget(
                            child: Column(
                              children: [
                                Text(f.scans.toString(),
                                    style: const TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.green)),
                                const Text('Total Scans',
                                    style: TextStyle(
                                        fontSize: 14, color: AppColors.sub)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: CardWidget(
                            child: Column(
                              children: [
                                Text(f.lastScan,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.accent)),
                                const Text('Last Scan',
                                    style: TextStyle(
                                        fontSize: 14, color: AppColors.sub)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (f.disease != 'None')
                      Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: CardWidget(
                          backgroundColor: AppColors.dangerPale,
                          child: Row(
                            children: [
                              const Text('⚠️ ', style: TextStyle(fontSize: 16)),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Active Disease',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.danger)),
                                  const SizedBox(height: 2),
                                  Text(f.disease,
                                      style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.text)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 18),
                    ButtonWidget(
                      icon: '🔬',
                      text: 'Scan Leaf Now',
                      onPressed: () => _showScanOptions(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 24),
            const Text(
              'Capture Leaf Image',
              style: TextStyle(
                  fontFamily: 'DM Serif Display',
                  fontSize: 24,
                  color: AppColors.forest),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a source to analyze this farmer\'s rice leaf',
              style: TextStyle(color: AppColors.sub, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                _buildPickerCard(context, 'Camera', '📸', ImageSource.camera),
                const SizedBox(width: 16),
                _buildPickerCard(
                    context, 'Gallery', '🖼️', ImageSource.gallery),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerCard(
      BuildContext context, String title, String icon, ImageSource source) {
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          Navigator.pop(context);
          try {
            final XFile? image = await _picker.pickImage(source: source);
            if (!mounted) return;
            if (image != null) {
              _runRealAnalysis(image);
            }
          } catch (e) {
            debugPrint('Error picking image: $e');
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.greenPale,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.green.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.forest,
                    fontSize: 15),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runRealAnalysis(XFile image) async {
    if (!mounted) return;

    setState(() {
      _subPage = 'scanning';
      _scanStep = 0;
      _analyzedImagePath = image.path;
    });

    // Step 0: Uploading simulation
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _scanStep = 1);

    try {
      // Step 1: Preprocessing simulation
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() => _scanStep = 2);

      // Step 2: Real Inference
      final result = await DiseaseService().predict(File(image.path));

      // Step 3: Finalizing simulation
      if (!mounted) return;
      setState(() => _scanStep = 3);
      await Future.delayed(const Duration(milliseconds: 600));

      if (mounted) {
        setState(() {
          _scanResult = result;
          _subPage =
              'detail'; // Go back to detail to show result in bottom sheet
        });
        _showDetailedResult(result, image.path);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _subPage = 'detail');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Analysis Error: $e'),
              backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showDetailedResult(Map<String, dynamic> result, String imagePath) {
    final disease = result['disease'] as String;
    final conf = result['confidence'] as int;
    final rec = diseaseRecs[disease] ?? diseaseRecs['Healthy']!;
    final probs = result['probabilities'] as Map<String, int>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2))),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.file(File(imagePath),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover),
                    ),
                    const SizedBox(height: 24),
                    Text(rec.icon, style: const TextStyle(fontSize: 64)),
                    const SizedBox(height: 12),
                    Text(
                      disease,
                      style: const TextStyle(
                          fontFamily: 'DM Serif Display',
                          fontSize: 32,
                          color: AppColors.forest),
                    ),
                    Text(
                      '$conf% Confidence Score',
                      style: const TextStyle(
                          color: AppColors.sub, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 24),

                    // Probability Breakdown
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('AI Confidence Breakdown',
                          style: TextStyle(
                              fontFamily: 'DM Serif Display', fontSize: 18)),
                    ),
                    const SizedBox(height: 16),
                    ...probs.entries.map((entry) {
                      final isSelected = entry.key == disease;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(entry.key,
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? AppColors.forest
                                            : AppColors.sub)),
                                Text('${entry.value}%',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500)),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: entry.value / 100,
                                backgroundColor:
                                    AppColors.border.withOpacity(0.3),
                                color: isSelected
                                    ? AppColors.green
                                    : AppColors.sub.withOpacity(0.3),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 32),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Treatment Recommendations',
                          style: TextStyle(
                              fontFamily: 'DM Serif Display', fontSize: 18)),
                    ),
                    const SizedBox(height: 12),
                    ...rec.ferts.map((f) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: CardWidget(
                            child: Row(
                              children: [
                                const Text('💊',
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(f,
                                        style: const TextStyle(fontSize: 14))),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 32),
                    ButtonWidget(text: 'Download Report', onPressed: () {}),
                    const SizedBox(height: 12),
                    ButtonWidget(
                      text: 'Close Result',
                      onPressed: () => Navigator.pop(context),
                      variant: 'outline',
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningOverlay() {
    final steps = [
      'Uploading image...',
      'Preprocessing leaf...',
      'Running AI model...',
      'Finalizing results...'
    ];
    final progress = [20, 45, 80, 98];

    return Container(
      color: AppColors.bg,
      width: double.infinity,
      height: double.infinity,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildRippleRing(),
                    _buildRippleRing(delay: 0.7),
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.forest, AppColors.green],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.forest.withOpacity(0.3),
                              blurRadius: 32,
                              offset: const Offset(0, 8)),
                        ],
                      ),
                      child: const Center(
                          child: Text('🔬', style: TextStyle(fontSize: 38))),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Analyzing Leaf',
                  style: TextStyle(
                      fontFamily: 'DM Serif Display',
                      fontSize: 26,
                      color: AppColors.forest),
                ),
                const SizedBox(height: 8),
                Text(steps[_scanStep],
                    style: const TextStyle(fontSize: 14, color: AppColors.sub)),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(steps.length, (i) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: i == _scanStep ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i < _scanStep
                            ? AppColors.green
                            : i == _scanStep
                                ? AppColors.accent
                                : AppColors.border,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 28),
                Container(
                  width: 220,
                  height: 6,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(4)),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress[_scanStep] / 100,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [AppColors.green, AppColors.accent]),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('${progress[_scanStep]}% complete',
                    style: const TextStyle(fontSize: 13, color: AppColors.sub)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRippleRing({double delay = 0}) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Opacity(
          opacity: 1 - value,
          child: Transform.scale(
            scale: 1 + value,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: AppColors.greenL.withOpacity(0.27), width: 2),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 3),
            Text(
              value,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ], 
        ),
      ),
    );
  }
}
