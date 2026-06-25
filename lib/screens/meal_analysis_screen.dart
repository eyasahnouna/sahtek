import 'dart:io';

import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/firebase_service.dart';
import '../utils/app_theme.dart';

/// Écran d'analyse photo d'un repas → estimation des glucides.
///
/// Flux :
///   1. L'utilisateur prend une photo ou choisit depuis la galerie
///   2. L'image est envoyée au backend Spring Boot → Gemini Vision API
///   3. Les glucides estimés par aliment sont affichés
///   4. L'utilisateur confirme → le total (double) est retourné via Navigator.pop
class MealAnalysisScreen extends StatefulWidget {
  const MealAnalysisScreen({super.key});

  @override
  State<MealAnalysisScreen> createState() => _MealAnalysisScreenState();
}

class _MealAnalysisScreenState extends State<MealAnalysisScreen> {
  File?               _image;
  MealAnalysisResult? _result;
  bool                _loading = false;
  String?             _error;
  final _hintCtrl = TextEditingController();

  @override
  void dispose() {
    _hintCtrl.dispose();
    super.dispose();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _pickImage({required bool fromGallery}) async {
    final xfile = await AiService.instance.pickImage(fromGallery: fromGallery);
    if (xfile == null || !mounted) return;
    setState(() {
      _image  = File(xfile.path);
      _result = null;
      _error  = null;
    });
  }

  Future<void> _analyze() async {
    if (_image == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      final result = await AiService.instance.analyzeMealImage(
        imageFile: _image!,
        hint: _hintCtrl.text.trim().isEmpty ? null : _hintCtrl.text.trim(),
      );
      if (mounted) setState(() { _result = result; _loading = false; });
    } on AiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Erreur inattendue : $e'; _loading = false; });
    }
  }

  Future<void> _confirmResult() async {
    if (_result == null || _image == null) return;
    setState(() => _loading = true);
    final imageUrl = await FirebaseService.instance.uploadMealImage(_image!);
    if (mounted) {
      setState(() => _loading = false);
      Navigator.of(context).pop((_result!.totalCarbsG, imageUrl));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.bgColor,
    appBar: AppBar(
      title: const Text('Analyser un repas'),
      actions: [
        if (_result != null)
          TextButton(
            onPressed: _confirmResult,
            child: Text('Appliquer',
                style: AppFonts.label(color: Colors.white, size: 13)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [

        // ── Photo ──────────────────────────────────────────────────────────
        _PhotoSection(
          image: _image,
          onCamera:  () => _pickImage(fromGallery: false),
          onGallery: () => _pickImage(fromGallery: true),
        ),
        const SizedBox(height: 16),

        // ── Hint ───────────────────────────────────────────────────────────
        TextField(
          controller: _hintCtrl,
          decoration: const InputDecoration(
            labelText: 'Contexte (optionnel)',
            hintText: "Ex: croissant + jus d'orange, petit déjeuner…",
            prefixIcon: Icon(Icons.info_outline_rounded, size: 18),
          ),
        ),
        const SizedBox(height: 16),

        // ── Bouton analyser ────────────────────────────────────────────────
        if (_image != null && !_loading)
          ElevatedButton.icon(
            onPressed: _analyze,
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('Analyser les glucides'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),

        // ── Chargement ─────────────────────────────────────────────────────
        if (_loading) ...[
          const SizedBox(height: 16),
          const _LoadingCard(),
        ],

        // ── Erreur ─────────────────────────────────────────────────────────
        if (_error != null) ...[
          const SizedBox(height: 16),
          _ErrorCard(message: _error!),
        ],

        // ── Résultats ──────────────────────────────────────────────────────
        if (_result != null) ...[
          const SizedBox(height: 20),
          _ResultsSection(result: _result!, onConfirm: _confirmResult),
        ],

        // ── Disclaimer ─────────────────────────────────────────────────────
        if (_result != null) ...[
          const SizedBox(height: 12),
          const _DisclaimerCard(),
        ],
      ],
    ),
  );
}

// ── Section photo ─────────────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  final File?        image;
  final VoidCallback onCamera;
  final VoidCallback onGallery;

  const _PhotoSection({
    required this.image,
    required this.onCamera,
    required this.onGallery,
  });

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(image!,
              height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _SourceButton(
            icon: Icons.camera_alt_rounded, label: 'Reprendre',
            color: AppTheme.primary, onTap: onCamera,
          )),
          const SizedBox(width: 10),
          Expanded(child: _SourceButton(
            icon: Icons.photo_library_rounded, label: 'Galerie',
            color: AppTheme.secondary, onTap: onGallery,
          )),
        ]),
      ]);
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.2), width: 2,
            strokeAlign: BorderSide.strokeAlignInside),
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle),
          child: const Icon(Icons.restaurant_rounded,
              color: AppTheme.primary, size: 40),
        ),
        const SizedBox(height: 16),
        Text('Photographiez votre repas',
            style: AppFonts.title(color: AppTheme.primary, size: 15)),
        const SizedBox(height: 6),
        Text('Croissant, jus, frites, brik…',
            style: AppFonts.body(color: Colors.grey, size: 13)),
        const SizedBox(height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _SourceButton(icon: Icons.camera_alt_rounded, label: 'Caméra',
              color: AppTheme.primary, onTap: onCamera),
          const SizedBox(width: 12),
          _SourceButton(icon: Icons.photo_library_rounded, label: 'Galerie',
              color: AppTheme.secondary, onTap: onGallery),
        ]),
      ]),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;

  const _SourceButton({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(label, style: AppFonts.label(color: color, size: 13)
            .copyWith(fontWeight: FontWeight.w700)),
      ]),
    ),
  );
}

