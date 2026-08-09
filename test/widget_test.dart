import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wara2a/main.dart';

void main() {
  testWidgets('renders the Arabic home experience', (tester) async {
    await tester.pumpWidget(const Wara2aApp());
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

  testWidgets('navigates through the presentation flow', (tester) async {
    await tester.pumpWidget(const Wara2aApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('البحث').last);
    await tester.pumpAndSettle();
    expect(find.text('البحث'), findsWidgets);
    expect(find.text('عمليات البحث الأخيرة'), findsOneWidget);

    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    expect(find.text('الوضع الداكن'), findsOneWidget);
    expect(find.text('محرك الذكاء المحلي'), findsOneWidget);

    await tester.tap(find.text('الرئيسية').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'إضافة فاتورة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تصوير فاتورة'));
    await tester.pumpAndSettle();
    expect(find.text('راجع الصورة'), findsOneWidget);

    final useImageButton = find.widgetWithText(FilledButton, 'استخدام الصورة');
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
