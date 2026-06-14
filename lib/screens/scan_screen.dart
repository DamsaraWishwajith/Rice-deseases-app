import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rice_guard/screens/home_screen.dart';
import 'dart:async';
import 'dart:math';
import 'dart:io';
import '../theme/app_colors.dart';
import '../widgets/card_widget.dart';
import '../widgets/top_bar.dart';
import '../widgets/button_widget.dart';
import '../models/farmer.dart';
import '../models/supervisor.dart';
import '../models/disease_rec.dart';
import '../services/disease_service.dart';
import '../services/ble_service.dart';

class ScanScreen extends StatefulWidget {
  final List<Farmer> farmers;
  final Supervisor supervisor;

  const ScanScreen(
      {super.key, required this.farmers, required this.supervisor});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _stage = 'pick'; // pick, scanning, result, recommend, compare, error
  Farmer? _selectedFarmer;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController _farmerSearchController = TextEditingController();
  File? _imageFile;
  String? _disease;
  String? _previewImage;
  int _scanStep = 0;
  Map<String, dynamic>? _scanResult;
  Map<String, dynamic>? _diseaseInfo;
  bool _fetchingInfo = false;
  bool _isSaving = false;
  String _notes = '';
  bool _useDemo = true;
  double _spread1 = 58;
  double _spread2 = 34;

  // ── BLE / ESP32 ──────────────────────────────────────────────────────────────
  final _bleService = BleService();
  BleStatus _bleStatus = BleStatus.idle;
  Esp32SensorData? _sensorData;
  StreamSubscription? _bleDataSub;
  StreamSubscription? _bleStatusSub;

  @override
  void initState() {
    super.initState();
    _loadModel();
    _bleStatusSub = _bleService.statusStream.listen((s) {
      if (mounted) setState(() => _bleStatus = s);
    });
    _bleDataSub = _bleService.dataStream.listen((d) {
      if (mounted) setState(() => _sensorData = d);
    });
  }

