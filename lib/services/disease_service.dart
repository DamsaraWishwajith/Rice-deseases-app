import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/disease_report.dart';

class DiseaseService {
  static final DiseaseService _instance = DiseaseService._internal();
  factory DiseaseService() => _instance;
  DiseaseService._internal();

  Interpreter? _interpreter;
  final List<String> labels = [
    'Bacterialblight',
    'Brownspot',
    'Healthy',
    'Others',
    'Sheath_blight'
  ];

  bool get isLoaded => _interpreter != null;

  Future<void> initModel() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/model.tflite');
      debugPrint('AI Model loaded successfully');
    } catch (e) {
      debugPrint('Error loading AI model: $e');
    }
  }

  Future<Map<String, dynamic>> predict(File imageFile) async {
    if (_interpreter == null) await initModel();
    if (_interpreter == null) throw Exception("Model not loaded");

    try {
      // 1. Read and decode image
      final imageBytes = await imageFile.readAsBytes();
      img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) throw Exception("Failed to decode image");

      // 2. Resize to 224x224 (standard for this model)
      img.Image resizedImage =
          img.copyResize(originalImage, width: 224, height: 224);

      // 3. Convert to Float32List and Normalize to [-1, 1] for MobileNetV2 backbone
      // Input shape: [1, 224, 224, 3]
      var input = Float32List(1 * 224 * 224 * 3);

      int index = 0;
      for (int y = 0; y < 224; y++) {
        for (int x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          // Normalize to [-1, 1]
          input[index++] = (pixel.r.toDouble() / 127.5) - 1.0;
          input[index++] = (pixel.g.toDouble() / 127.5) - 1.0;
          input[index++] = (pixel.b.toDouble() / 127.5) - 1.0;
        }
      }

      // Convert to shaped list for the interpreter
      final inputReshaped = input.reshape([1, 224, 224, 3]);

      // 4. Prepare Output [1, labels.length]
      var output = List.generate(1, (i) => List.filled(labels.length, 0.0));

      // 5. Run Inference
      _interpreter!.run(inputReshaped, output);
      debugPrint("Raw Output Tensor: ${output[0]}");

      // 6. Process Results
      List<double> probabilities = output[0];
      int maxIdx = 0;
      double maxProb = probabilities[0];

      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          maxIdx = i;
        }
      }

      final probs = <String, int>{};
      for (int i = 0; i < labels.length; i++) {
        probs[labels[i]] = (probabilities[i] * 100).round();
      }

      return {
        'disease': labels[maxIdx],
        'confidence': (maxProb * 100).round(),
        'probabilities': probs,
      };
    } catch (e) {
      debugPrint("Inference error: $e");
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getDiseaseInfo(String label) async {
    // Map internal label to user-friendly label if needed
    String searchLabel = label;
    if (label == 'Bacterialblight') searchLabel = 'Bacterial Blight';
    if (label == 'Brownspot') searchLabel = 'Brown Spot';
    if (label == 'Sheath_blight') searchLabel = 'Sheath Blight';

    try {
      final response = await http.post(
        Uri.parse('http://192.168.8.184:8000/api/disease-info'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': searchLabel}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint('API Error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching disease info: $e');
      return null;
    }
  }

  Future<bool> saveDiseaseReport({
    required int userId,
    int? farmerId,
    required String diseaseName,
    required File imageFile,
    required String note,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.8.184:8000/api/disease-reports'),
      );

      request.fields['user_id'] = userId.toString();
      if (farmerId != null) {
        request.fields['farmer_id'] = farmerId.toString();
      }
      request.fields['disease_name'] = diseaseName;
      request.fields['customer_note'] = note;

      request.files.add(
        await http.MultipartFile.fromPath(
          'disease_image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      var response = await request.send();

      if (response.statusCode == 201) {
        debugPrint('Report saved successfully');
        return true;
      } else {
        var respBody = await response.stream.bytesToString();
        debugPrint('Save error: ${response.statusCode} - $respBody');
        return false;
      }
    } catch (e) {
      debugPrint('Error saving report: $e');
      return false;
    }
  }

  Future<List<DiseaseReport>> getSupervisorReports(int supervisorId) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://192.168.8.184:8000/api/get-supervisor-reports'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'supervisor_id': supervisorId.toString()}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return (data['data'] as List)
              .map((item) => DiseaseReport.fromJson(item))
              .toList();
        }
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching reports: $e');
      return [];
    }
  }

  Future<void> generatePdfReport(List<DiseaseReport> reports, String district,
      String supervisorName) async {
    final pdf = pw.Document();

    // Load Unicode supports fonts to avoid Helvetica warnings
    final font = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();

    // Pre-fetch images
    final Map<int, pw.MemoryImage?> imageMap = {};
    for (var report in reports) {
      if (report.diseaseImage.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(report.diseaseImage));
          if (response.statusCode == 200) {
            imageMap[report.reportId] = pw.MemoryImage(response.bodyBytes);
          }
        } catch (e) {
          debugPrint('Failed to load image for report ${report.reportId}: $e');
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: font,
          bold: boldFont,
        ),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Rice Guard - Disease Reports',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateTime.now().toString().split(' ').first),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Text('Supervisor: $supervisorName'),
            pw.Text('District: $district'),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400),
              columnWidths: {
                0: const pw.FixedColumnWidth(35), // ID
                1: const pw.FixedColumnWidth(60), // Photo
                2: const pw.FixedColumnWidth(70), // Farmer
                3: const pw.FixedColumnWidth(70), // Disease
                4: const pw.FixedColumnWidth(90), // Date/Note
                5: const pw.FlexColumnWidth(), // Solutions
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColors.grey300),
                  children: [
                    _buildCell('ID', bold: true),
                    _buildCell('Photo', bold: true),
                    _buildCell('Farmer', bold: true),
                    _buildCell('Disease', bold: true),
                    _buildCell('Date/Note', bold: true),
                    _buildCell('Solutions', bold: true),
                  ],
                ),
                ...reports.map((report) {
                  final img = imageMap[report.reportId];
                  return pw.TableRow(
                    children: [
                      _buildCell('#${report.reportId}'),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(3),
                        child: img != null
                            ? pw.Container(
                                height: 40,
                                width: 40,
                                child: pw.Image(img, fit: pw.BoxFit.cover),
                              )
                            : pw.Center(
                                child: pw.Text('No Image',
                                    style: const pw.TextStyle(fontSize: 6))),
                      ),
                      _buildCell(report.farmerName),
                      _buildCell(report.diseaseName),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(5),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(report.createdAt.split('T').first,
                                style: const pw.TextStyle(fontSize: 8)),
                            if (report.customerNote != null &&
                                report.customerNote!.isNotEmpty)
                              pw.Text('\nNote: ${report.customerNote}',
                                  style: pw.TextStyle(
                                      fontSize: 7, color: PdfColors.grey700)),
                          ],
                        ),
                      ),
                      _buildCell(report.recommendSolutions, fontSize: 8),
                    ],
                  );
                }).toList(),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  pw.Widget _buildCell(String text, {bool bold = false, double fontSize = 9}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontSize: fontSize,
        ),
      ),
    );
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