// ── Chargement ────────────────────────────────────────────────────────────────

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.08),
            blurRadius: 16, offset: const Offset(0, 4))]),
    child: Row(children: [
      const SizedBox(
        width: 28, height: 28,
        child: CircularProgressIndicator(
            color: AppTheme.primary, strokeWidth: 3),
      ),
      const SizedBox(width: 16),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        Text('Analyse en cours…',
            style: AppFonts.title(color: AppTheme.primary, size: 14)),
        const SizedBox(height: 3),
        Text('Gemini Vision identifie les aliments et estime les glucides.',
            style: AppFonts.body(color: Colors.grey, size: 12)),
      ])),
    ]),
  );
}

// ── Erreur ────────────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
        color: AppTheme.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.3))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline_rounded, color: AppTheme.danger, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Text(message,
          style: AppFonts.body(color: AppTheme.danger, size: 13))),
    ]),
  );
}

// ── Résultats ─────────────────────────────────────────────────────────────────

class _ResultsSection extends StatelessWidget {
  final MealAnalysisResult result;
  final VoidCallback        onConfirm;

  const _ResultsSection({required this.result, required this.onConfirm});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
        const SizedBox(width: 8),
        Text("Résultats de l'analyse", style: AppFonts.title(size: 15)),
      ]),
      const SizedBox(height: 12),

      ...result.foods.map((food) => _FoodItemRow(food: food)),
      const SizedBox(height: 12),

      // Total + bouton Appliquer
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.centerLeft, end: Alignment.centerRight),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          const Icon(Icons.grain_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Total glucides estimés',
                style: AppFonts.label(color: Colors.white70, size: 12)),
            Text('${result.totalCarbsG.toStringAsFixed(1)} g',
                style: AppFonts.bold(color: Colors.white, size: 28)),
          ])),
          ElevatedButton(
            onPressed: onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppTheme.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text('Appliquer',
                style: AppFonts.label(color: AppTheme.primary, size: 13)
                    .copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
      ),

      if (result.notes != null && result.notes!.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.lightbulb_outline_rounded,
                color: Colors.amber.shade600, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(result.notes!,
                style: AppFonts.body(color: Colors.grey.shade600, size: 12))),
          ]),
        ),
      ],
    ],
  );
}

class _FoodItemRow extends StatelessWidget {
  final FoodItemResult food;
  const _FoodItemRow({required this.food});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8, offset: const Offset(0, 2))]),
    child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.restaurant_menu_rounded,
            color: AppTheme.primary, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(food.name, style: AppFonts.title(size: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        if (food.portionLabel.isNotEmpty)
          Text(food.portionLabel,
              style: AppFonts.body(color: Colors.grey, size: 11)),
      ])),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text('${food.carbsG.toStringAsFixed(1)} g',
            style: AppFonts.bold(color: AppTheme.primary, size: 15)),
        Text('glucides',
            style: AppFonts.label(
                color: AppTheme.primary.withValues(alpha: 0.6), size: 10)),
        if (food.confidenceLabel.isNotEmpty) ...[
          const SizedBox(height: 2),
          _ConfidenceBadge(
              label: food.confidenceLabel, confidence: food.confidence ?? 0),
        ],
      ]),
    ]),
  );
}

class _ConfidenceBadge extends StatelessWidget {
  final String label;
  final double confidence;
  const _ConfidenceBadge({required this.label, required this.confidence});

  Color get _color {
    if (confidence >= 0.8) return AppTheme.success;
    if (confidence >= 0.5) return AppTheme.warning;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20)),
    child: Text(label,
        style: AppFonts.label(color: _color, size: 9)
            .copyWith(fontWeight: FontWeight.w700)),
  );
}

// ── Disclaimer ────────────────────────────────────────────────────────────────

class _DisclaimerCard extends StatelessWidget {
  const _DisclaimerCard();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(
        "Estimation indicative uniquement. "
        "Ne modifiez pas votre dose d'insuline sans l'avis de votre médecin.",
        style: AppFonts.body(color: Colors.amber.shade800, size: 11),
      )),
    ]),
  );
}