  @override
  void didUpdateWidget(covariant ScanScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.farmers != widget.farmers) {
      _filterFarmers();
    }
  }

  Future<void> _loadModel() async {
    await DiseaseService().initModel();
  }

  void _filterFarmers() {
    // This method is now handled locally in the modal or via build
  }

  @override
  void dispose() {
    _farmerSearchController.dispose();
    _bleDataSub?.cancel();
    _bleStatusSub?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  void _handleBack() {
    setState(() {
      if (_stage == 'recommend' || _stage == 'compare') {
        _stage = 'result';
      } else if (_stage == 'result' || _stage == 'error' || _stage == 'scanning') {
        _stage = 'pick';
      } else if (_stage == 'pick') {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_stage == 'pick') {
      content = _buildPickScreen();
    } else if (_stage == 'scanning') {
      content = _buildScanningScreen();
    } else if (_stage == 'result') {
      content = _buildResultScreen();
    } else if (_stage == 'recommend') {
      content = _buildRecommendScreen();
    } else if (_stage == 'compare') {
      content = _buildCompareScreen();
    } else if (_stage == 'error') {
      content = _buildErrorScreen();
    } else {
      content = const SizedBox();
    }

    return PopScope(
      canPop: _stage == 'pick',
      onPopInvoked: (didPop) {
        if (didPop) return;
        _handleBack();
      },
      child: content,
    );
  }

  Widget _buildPickScreen() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Scan Leaf',
              onBack: _handleBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_useDemo)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          color: AppColors.warnPale,
                          border: Border.all(
                              color: AppColors.warn.withOpacity(0.27)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Text('🧪', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text('Demo Mode Active',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.warn,
                                          fontSize: 13)),
                                  Text('Predictions are simulated',
                                      style: TextStyle(
                                          fontSize: 12, color: AppColors.sub)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Text(
                      'Select a farmer then upload a rice leaf photo for AI analysis.',
                      style: TextStyle(fontSize: 13, color: AppColors.sub),
                    ),
                    const SizedBox(height: 18),
                    GestureDetector(
                      onTap: () => _showFarmerSelector(),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.border.withOpacity(0.5)),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.forest.withOpacity(0.03),
                                blurRadius: 10,
                                offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _selectedFarmer != null
                                    ? AppColors.greenPale
                                    : AppColors.bg,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                  child: Text(
                                      _selectedFarmer != null ? '👤' : '🔍',
                                      style: const TextStyle(fontSize: 20))),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedFarmer?.name ?? 'Select Farmer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: _selectedFarmer != null
                                          ? AppColors.text
                                          : AppColors.sub,
                                    ),
                                  ),
                                  Text(
                                    _selectedFarmer != null
                                        ? _selectedFarmer!.location
                                        : 'Tap to search & associate scan',
                                    style: const TextStyle(
                                        fontSize: 12, color: AppColors.sub),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down,
                                color: AppColors.sub),
                          ],
                        ),
                      ),
                    ),
                    if (_selectedFarmer != null) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Upload Leaf Image',
                        style: TextStyle(
                          fontFamily: 'DM Serif Display',
                          fontSize: 18,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _showPickerOptions(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 44),
                          decoration: BoxDecoration(
                            color: AppColors.greenPale,
                            border: Border.all(
                                color: AppColors.green,
                                width: 2,
                                style: BorderStyle.solid),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Text('📷', style: TextStyle(fontSize: 52)),
                              const SizedBox(height: 12),
                              const Text(
                                'Tap to capture / upload',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.green,
                                    fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text('JPG or PNG · Close-up of rice leaf',
                                  style: TextStyle(
                                      fontSize: 13, color: AppColors.sub)),
                              const SizedBox(height: 14),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _buildBadge('📸 Camera'),
                                  const SizedBox(width: 8),
                                  _buildBadge('🖼 Gallery'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFarmerSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppColors.bg,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(32), topRight: Radius.circular(32)),
          ),
          child: Column(
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              const Text('Select Farmer',
                  style: TextStyle(
                      fontFamily: 'DM Serif Display',
                      fontSize: 24,
                      color: AppColors.forest)),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border.withOpacity(0.5)),
                ),
                child: TextField(
                  controller: _farmerSearchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search by name or district...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _farmerSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _farmerSearchController.clear();
                              (context as Element).markNeedsBuild();
                            })
                        : null,
                    border: InputBorder.none,
                  ),
                  onChanged: (v) {
                    (context as Element).markNeedsBuild();
                  },
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Builder(builder: (context) {
                  final query = _farmerSearchController.text.toLowerCase();
                  final filtered = widget.farmers
                      .where((f) =>
                          f.name.toLowerCase().contains(query) ||
                          f.location.toLowerCase().contains(query))
                      .toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🔍', style: TextStyle(fontSize: 40)),
                          const SizedBox(height: 12),
                          Text(
                              widget.farmers.isEmpty
                                  ? 'No farmers found in database'
                                  : 'No matching farmers found',
                              style: const TextStyle(color: AppColors.sub)),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final f = filtered[index];
                      final isSel = _selectedFarmer?.id == f.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CardWidget(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: InkWell(
                            onTap: () {
                              setState(() => _selectedFarmer = f);
                              Navigator.pop(context);
                            },
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isSel
                                        ? AppColors.greenPale
                                        : AppColors.bg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(child: Text('👤')),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(f.name,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w700)),
                                      Text(f.location,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.sub)),
                                    ],
                                  ),
                                ),
                                if (isSel)
                                  const Icon(Icons.check_circle,
                                      color: AppColors.green),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.sub)),
    );
  }

  void _showPickerOptions(BuildContext context) {
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
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 24),
            const Text('Scan Leaf',
                style: TextStyle(
                    fontFamily: 'DM Serif Display',
                    fontSize: 22,
                    color: AppColors.forest)),
            const SizedBox(height: 8),
            const Text('Choose image source for analysis',
                style: TextStyle(color: AppColors.sub, fontSize: 13)),
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
        onTap: () => _pickImage(source),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: AppColors.greenPale,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.green.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Text(icon, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 12),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.forest,
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  void _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        setState(() {
          _imageFile = File(image.path);
          _previewImage = image.path;
          _stage = 'scanning';
          _scanStep = 0;
          _simulateScan();
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Could not open source. Note: Camera does not work on Simulators.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _simulateScan() async {
    if (_imageFile == null) return;

    // Step 0: uploading
    await Future.delayed(const Duration(milliseconds: 600));
    setState(() => _scanStep = 1);

    try {
      setState(() => _scanStep = 2);

      final result = await DiseaseService().predict(_imageFile!);

      setState(() => _scanStep = 3);
      await Future.delayed(const Duration(milliseconds: 600));

      setState(() {
        _scanResult = result;
        _disease = result['disease'] as String;
        _stage = 'result';
      });
    } catch (e) {
      debugPrint("Analysis error: $e");
      setState(() => _stage = 'error');
    }
  }

  void _fetchRecommendation() async {
    if (_disease == null) return;

    setState(() => _fetchingInfo = true);

    final info = await DiseaseService().getDiseaseInfo(_disease!);

    if (mounted) {
      setState(() {
        _diseaseInfo = info;
        _fetchingInfo = false;
        _stage = 'recommend';
      });

      if (info == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Could not fetch latest info. Showing default results.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _handleSaveReport() async {
    if (_disease == null || _imageFile == null) return;

    setState(() => _isSaving = true);

    final success = await DiseaseService().saveDiseaseReport(
      userId: widget.supervisor.id,
      farmerId: _selectedFarmer?.id,
      diseaseName: _disease!,
      imageFile: _imageFile!,
      note: _notes,
      temp: _sensorData?.temp,
      hum: _sensorData?.hum,
      soil: _sensorData?.soil,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report saved successfully!'),
            backgroundColor: AppColors.green,
          ),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(supervisor: widget.supervisor)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save report. Please try again.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildScanningScreen() {
    final steps = [
      'Uploading image...',
      'Preprocessing leaf...',
      'Running AI model...',
      'Finalizing results...'
    ];
    final progress = [20, 45, 80, 98];

    return Scaffold(
      body: SafeArea(
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
                        gradient: LinearGradient(
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
                const SizedBox(height: 40),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.greenPale,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.greenL,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          'Keras model · Rice disease classifier · 4 classes',
                          style: TextStyle(fontSize: 12, color: AppColors.sub),
                        ),
                      ),
                    ],
                  ),
                ),
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

  Widget _buildResultScreen() {
    final disease = _disease ?? 'Unknown';
    final rec = diseaseRecs[disease] ?? diseaseRecs['Healthy']!;
    final isHealthy = disease == 'Healthy';
    final resultColor = isHealthy ? AppColors.green : AppColors.danger;
    final resultBg = isHealthy ? AppColors.greenPale : AppColors.dangerPale;
    final conf = _scanResult?['confidence'] as int?;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              title: 'Scan Result',
              onBack: _handleBack,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                child: Column(
                  children: [
                    if (_imageFile != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.file(
                          _imageFile!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                    else if (_previewImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Image.network(
                          _previewImage!,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: resultBg,
                        border: Border.all(
                            color: resultColor.withOpacity(0.27), width: 1.0),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: resultColor.withOpacity(0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(rec.icon, style: const TextStyle(fontSize: 48)),
                          const SizedBox(height: 10),
                          Text(
                            disease,
                            style: TextStyle(
                              fontFamily: 'DM Serif Display',
                              fontSize: 28,
                              color: resultColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isHealthy ? 'No disease found' : 'Disease Detected',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.sub),
                          ),
                          if (conf != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: conf > 80
                                            ? AppColors.greenL
                                            : conf > 60
                                                ? AppColors.warn
                                                : AppColors.danger,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text('$conf% confidence',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (_scanResult?['probabilities'] != null)
                      CardWidget(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Probability Breakdown',
                              style: TextStyle(
                                  fontFamily: 'DM Serif Display',
                                  fontSize: 16,
                                  color: AppColors.text),
                            ),
                            const SizedBox(height: 14),
                            ...((_scanResult?['probabilities']
                                        as Map<String, int>)
                                    .entries
                                    .toList()
                                  ..sort((a, b) => b.value.compareTo(a.value)))
                                .map((entry) {
                              final lbl = entry.key;
                              final pct = entry.value;
                              final isTop = lbl == disease;
                              final recItem =
                                  diseaseRecs[lbl] ?? diseaseRecs['Healthy']!;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(recItem.icon,
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            lbl,
                                            style: TextStyle(
                                              color: isTop
                                                  ? resultColor
                                                  : AppColors.text,
                                              fontWeight: isTop
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$pct%',
                                          style: TextStyle(
                                            color: isTop
                                                ? resultColor
                                                : AppColors.sub,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: AppColors.border,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor: pct / 100,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isTop
                                                ? (isHealthy
                                                    ? AppColors.greenL
                                                    : AppColors.danger)
                                                : AppColors.sub,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    CardWidget(
                      child: Row(
                        children: [
                          const Text('👤', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_selectedFarmer?.name ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '📍 ${_selectedFarmer?.location ?? _selectedFarmer?.district ?? ''}',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.sub),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (!isHealthy)
                      ButtonWidget(
                        loading: _fetchingInfo,
                        icon: '💊',
                        text: 'View Recommendations',
                        onPressed: _fetchRecommendation,
                      ),
                    const SizedBox(height: 10),
                    // ButtonWidget(
                    //   variant: 'outline',
                    //   icon: '📊',
                    //   text: 'View Scan Comparison',
                    //   onPressed: () => setState(() => _stage = 'compare'),
                    // ),
                    const SizedBox(height: 10),
                    ButtonWidget(
                      variant: 'ghost',
                      icon: '🔬',
                      text: 'New Scan',
                      onPressed: () => setState(() {
                        _stage = 'pick';
                        _scanResult = null;
                        _disease = null;
                        _previewImage = null;
                      }),
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

  Widget _buildRecommendScreen() {
    final disease = _disease ?? 'Unknown';
    final rec = diseaseRecs[disease] ?? diseaseRecs['Healthy']!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'Recommendations', onBack: _handleBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: rec.color.withOpacity(0.09),
                        border: Border.all(color: rec.color.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Text(rec.icon, style: const TextStyle(fontSize: 26)),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(disease,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: rec.color)),
                              Text('for ${_selectedFarmer?.name ?? ''}',
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.sub)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Scanned Specimen',
                      style: TextStyle(
                          fontFamily: 'DM Serif Display',
                          fontSize: 18,
                          color: AppColors.text),
                    ),
                    const SizedBox(height: 12),
                    if (_imageFile != null)
                      CardWidget(
                        padding: EdgeInsets.zero,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            _imageFile!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'About Disease',
                      style: TextStyle(
                          fontFamily: 'DM Serif Display',
                          fontSize: 18,
                          color: AppColors.text),
                    ),
                    const SizedBox(height: 12),
                    CardWidget(
                      child: Text(
                        _diseaseInfo?['note'] ?? rec.note,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.sub, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Solutions & Treatments',
                      style: TextStyle(
                          fontFamily: 'DM Serif Display',
                          fontSize: 18,
                          color: AppColors.text),
                    ),
                    const SizedBox(height: 12),
                    CardWidget(
                      child: Column(
                        children: ((_diseaseInfo?['solutions'] as String?)
                                    ?.split('\n') ??
                                rec.ferts)
                            .map((f) {
                          if (f.trim().isEmpty) return const SizedBox.shrink();
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              border: Border(
                                  bottom: BorderSide(color: AppColors.border)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 6),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: AppColors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Text(f.replaceAll('•', '').trim(),
                                        style: const TextStyle(fontSize: 14))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // ── ESP32 Greenhouse Sensor Card ───────────────────────
                    _buildEsp32SensorCard(),
                    const SizedBox(height: 18),
                    const Text(
                      'Custom Notes',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                          color: AppColors.sub),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      maxLines: 4,
                      onChanged: (v) => _notes = v,
                      decoration: InputDecoration(
                        hintText: 'Add your observations...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.border, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.border, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ButtonWidget(
                      loading: _isSaving,
                      icon: '✓',
                      text: 'Save Scans',
                      onPressed: _handleSaveReport,
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

  // ── ESP32 Greenhouse Sensor Card ──────────────────────────────────────────
  Widget _buildEsp32SensorCard() {
    final bool isConnected = _bleStatus == BleStatus.connected;
    final bool isBusy = _bleStatus == BleStatus.scanning ||
        _bleStatus == BleStatus.connecting;

    String statusLabel;
    Color statusColor;
    IconData statusIcon;
    switch (_bleStatus) {
      case BleStatus.connected:
        statusLabel = 'Connected';
        statusColor = AppColors.greenL;
        statusIcon = Icons.bluetooth_connected_rounded;
        break;
      case BleStatus.scanning:
        statusLabel = 'Scanning...';
        statusColor = AppColors.accent;
        statusIcon = Icons.bluetooth_searching_rounded;
        break;
      case BleStatus.connecting:
        statusLabel = 'Connecting...';
        statusColor = AppColors.accent;
        statusIcon = Icons.bluetooth_searching_rounded;
        break;
      case BleStatus.error:
        statusLabel = 'Not Found';
        statusColor = AppColors.danger;
        statusIcon = Icons.bluetooth_disabled_rounded;
        break;
      default:
        statusLabel = 'Disconnected';
        statusColor = AppColors.sub;
        statusIcon = Icons.bluetooth_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.forest.withOpacity(0.96),
            const Color(0xFF27583A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withOpacity(0.25),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Farm Condition Sensor',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Row(
                        children: [
                          if (isConnected)
                            _PulseDot(color: statusColor)
                          else
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                          const SizedBox(width: 5),
                          Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Connect / Disconnect button
                GestureDetector(
                  onTap: isBusy
                      ? null
                      : isConnected
                          ? _bleService.disconnect
                          : _bleService.connect,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? AppColors.danger.withOpacity(0.85)
                          : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.2), width: 1),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isConnected ? 'Disconnect' : 'Connect',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          // ── Divider ───────────────────────────────────────────────────
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.1),
          ),
          // ── Sensor tiles ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: _sensorData != null
                ? Row(
                    children: [
                      _buildSensorTile(
                        icon: '🌡️',
                        label: 'Temperature',
                        value: '${_sensorData!.temp.toStringAsFixed(1)}°C',
                        barValue: (_sensorData!.temp.clamp(0, 50) / 50),
                        barColor: _tempColor(_sensorData!.temp),
                      ),
                      _vDivider(),
                      _buildSensorTile(
                        icon: '💧',
                        label: 'Humidity',
                        value: '${_sensorData!.hum.toStringAsFixed(1)}%',
                        barValue: _sensorData!.hum.clamp(0, 100) / 100,
                        barColor: const Color(0xFF5BC8E8),
                      ),
                      _vDivider(),
                      _buildSensorTile(
                        icon: '🌱',
                        label: 'Soil',
                        value: '${_sensorData!.soil}%',
                        barValue: _sensorData!.soil.clamp(0, 100) / 100,
                        barColor: AppColors.accent,
                      ),
                    ],
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isConnected
                              ? Icons.hourglass_top_rounded
                              : Icons.sensors_off_rounded,
                          color: Colors.white38,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isConnected
                              ? 'Waiting for sensor data...'
                              : 'Tap Connect to read sensors',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSensorTile({
    required String icon,
    required String label,
    required String value,
    required double barValue,
    required Color barColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barValue,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vDivider() {
    return Container(
      width: 1,
      height: 70,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: Colors.white.withOpacity(0.1),
    );
  }

  Color _tempColor(double t) {
    if (t < 20) return const Color(0xFF5BC8E8);
    if (t < 30) return AppColors.greenL;
    if (t < 35) return AppColors.accent;
    return AppColors.danger;
  }

  // ────────────────────────────────────────────────────────────────────────────
  Widget _buildCompareScreen() {
    final reduction = _spread1 - _spread2;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'Scan Comparison', onBack: _handleBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 100),
                child: Column(
                  children: [
                    Text(
                      '${_selectedFarmer?.name ?? ''} · ${_disease ?? 'Disease'}',
                      style:
                          const TextStyle(fontSize: 13, color: AppColors.sub),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        _buildComparisonCard('Scan 1', '2 weeks ago', _spread1,
                            AppColors.danger),
                        const SizedBox(width: 12),
                        _buildComparisonCard(
                            'Scan 2', 'Today', _spread2, AppColors.greenL),
                      ],
                    ),
                    const SizedBox(height: 18),
                    CardWidget(
                      backgroundColor: reduction > 0
                          ? AppColors.greenPale
                          : AppColors.dangerPale,
                      child: Column(
                        children: [
                          Text(reduction > 0 ? '📉' : '📈',
                              style: const TextStyle(fontSize: 44)),
                          const SizedBox(height: 8),
                          Text(
                            '${reduction.abs()}% ${reduction > 0 ? 'Reduction' : 'Increase'}',
                            style: TextStyle(
                              fontFamily: 'DM Serif Display',
                              fontSize: 24,
                              color: reduction > 0
                                  ? AppColors.green
                                  : AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            reduction > 0
                                ? 'Treatment is working. Continue current plan.'
                                : 'Disease spreading! Immediate action needed!',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.sub),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    ButtonWidget(
                      variant: 'outline',
                      icon: '🔬',
                      text: 'Start New Scan',
                      onPressed: () => setState(() {
                        _stage = 'pick';
                        _selectedFarmer = null;
                        _previewImage = null;
                        _disease = null;
                        _scanResult = null;
                      }),
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

  Widget _buildComparisonCard(
      String label, String sub, double spread, Color color) {
    return Expanded(
      child: CardWidget(
        child: Column(
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.sub)),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(fontSize: 10, color: AppColors.sub)),
            const SizedBox(height: 12),
            _buildDonutChart(spread.toInt(), color, 100),
            const SizedBox(height: 10),
            Text('${spread.toInt()}%',
                style: TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 22, color: color)),
            const Text('spread',
                style: TextStyle(fontSize: 11, color: AppColors.sub)),
          ],
        ),
      ),
    );
  }

  Widget _buildDonutChart(int pct, Color color, double size) {
    final r = size / 2;
    final ir = r * 0.52;
    final angle = (pct / 100) * 2 * pi - pi / 2;
    final sa = -pi / 2;
    final la = pct > 50 ? 1 : 0;
    final x1 = r + r * cos(sa);
    final y1 = r + r * sin(sa);
    final x2 = r + r * cos(angle);
    final y2 = r + r * sin(angle);
    final ix1 = r + ir * cos(sa);
    final iy1 = r + ir * sin(sa);
    final ix2 = r + ir * cos(angle);
    final iy2 = r + ir * sin(angle);

    String path;
    if (pct >= 99) {
      path =
          'M $r ${r - r} A $r $r 0 1 1 ${r - 0.01} ${r - r} L ${r - 0.01} ${r - ir} A $ir $ir 0 1 0 $r ${r - ir} Z';
    } else {
      path =
          'M $ix1 $iy1 L $x1 $y1 A $r $r 0 $la 1 $x2 $y2 L $ix2 $iy2 A $ir $ir 0 $la 0 $ix1 $iy1 Z';
    }

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(pct, color, r, ir, path),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            TopBar(title: 'Scan Failed', onBack: _handleBack),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 64)),
                    const SizedBox(height: 20),
                    const Text(
                      'Model API Error',
                      style: TextStyle(
                          fontFamily: 'DM Serif Display',
                          fontSize: 22,
                          color: AppColors.danger),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerPale,
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.2)),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Error Details',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger)),
                          const SizedBox(height: 6),
                          const Text('Could not reach model API',
                              style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ButtonWidget(
                      icon: '🧪',
                      text: 'Use Demo Mode',
                      onPressed: () => setState(() {
                        _useDemo = true;
                        _stage = 'pick';
                      }),
                    ),
                    const SizedBox(height: 12),
                    ButtonWidget(
                      variant: 'ghost',
                      text: '← Try Again',
                      onPressed: () => setState(() => _stage = 'pick'),
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
}

class _DonutPainter extends CustomPainter {
  final int pct;
  final Color color;
  final double r;
  final double ir;
  final String path;

  _DonutPainter(this.pct, this.color, this.r, this.ir, this.path);

  @override
  void paint(Canvas canvas, Size size) {
    final paintBg = Paint()..color = AppColors.border;
    canvas.drawCircle(Offset(r, r), r, paintBg);
    final paintInner = Paint()..color = AppColors.white;
    canvas.drawCircle(Offset(r, r), ir, paintInner);
    final paintDonut = Paint()..color = color;
    final pathObj = _parseSimplePath(path);
    canvas.drawPath(pathObj, paintDonut);
  }

  Path _parseSimplePath(String path) {
    final pathObj = Path();
    final parts = path.split(' ');
    int i = 0;
    while (i < parts.length) {
      final cmd = parts[i];
      if (cmd == 'M') {
        pathObj.moveTo(double.parse(parts[i + 1]), double.parse(parts[i + 2]));
        i += 3;
      } else if (cmd == 'L') {
        pathObj.lineTo(double.parse(parts[i + 1]), double.parse(parts[i + 2]));
        i += 3;
      } else if (cmd == 'A') {
        final rx = double.parse(parts[i + 1]);
        final laf = double.parse(parts[i + 4]) == 1;
        final sf = double.parse(parts[i + 5]) == 1;
        final x = double.parse(parts[i + 6]);
        final y = double.parse(parts[i + 7]);
        pathObj.arcToPoint(Offset(x, y),
            radius: Radius.circular(rx), largeArc: laf, clockwise: sf);
        i += 8;
      } else if (cmd == 'Z') {
        pathObj.close();
        i++;
      } else {
        i++;
      }
    }
    return pathObj;
  }


  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

/// Small pulsing dot to show a live/connected status.
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(
          color: widget.color.withOpacity(0.4 + 0.6 * _anim.value),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withOpacity(0.5 * _anim.value),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}
