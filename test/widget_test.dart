import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/core/theme/app_colors.dart';
import 'package:wara2a/features/invoice_capture/models/invoice_image_draft.dart';
import 'package:wara2a/features/invoice_capture/repositories/invoice_image_repository.dart';
import 'package:wara2a/main.dart';

void main() {
  testWidgets('renders the Arabic home experience', (tester) async {
    await tester.pumpWidget(Wara2aApp(imageRepository: _TestImageRepository()));
    await tester.pumpAndSettle();

    expect(find.text('أهلاً بك، تذكّر كل فاتورة.'), findsOneWidget);
    expect(find.text('إضافة فاتورة'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('opens the invoice source sheet from the home hero', (
    tester,
  ) async {
    await tester.pumpWidget(const Wara2aApp());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'إضافة فاتورة'));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('من أين نبدأ؟'), findsOneWidget);
    expect(find.text('تصوير فاتورة'), findsOneWidget);
    expect(find.text('اختيار من المعرض'), findsOneWidget);
  });

  testWidgets('opens notifications without navigating to settings', (
    tester,
  ) async {
    await tester.pumpWidget(const Wara2aApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.pumpAndSettle();

    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('الإشعارات'), findsOneWidget);
    expect(find.text('لا توجد إشعارات جديدة'), findsOneWidget);
  });

  testWidgets('keeps add invoice labels readable in dark mode', (tester) async {
    await tester.pumpWidget(Wara2aApp(imageRepository: _TestImageRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text('الرئيسية').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة فاتورة'));
    await tester.pumpAndSettle();

    final cameraLabel = tester.widget<Text>(find.text('تصوير فاتورة'));
    expect(cameraLabel.style?.color, AppColors.ink);
  });

  testWidgets('navigates through the presentation flow', (tester) async {
    await tester.pumpWidget(Wara2aApp(imageRepository: _TestImageRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('البحث').last);
    await tester.pumpAndSettle();
    expect(find.text('البحث'), findsWidgets);
    expect(find.text('عمليات البحث الأخيرة'), findsOneWidget);

    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    expect(find.text('الوضع الداكن'), findsOneWidget);
    expect(find.text('محرك استخراج الفواتير المحلي'), findsOneWidget);
    expect(
      find.text('الحجم التقريبي 550–650 ميجابايت (OCR + Qwen)'),
      findsOneWidget,
    );

    await tester.tap(find.text('الرئيسية').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة فاتورة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تصوير فاتورة'));
    await tester.pumpAndSettle();
    expect(find.text('راجع الصورة'), findsOneWidget);

    final useImageButton = find.widgetWithText(FilledButton, 'استخدام الصورة');
    final useImageLabel = tester.widget<Text>(find.text('استخدام الصورة'));
    expect(useImageLabel.maxLines, 1);
    expect(useImageLabel.softWrap, isFalse);
    await tester.ensureVisible(useImageButton);
    await tester.tap(useImageButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('نجهّز مسودة فاتورتك'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'عرض المسودة'));
    await tester.pumpAndSettle();
    expect(find.text('راجع الفاتورة'), findsOneWidget);

    await tester.drag(find.byType(ListView).last, const Offset(0, -700));
    await tester.pump();
    final saveButton = find.widgetWithText(FilledButton, 'تأكيد وحفظ الفاتورة');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الفاتورة'), findsOneWidget);
  });
}

class _TestImageRepository implements InvoiceImageRepository {
  @override
  Future<void> discardDraft(InvoiceImageDraft draft) async {}

  @override
  Future<InvoiceImageDraft?> pickImage(InvoiceImageSource source) async {
    return InvoiceImageDraft(
      id: 'test-draft',
      path: '/missing-test-image.jpg',
      source: source,
      mimeType: 'image/jpeg',
      byteLength: 1024,
      width: 1000,
      height: 1500,
      createdAt: DateTime(2026),
    );
  }

  @override
  Future<InvoiceImageDraft?> recoverLostData() async => null;
}
