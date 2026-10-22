import 'package:flutter/material.dart';
import '../app_theme.dart';

class PlateCalculatorDialog extends StatefulWidget {
  final double initialWeight;
  final String unit; // 'kg' or 'lbs'
  final ValueChanged<double>? onApplyWeight;

  const PlateCalculatorDialog({
    super.key,
    this.initialWeight = 100.0,
    this.unit = 'kg',
    this.onApplyWeight,
  });

  static Future<void> show(
    BuildContext context, {
    double initialWeight = 100.0,
    String unit = 'kg',
    ValueChanged<double>? onApplyWeight,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: PlateCalculatorDialog(
          initialWeight: initialWeight,
          unit: unit,
          onApplyWeight: onApplyWeight,
        ),
      ),
    );
  }

  @override
  State<PlateCalculatorDialog> createState() => _PlateCalculatorDialogState();
}

class _PlateCalculatorDialogState extends State<PlateCalculatorDialog> {
  late double _targetWeight;
  late double _barWeight;
  late String _unit;

  // Standard metric plates in kg
  static const List<double> _metricPlates = [25.0, 20.0, 15.0, 10.0, 5.0, 2.5, 1.25, 0.5];
  // Standard imperial plates in lbs
  static const List<double> _imperialPlates = [45.0, 35.0, 25.0, 10.0, 5.0, 2.5, 1.25];

  @override
  void initState() {
    super.initState();
    _unit = widget.unit.toLowerCase().contains('lb') ? 'lbs' : 'kg';
    _barWeight = _unit == 'kg' ? 20.0 : 45.0;
    _targetWeight = widget.initialWeight > _barWeight ? widget.initialWeight : (_unit == 'kg' ? 100.0 : 225.0);
  }

  Color _getPlateColor(double weight, String unit) {
    if (unit == 'kg') {
      if (weight >= 25.0) return const Color(0xFFEF4444); // Red
      if (weight >= 20.0) return const Color(0xFF3B82F6); // Blue
      if (weight >= 15.0) return const Color(0xFFFACC15); // Yellow
      if (weight >= 10.0) return const Color(0xFF22C55E); // Green
      if (weight >= 5.0) return const Color(0xFFF8FAFC); // White
      if (weight >= 2.5) return const Color(0xFF1E293B); // Black
      if (weight >= 1.25) return const Color(0xFF94A3B8); // Silver
      return const Color(0xFF64748B); // Chrome micro
    } else {
      if (weight >= 45.0) return const Color(0xFF3B82F6); // Blue
      if (weight >= 35.0) return const Color(0xFFFACC15); // Yellow
      if (weight >= 25.0) return const Color(0xFF22C55E); // Green
      if (weight >= 10.0) return const Color(0xFFF8FAFC); // White
      if (weight >= 5.0) return const Color(0xFF1E293B); // Black
      return const Color(0xFF94A3B8); // Silver
    }
  }

