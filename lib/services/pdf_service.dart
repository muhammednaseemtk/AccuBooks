import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../core/utils/currency_utils.dart';
import '../core/utils/date_utils.dart';
import '../models/company_model.dart';
import '../models/sales_invoice_model.dart';

class PdfService {
  /// Generate a PDF document bytes for a Sales Invoice
  static Future<Uint8List> generateInvoicePdf({
    required CompanyModel company,
    required SalesInvoiceModel invoice,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            // Header: Company details & Invoice label
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      company.name,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E3A8A'),
                      ),
                    ),
                    if (company.address != null) ...[
                      pw.SizedBox(height: 4),
                      pw.Text(company.address!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                    if (company.phone != null || company.email != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text('${company.phone ?? ''} | ${company.email ?? ''}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                    if (company.taxNumber != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text('GSTIN / Tax ID: ${company.taxNumber}',
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    ],
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'TAX INVOICE',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#1E3A8A'),
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text('Invoice #: ${invoice.invoiceNumber}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Date: ${AppDateUtils.formatInvoice(invoice.invoiceDate)}',
                        style: const pw.TextStyle(fontSize: 10)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: invoice.isPaid ? PdfColors.green100 : PdfColors.amber100,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                      ),
                      child: pw.Text(
                        invoice.paymentStatus.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: invoice.isPaid ? PdfColors.green800 : PdfColors.amber900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey300, thickness: 1),
            pw.SizedBox(height: 12),

            // Bill To Section
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColor.fromHex('#F8FAFC'),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('BILL TO:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey600)),
                        pw.SizedBox(height: 4),
                        pw.Text(invoice.customerName ?? 'Customer',
                            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        if (invoice.customerAddress != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(invoice.customerAddress!, style: const pw.TextStyle(fontSize: 10)),
                        ],
                        if (invoice.customerPhone != null) ...[
                          pw.SizedBox(height: 2),
                          pw.Text('Phone: ${invoice.customerPhone}', style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Table of Items
            pw.TableHelper.fromTextArray(
              headers: ['#', 'ITEM & DESCRIPTION', 'QTY', 'RATE', 'TAX %', 'TOTAL'],
              data: List.generate(invoice.items.length, (index) {
                final item = invoice.items[index];
                return [
                  (index + 1).toString(),
                  item.productName ?? 'Product',
                  '${item.quantity} ${item.unit ?? ''}'.trim(),
                  CurrencyUtils.format(item.rate, symbol: company.currency),
                  '${item.taxRate}%',
                  CurrencyUtils.format(item.total, symbol: company.currency),
                ];
              }),
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('#1E3A8A')),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),

            pw.SizedBox(height: 16),

            // Totals Row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Notes & Terms
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
                        pw.Text('Notes:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 2),
                        pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        pw.SizedBox(height: 10),
                      ],
                      pw.Text('Terms & Conditions:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('1. Goods once sold will not be taken back.\n2. Payment is due within standard credit terms.\n3. Subject to local jurisdiction.',
                          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),

                // Numerical Totals
                pw.Expanded(
                  flex: 2,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F8FAFC'),
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      children: [
                        _buildTotalRow('Subtotal', CurrencyUtils.format(invoice.subtotal, symbol: company.currency)),
                        if (invoice.discount > 0)
                          _buildTotalRow('Discount', '- ${CurrencyUtils.format(invoice.discount, symbol: company.currency)}'),
                        _buildTotalRow('Tax (GST)', CurrencyUtils.format(invoice.taxAmount, symbol: company.currency)),
                        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                        _buildTotalRow('Grand Total', CurrencyUtils.format(invoice.grandTotal, symbol: company.currency), isBold: true),
                        _buildTotalRow('Amount Paid', CurrencyUtils.format(invoice.paidAmount, symbol: company.currency)),
                        pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                        _buildTotalRow('Balance Due', CurrencyUtils.format(invoice.balanceAmount, symbol: company.currency), isBold: true),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 40),

            // Authorized Signatory
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Customer Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Column(
                  children: [
                    pw.Text('For ${company.name}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 28),
                    pw.Text('Authorized Signatory', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
          ];
        },
      ),
    );

    return await pdf.save();
  }

  static pw.Widget _buildTotalRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  /// Print invoice directly to printer or OS print dialog
  static Future<void> printInvoice({
    required CompanyModel company,
    required SalesInvoiceModel invoice,
  }) async {
    final pdfBytes = await generateInvoicePdf(company: company, invoice: invoice);
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfBytes,
      name: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }

  /// Share / Save PDF file
  static Future<void> shareInvoicePdf({
    required CompanyModel company,
    required SalesInvoiceModel invoice,
  }) async {
    final pdfBytes = await generateInvoicePdf(company: company, invoice: invoice);
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Invoice_${invoice.invoiceNumber}.pdf',
    );
  }
}
