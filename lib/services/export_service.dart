import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/api_config.dart';
import '../models/speed_record.dart';
import '../models/trip.dart';

/// Serviço de exportação de relatórios em Excel.
///
/// O relatório é a peça-chave do app: o usuário usa esse arquivo como
/// prova documental ao recorrer de uma multa de velocidade.
///
/// Formato do relatório:
///  - Aba "Resumo":     dados gerais da(s) viagem(ns).
///  - Aba "Registros":  velocidade minuto a minuto com hash SHA-256.
///  - Aba "Assinatura": assinatura digital emitida pelo servidor (Fase 1).
class ExportService {
  static const _dateFormat = 'dd/MM/yyyy HH:mm:ss';

  /// Exporta uma única viagem como Excel e abre o share sheet.
  Future<File> exportTrip(
    Trip trip, {
    String? firebaseToken,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _buildSummarySheet(excel, [trip]);
    _buildRecordsSheet(excel, [trip]);

    final filename =
        'relatorio_velocidade_${DateFormat('yyyyMMdd_HHmm').format(trip.startedAt)}.xlsx';

    return _buildSignAndShare(
      excel,
      filename: filename,
      firebaseToken: firebaseToken,
      tripIds: [trip.id],
      records: trip.records,
    );
  }

  /// Exporta um conjunto de viagens em um único arquivo Excel.
  Future<File> exportTrips(
    List<Trip> trips, {
    String? filterDescription,
    String? firebaseToken,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    _buildSummarySheet(excel, trips, filterDescription: filterDescription);
    _buildRecordsSheet(excel, trips);

    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    final filename = 'relatorio_velocidade_${trips.length}_viagens_$stamp.xlsx';

    return _buildSignAndShare(
      excel,
      filename: filename,
      firebaseToken: firebaseToken,
      tripIds: trips.map((t) => t.id).toList(),
      records: trips.expand((t) => t.records).toList(),
    );
  }

  // ── Aba "Resumo" ────────────────────────────────────────────────────────
  void _buildSummarySheet(
    Excel excel,
    List<Trip> trips, {
    String? filterDescription,
  }) {
    final sheet = excel['Resumo'];
    final df = DateFormat(_dateFormat);

    sheet.appendRow([
      TextCellValue('RELATÓRIO DE VELOCIDADE — Tracking Velocidade'),
    ]);
    sheet.appendRow([
      TextCellValue('Gerado em: ${df.format(DateTime.now())}'),
    ]);
    sheet.appendRow([
      TextCellValue('Autenticidade: registros protegidos por hash SHA-256 (Fase 1)'),
    ]);
    if (filterDescription != null) {
      sheet.appendRow([TextCellValue('Filtro aplicado: $filterDescription')]);
    }
    sheet.appendRow([TextCellValue('')]);

    final headers = [
      'ID Viagem',
      'Data início',
      'Data fim',
      'Origem',
      'Destino',
      'Velocidade média (km/h)',
      'Velocidade máxima (km/h)',
      'Distância (km)',
      'Duração (min)',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final t in trips) {
      sheet.appendRow([
        TextCellValue(t.id),
        TextCellValue(df.format(t.startedAt)),
        TextCellValue(t.endedAt != null ? df.format(t.endedAt!) : '-'),
        TextCellValue(t.startAddress),
        TextCellValue(t.endAddress ?? '-'),
        DoubleCellValue(t.avgSpeedKmh),
        DoubleCellValue(t.maxSpeedKmh),
        DoubleCellValue(t.distanceKm),
        IntCellValue(t.duration.inMinutes),
      ]);
    }

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 22);
    sheet.setColumnWidth(3, 38);
    sheet.setColumnWidth(4, 38);
    sheet.setColumnWidth(5, 22);
    sheet.setColumnWidth(6, 22);
    sheet.setColumnWidth(7, 14);
    sheet.setColumnWidth(8, 14);
  }

  // ── Aba "Registros" ─────────────────────────────────────────────────────
  void _buildRecordsSheet(Excel excel, List<Trip> trips) {
    final sheet = excel['Registros'];
    final df = DateFormat(_dateFormat);

    final headers = [
      'ID Viagem',
      'Data/Hora (NTP)',
      'Velocidade média (km/h)',
      'Velocidade máxima (km/h)',
      'Latitude',
      'Longitude',
      'Precisão GPS',
      'Hash SHA-256',
      'Endereço',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final t in trips) {
      for (final r in t.records) {
        sheet.appendRow([
          TextCellValue(t.id),
          TextCellValue(df.format(r.timestamp.toLocal())),
          DoubleCellValue(r.speedKmh),
          DoubleCellValue(r.maxSpeedKmh),
          DoubleCellValue(r.latitude),
          DoubleCellValue(r.longitude),
          TextCellValue('±${r.accuracy.toStringAsFixed(0)} m'),
          TextCellValue(r.hash ?? 'N/D'),
          TextCellValue(r.address ?? '-'),
        ]);
      }
    }

    sheet.setColumnWidth(0, 14);
    sheet.setColumnWidth(1, 22);
    sheet.setColumnWidth(2, 26);
    sheet.setColumnWidth(3, 26);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 14);
    sheet.setColumnWidth(6, 12);
    sheet.setColumnWidth(7, 68);  // hash SHA-256 (64 chars)
    sheet.setColumnWidth(8, 38);
  }

