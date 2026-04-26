import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/speed_record.dart';
import '../../services/export_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';

class DailyMapScreen extends StatefulWidget {
  final DateTime initialDate;

  const DailyMapScreen({super.key, required this.initialDate});

  @override
  State<DailyMapScreen> createState() => _DailyMapScreenState();
}

class _DailyMapScreenState extends State<DailyMapScreen> {
  late DateTime _selectedDate;
  List<SpeedRecord> _records = [];
  bool _loading = false;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final records =
          await context.read<StorageService>().getDailyRecords(_selectedDate);
      setState(() => _records = records);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _load();
    }
  }

  Future<void> _export() async {
    if (_records.isEmpty) return;
    setState(() => _exporting = true);
    try {
      await ExportService().exportDailyRecords(_selectedDate, _records);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório diário gerado com sucesso!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao exportar: $e')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  // ── Derived values ─────────────────────────────────────────────────────────

  List<LatLng> get _polylinePoints =>
      _records.map((r) => LatLng(r.latitude, r.longitude)).toList();

  double get _maxSpeed =>
      _records.isEmpty ? 0 : _records.map((r) => r.maxSpeedKmh).reduce((a, b) => a > b ? a : b);

  double get _avgSpeed {
    if (_records.isEmpty) return 0;
    return _records.map((r) => r.speedKmh).reduce((a, b) => a + b) /
        _records.length;
  }

  Duration get _totalTime => Duration(minutes: _records.length);

  LatLngBounds? get _bounds {
    if (_records.isEmpty) return null;
    double minLat = _records.first.latitude;
    double maxLat = _records.first.latitude;
    double minLon = _records.first.longitude;
    double maxLon = _records.first.longitude;
    for (final r in _records) {
      if (r.latitude < minLat) minLat = r.latitude;
      if (r.latitude > maxLat) maxLat = r.latitude;
      if (r.longitude < minLon) minLon = r.longitude;
      if (r.longitude > maxLon) maxLon = r.longitude;
    }
    return LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
        actions: [
          IconButton(
            tooltip: 'Escolher data',
            icon: const Icon(Icons.calendar_today_rounded),
            onPressed: _pickDate,
          ),
          if (_records.isNotEmpty)
            IconButton(
              tooltip: 'Exportar Excel',
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.file_download_rounded),
              onPressed: _exporting ? null : _export,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? _emptyState()
              : Column(
                  children: [
                    _StatsBar(
                      recordCount: _records.length,
                      maxSpeed: _maxSpeed,
                      avgSpeed: _avgSpeed,
                      totalTime: _totalTime,
                    ),
                    Expanded(child: _buildMap()),
                  ],
                ),
    );
  }

  Widget _buildMap() {
    final points = _polylinePoints;
    final bounds = _bounds;

    return FlutterMap(
      options: MapOptions(
        initialCameraFit: bounds != null
            ? CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(40),
              )
            : null,
        initialCenter: points.isNotEmpty ? points.first : const LatLng(-15.78, -47.93),
        initialZoom: 13,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.trackingvelocidade.app',
        ),
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: AppColors.primary,
              ),
            ],
          ),
        if (points.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: points.first,
                child: const Icon(Icons.trip_origin_rounded,
                    color: AppColors.success, size: 28),
              ),
              Marker(
                point: points.last,
                child: const Icon(Icons.location_pin,
                    color: AppColors.danger, size: 32),
              ),
            ],
          ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.divider,
              ),
              child: const Icon(Icons.map_outlined,
                  size: 56, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            const Text('Nenhum trajeto neste dia',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
              'Tente selecionar outro dia ou aguarde o tracking registrar dados.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today_rounded),
              label: const Text('Escolher outro dia'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final int recordCount;
  final double maxSpeed;
  final double avgSpeed;
  final Duration totalTime;

  const _StatsBar({
    required this.recordCount,
    required this.maxSpeed,
    required this.avgSpeed,
    required this.totalTime,
  });

  @override
  Widget build(BuildContext context) {
    final hours = totalTime.inHours;
    final minutes = totalTime.inMinutes.remainder(60);
    final timeLabel = hours > 0 ? '${hours}h ${minutes}min' : '${minutes}min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          _Stat(
            label: 'Registros',
            value: '$recordCount min',
            icon: Icons.timeline_rounded,
            color: AppColors.primary,
          ),
          _Stat(
            label: 'Vel. máx.',
            value: '${maxSpeed.toStringAsFixed(0)} km/h',
            icon: Icons.speed_rounded,
            color: AppColors.danger,
          ),
          _Stat(
            label: 'Vel. média',
            value: '${avgSpeed.toStringAsFixed(0)} km/h',
            icon: Icons.av_timer_rounded,
            color: AppColors.success,
          ),
          _Stat(
            label: 'Tempo ativo',
            value: timeLabel,
            icon: Icons.timer_rounded,
            color: AppColors.accent,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
              )),
          Text(label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              )),
        ],
      ),
    );
  }
}
