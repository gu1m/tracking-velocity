import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

/// Modelo do filtro avançado.
class TripFilter {
  final DateTime? from;
  final DateTime? to;
  final String? location;
  final double? minSpeedKmh;
  final double? maxSpeedKmh;

  const TripFilter({
    this.from,
    this.to,
    this.location,
    this.minSpeedKmh,
    this.maxSpeedKmh,
  });

  bool get hasActiveFilter =>
      from != null ||
      to != null ||
      (location != null && location!.isNotEmpty) ||
      minSpeedKmh != null ||
      maxSpeedKmh != null;

  String describe() {
    final df = DateFormat('dd/MM/yy');
    final parts = <String>[];
    if (from != null && to != null) {
      parts.add('${df.format(from!)} → ${df.format(to!)}');
    } else if (from != null) {
      parts.add('A partir de ${df.format(from!)}');
    } else if (to != null) {
      parts.add('Até ${df.format(to!)}');
    }
    if (location != null && location!.isNotEmpty) {
      parts.add('"$location"');
    }
    if (minSpeedKmh != null) parts.add('≥ ${minSpeedKmh!.toInt()} km/h');
    if (maxSpeedKmh != null) parts.add('≤ ${maxSpeedKmh!.toInt()} km/h');
    return parts.join(' • ');
  }
}

class SearchFilterScreen extends StatefulWidget {
  final TripFilter initial;
  const SearchFilterScreen({super.key, required this.initial});

  @override
  State<SearchFilterScreen> createState() => _SearchFilterScreenState();
}

class _SearchFilterScreenState extends State<SearchFilterScreen> {
  late DateTime? _from = widget.initial.from;
  late DateTime? _to = widget.initial.to;
  late final TextEditingController _locCtrl =
      TextEditingController(text: widget.initial.location ?? '');
  late RangeValues _speedRange = RangeValues(
    widget.initial.minSpeedKmh ?? 0,
    widget.initial.maxSpeedKmh ?? 200,
  );

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM/yyyy', 'pt_BR');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Filtros avançados'),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _from = null;
                _to = null;
                _locCtrl.clear();
                _speedRange = const RangeValues(0, 200);
              });
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SectionLabel('Período'),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'De',
                  value: _from,
                  formatter: df,
                  onPick: (d) => setState(() => _from = d),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'Até',
                  value: _to,
                  formatter: df,
                  onPick: (d) => setState(() => _to = d),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _PresetChip(
                label: 'Hoje',
                onTap: () => _setPreset(0),
              ),
              _PresetChip(
                label: 'Últimos 7 dias',
                onTap: () => _setPreset(7),
              ),
              _PresetChip(
                label: 'Últimos 30 dias',
                onTap: () => _setPreset(30),
              ),
              _PresetChip(
                label: 'Últimos 90 dias',
                onTap: () => _setPreset(90),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Local (endereço, cidade, rodovia)'),
          TextField(
            controller: _locCtrl,
            decoration: const InputDecoration(
              hintText: 'Ex: Marginal Tietê, Rod. Anhanguera, Centro…',
              prefixIcon: Icon(Icons.place_rounded),
            ),
          ),
          const SizedBox(height: 24),
          const _SectionLabel('Faixa de velocidade'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: RangeSlider(
              values: _speedRange,
              min: 0,
              max: 200,
              divisions: 40,
              activeColor: AppColors.primary,
              labels: RangeLabels(
                '${_speedRange.start.toInt()} km/h',
                '${_speedRange.end.toInt()} km/h',
              ),
              onChanged: (v) => setState(() => _speedRange = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mín: ${_speedRange.start.toInt()} km/h',
                  style: const TextStyle(color: AppColors.textSecondary)),
              Text('Máx: ${_speedRange.end.toInt()} km/h',
                  style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _apply,
            icon: const Icon(Icons.check_rounded),
            label: const Text('Aplicar filtros'),
          ),
        ],
      ),
    );
  }

  void _setPreset(int days) {
    setState(() {
      _to = DateTime.now();
      _from = days == 0
          ? DateTime(_to!.year, _to!.month, _to!.day)
          : _to!.subtract(Duration(days: days));
    });
  }

  void _apply() {
    Navigator.of(context).pop(TripFilter(
      from: _from,
      to: _to,
      location: _locCtrl.text.trim().isEmpty ? null : _locCtrl.text.trim(),
      minSpeedKmh: _speedRange.start > 0 ? _speedRange.start : null,
      maxSpeedKmh: _speedRange.end < 200 ? _speedRange.end : null,
    ));
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            )),
      );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final DateFormat formatter;
  final ValueChanged<DateTime?> onPick;

  const _DateField({
    required this.label,
    required this.value,
    required this.formatter,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 3),
          lastDate: now,
          locale: const Locale('pt', 'BR'),
        );
        onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Text(
          value != null ? formatter.format(value!) : '—',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PresetChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: AppColors.primaryLight,
      labelStyle: const TextStyle(
        color: AppColors.primaryDark,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
    );
  }
}