  // ── Aba "Assinatura Digital" ────────────────────────────────────────────
  void _buildSignatureSheet(
    Excel excel, {
    required String reportId,
    required String ntpTimestamp,
    required String signature,
    required String verifyUrl,
    required int recordCount,
  }) {
    final sheet = excel['Assinatura Digital'];

    sheet.appendRow([TextCellValue('ASSINATURA DIGITAL — Fase 1')]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('ID do relatório'), TextCellValue(reportId)]);
    sheet.appendRow([TextCellValue('Horário NTP (servidor oficial)'), TextCellValue(ntpTimestamp)]);
    sheet.appendRow([TextCellValue('Total de registros assinados'), IntCellValue(recordCount)]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('Assinatura RSA-SHA256 (base64):')]);
    sheet.appendRow([TextCellValue(signature)]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([TextCellValue('URL de verificação:')]);
    sheet.appendRow([TextCellValue(verifyUrl)]);
    sheet.appendRow([TextCellValue('')]);
    sheet.appendRow([
      TextCellValue(
        'Para verificar a autenticidade deste relatório, acesse a URL acima '
        'ou escaneie o QR code. O servidor oficial confirmará o horário NTP, '
        'o número de registros e a assinatura digital.',
      ),
    ]);

    sheet.setColumnWidth(0, 36);
    sheet.setColumnWidth(1, 80);
  }

  /// Exporta todos os registros de um dia como Excel.
  Future<File> exportDailyRecords(
    DateTime date,
    List<SpeedRecord> records, {
    String? firebaseToken,
  }) async {
    final excel = Excel.createExcel();
    excel.delete('Sheet1');

    final sheetName = 'Trajeto ${DateFormat('dd-MM-yyyy').format(date)}';
    final sheet = excel[sheetName];
    final df = DateFormat(_dateFormat);

    sheet.appendRow([TextCellValue('TRAJETO DIÁRIO — Tracking Velocidade')]);
    sheet.appendRow([TextCellValue('Data: ${DateFormat('dd/MM/yyyy').format(date)}')]);
    sheet.appendRow([TextCellValue('Gerado em: ${df.format(DateTime.now())}')]);
    sheet.appendRow([TextCellValue('Registros protegidos por hash SHA-256')]);
    sheet.appendRow([TextCellValue('')]);

    final headers = [
      'Data/Hora (NTP)',
      'Velocidade média (km/h)',
      'Velocidade máxima (km/h)',
      'Latitude',
      'Longitude',
      'Precisão GPS',
      'Hash SHA-256',
    ];
    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

    for (final r in records) {
      sheet.appendRow([
        TextCellValue(df.format(r.timestamp.toLocal())),
        DoubleCellValue(r.speedKmh),
        DoubleCellValue(r.maxSpeedKmh),
        DoubleCellValue(r.latitude),
        DoubleCellValue(r.longitude),
        TextCellValue('±${r.accuracy.toStringAsFixed(0)} m'),
        TextCellValue(r.hash ?? 'N/D'),
      ]);
    }

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 24);
    sheet.setColumnWidth(2, 24);
    sheet.setColumnWidth(3, 14);
    sheet.setColumnWidth(4, 14);
    sheet.setColumnWidth(5, 12);
    sheet.setColumnWidth(6, 68);

    final stamp = DateFormat('yyyyMMdd').format(date);
    final filename = 'trajeto_diario_$stamp.xlsx';

    // Cria um único "Trip" virtual para poder reusar _buildSignAndShare.
    // Como não temos tripId único aqui, usamos uma lista de IDs distintos.
    final tripIds = records.map((r) => r.tripId).toSet().toList();

    return _buildSignAndShare(
      excel,
      filename: filename,
      firebaseToken: firebaseToken,
      tripIds: tripIds,
      records: records,
    );
  }

  // ── Assinar e compartilhar ───────────────────────────────────────────────

  /// Assina o relatório no backend (se token disponível) e compartilha.
  Future<File> _buildSignAndShare(
    Excel excel, {
    required String filename,
    required List<String> tripIds,
    required List<SpeedRecord> records,
    String? firebaseToken,
  }) async {
    // Tenta assinar no backend.
    if (firebaseToken != null && records.isNotEmpty) {
      try {
        final sigData = await _signReport(
          firebaseToken: firebaseToken,
          tripIds: tripIds,
          records: records,
        );
        if (sigData != null) {
          _buildSignatureSheet(
            excel,
            reportId: sigData['reportId'] as String,
            ntpTimestamp: sigData['ntpTimestamp'] as String,
            signature: sigData['signature'] as String,
            verifyUrl: sigData['verifyUrl'] as String,
            recordCount: records.length,
          );
        }
      } catch (e) {
        // Assinatura falhou — exporta mesmo assim sem a aba de assinatura.
        debugPrint('[ExportService] Assinatura digital falhou: $e');
      }
    }

    return _saveAndShare(excel, filename: filename);
  }

  /// Chama POST /reports/sign no backend Railway.
  Future<Map<String, dynamic>?> _signReport({
    required String firebaseToken,
    required List<String> tripIds,
    required List<SpeedRecord> records,
  }) async {
    // Constrói lista de hashes para assinatura canônica.
    final hashes = records
        .where((r) => r.hash != null)
        .map((r) => r.hash!)
        .toList();

    if (hashes.isEmpty) return null;

    final response = await http
        .post(
          Uri.parse('${ApiConfig.baseUrl}/reports/sign'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $firebaseToken',
          },
          body: jsonEncode({
            'tripIds': tripIds,
            'recordHashes': hashes,
            'recordCount': records.length,
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    debugPrint('[ExportService] /reports/sign → ${response.statusCode}: ${response.body}');
    return null;
  }

  Future<File> _saveAndShare(Excel excel, {required String filename}) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Não foi possível gerar o arquivo Excel.');
    }
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        )
      ],
      subject: 'Relatório de velocidade — Tracking Velocidade',
      text:
          'Segue o relatório com os dados de GPS para uso como prova documental.',
    );

    return file;
  }
}

