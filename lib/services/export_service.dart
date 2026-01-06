import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart' as intl;
import '../models/expense_model.dart';
import '../models/budget_model.dart';

class ExportService {
  static Future<void> exportToPdf({
    required String userName,
    required List<ExpenseModel> expenses,
    required List<BudgetModel> budgets,
    required String monthName,
    required int year,
    required double totalBudget,
    required double totalSpent,
    required String currency,
  }) async {
    try {
      final pdf = pw.Document();
      
      // Use PdfGoogleFonts for more reliable Arabic support
      final font = await PdfGoogleFonts.cairoRegular();
      final boldFont = await PdfGoogleFonts.cairoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(
            base: font,
            bold: boldFont,
          ),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تقرير المصاريف الشهري', style: pw.TextStyle(fontSize: 24, font: boldFont)),
                    pw.Text('Balanceer', style: pw.TextStyle(fontSize: 20, color: PdfColors.blue)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('المستخدِم: $userName'),
                      pw.Text('الفترة: $monthName $year'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('إجمالي الميزانية: ${totalBudget.toStringAsFixed(2)} $currency'),
                      pw.Text('إجمالي المصروف: ${totalSpent.toStringAsFixed(2)} $currency'),
                      pw.Text('المتبقي: ${(totalBudget - totalSpent).toStringAsFixed(2)} $currency', 
                        style: pw.TextStyle(color: (totalBudget - totalSpent) >= 0 ? PdfColors.green : PdfColors.red)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.TableHelper.fromTextArray(
                headers: ['التاريخ', 'الفئة', 'الوصف', 'المبلغ'],
                data: expenses.map((e) => [
                  intl.DateFormat('yyyy-MM-dd').format(e.expenseDate),
                  e.displayName,
                  e.notes ?? '',
                  '${e.amount.toStringAsFixed(2)} $currency',
                ]).toList(),
                headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                cellAlignment: pw.Alignment.centerRight,
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Balanceer_Report_${monthName}_$year.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'تقرير مصاريف شهر $monthName $year');
    } catch (e) {
      print('Error exporting PDF: $e');
      rethrow;
    }
  }

  static Future<void> exportToExcel({
    required List<ExpenseModel> expenses,
    required String monthName,
    required int year,
    required String currency,
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Expenses'];

    // Add headers
    sheet.appendRow([
      TextCellValue('التاريخ'),
      TextCellValue('الفئة'),
      TextCellValue('الوصف'),
      TextCellValue('المبلغ ($currency)'),
    ]);

    // Add data
    for (var e in expenses) {
      sheet.appendRow([
        TextCellValue(intl.DateFormat('yyyy-MM-dd').format(e.expenseDate)),
        TextCellValue(e.displayName),
        TextCellValue(e.notes ?? ''),
        DoubleCellValue(e.amount),
      ]);
    }

    final output = await getTemporaryDirectory();
    final fileName = "Balanceer_Expenses_$monthName$year.xlsx";
    final file = File("${output.path}/$fileName");
    
    final bytes = excel.encode();
    if (bytes != null) {
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'بيانات مصاريف شهر $monthName $year');
    }
  }
  static Future<void> exportDebtsToPdf({
    required String userName,
    required List<DebtModel> debts,
    required String currency,
  }) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.cairoRegular();
      final boldFont = await PdfGoogleFonts.cairoBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
            return [
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('تقرير الديون', style: pw.TextStyle(fontSize: 24, font: boldFont)),
                    pw.Text('Balanceer', style: pw.TextStyle(fontSize: 20, color: PdfColors.blue)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('المستخدِم: $userName'),
              pw.Text('تاريخ التقرير: ${intl.DateFormat('yyyy-MM-dd').format(DateTime.now())}'),
              pw.SizedBox(height: 30),
              
              pw.Text('الديون', style: pw.TextStyle(fontSize: 18, font: boldFont)),
              pw.SizedBox(height: 10),
              
              pw.TableHelper.fromTextArray(
                headers: ['النوع', 'الاسم', 'المبلغ', 'التاريخ', 'الحالة'],
                data: debts.map((d) => [
                  d.type == DebtType.credit ? 'دين لي' : 'دين علي',
                  d.personName,
                  '${d.amount.toStringAsFixed(2)} $currency',
                  intl.DateFormat('yyyy-MM-dd').format(d.debtDate),
                  d.isPaid ? 'تم السداد' : 'غير مسدد',
                ]).toList(),
                headerStyle: pw.TextStyle(font: boldFont, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                cellAlignment: pw.Alignment.centerRight,
              ),
            ];
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final file = File("${output.path}/Balanceer_Debts_${DateTime.now().millisecondsSinceEpoch}.pdf");
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles([XFile(file.path)], text: 'تقرير الديون - Balanceer');
    } catch (e) {
      print('Error exporting Debts PDF: $e');
      rethrow;
    }
  }
}