  Map<double, int> _calculatePlatesPerSide() {
    final availablePlates = _unit == 'kg' ? _metricPlates : _imperialPlates;
    double remaining = (_targetWeight - _barWeight) / 2.0;
    final Map<double, int> result = {};

    if (remaining <= 0) return result;

    for (final plate in availablePlates) {
      if (remaining >= plate) {
        int count = (remaining / plate).floor();
        result[plate] = count;
        remaining -= count * plate;
        remaining = double.parse(remaining.toStringAsFixed(2));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final platesPerSide = _calculatePlatesPerSide();
    final double weightPerSide = (_targetWeight - _barWeight) > 0 ? (_targetWeight - _barWeight) / 2.0 : 0.0;
    final double actualTotal = _barWeight + (platesPerSide.entries.fold<double>(0.0, (sum, e) => sum + (e.key * e.value)) * 2);

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.fitness_center, color: AppTheme.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Flexible(
                        child: Text(
                          'Barbell Plate Calculator',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          const SizedBox(height: 16),

          // Bar weight selector & unit toggle
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<double>(
                      value: _barWeight,
                      dropdownColor: AppTheme.cardColor,
                      isDense: true,
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700),
                      items: _unit == 'kg'
                          ? const [
                              DropdownMenuItem(value: 20.0, child: Text('Standard Olympic Bar (20 kg)')),
                              DropdownMenuItem(value: 15.0, child: Text('Women Olympic Bar (15 kg)')),
                              DropdownMenuItem(value: 25.0, child: Text('Squat / Power Bar (25 kg)')),
                              DropdownMenuItem(value: 10.0, child: Text('Technique / EZ Bar (10 kg)')),
                            ]
                          : const [
                              DropdownMenuItem(value: 45.0, child: Text('Standard Olympic Bar (45 lbs)')),
                              DropdownMenuItem(value: 35.0, child: Text('Women Olympic Bar (35 lbs)')),
                              DropdownMenuItem(value: 55.0, child: Text('Squat / Power Bar (55 lbs)')),
                              DropdownMenuItem(value: 25.0, child: Text('Technique / EZ Bar (25 lbs)')),
                            ],
                      onChanged: (val) {
                        if (val != null) setState(() => _barWeight = val);
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: Row(
                  children: [
                    _UnitButton(
                      label: 'KG',
                      isSelected: _unit == 'kg',
                      onTap: () {
                        setState(() {
                          _unit = 'kg';
                          _barWeight = 20.0;
                          _targetWeight = (_targetWeight / 2.20462).roundToDouble();
                        });
                      },
                    ),
                    _UnitButton(
                      label: 'LBS',
                      isSelected: _unit == 'lbs',
                      onTap: () {
                        setState(() {
                          _unit = 'lbs';
                          _barWeight = 45.0;
                          _targetWeight = (_targetWeight * 2.20462).roundToDouble();
                        });
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Target weight input with increment/decrement steppers
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TARGET TOTAL WEIGHT', style: TextStyle(color: AppTheme.textTertiary, fontSize: 10, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${_targetWeight.toStringAsFixed(1)} $_unit',
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    _StepperButton(
                      icon: Icons.remove,
                      onTap: () {
                        final step = _unit == 'kg' ? 2.5 : 5.0;
                        if (_targetWeight - step >= _barWeight) {
                          setState(() => _targetWeight -= step);
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                    _StepperButton(
                      icon: Icons.add,
                      onTap: () {
                        final step = _unit == 'kg' ? 2.5 : 5.0;
                        setState(() => _targetWeight += step);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Visual Barbell Sleeve Representation
          const Text(
            'BARBELL SLEEVE (ONE SIDE)',
            style: TextStyle(color: AppTheme.textTertiary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Container(
            height: 90,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF0D1117),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Bar collar
                    Container(
                      width: 16,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF64748B),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    // Shaft segment
                    Container(
                      width: 8,
                      height: 18,
                      color: const Color(0xFF94A3B8),
                    ),
                    if (platesPerSide.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'No plates needed — empty barbell',
                          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                        ),
                      )
                    else
                      ...platesPerSide.entries.expand((entry) {
                        return List.generate(entry.value, (index) {
                          final pWeight = entry.key;
                          final color = _getPlateColor(pWeight, _unit);
                          final double height = (36 + (pWeight / (_unit == 'kg' ? 25.0 : 45.0)) * 34).clamp(36.0, 70.0);
                          return Container(
                            margin: const EdgeInsets.only(left: 3),
                            width: 14,
                            height: height,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.black45, width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                          );
                        });
                      }),
                    // Bar sleeve end
                    Container(
                      width: 24,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Color(0xFF94A3B8),
                        borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Plate Breakdown Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      'Plates per side: ${weightPerSide.toStringAsFixed(1)} $_unit',
                      style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    Text(
                      'Exact loaded: ${actualTotal.toStringAsFixed(1)} $_unit',
                      style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (platesPerSide.isEmpty)
                  const Text('Bar only. Lift at current collar weight.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: platesPerSide.entries.map((e) {
                      final pWeight = e.key;
                      final count = e.value;
                      final color = _getPlateColor(pWeight, _unit);
                      final isLight = color == const Color(0xFFF8FAFC) || color == const Color(0xFFFACC15);
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: color,
                        label: Text(
                          '${count}x ${pWeight.toStringAsFixed(pWeight % 1 == 0 ? 0 : 1)} $_unit',
                          style: TextStyle(
                            color: isLight ? Colors.black87 : Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 11,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (widget.onApplyWeight != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check),
                label: Text('Apply ${_targetWeight.toStringAsFixed(1)} $_unit to Set'),
                onPressed: () {
                  widget.onApplyWeight!(_targetWeight);
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _UnitButton({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppTheme.backgroundColor : AppTheme.textSecondary,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
      ),
    );
  }
}
