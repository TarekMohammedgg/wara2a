import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ar'));
  }

  bool get isArabic => locale.languageCode == 'ar';

  String _value(String key) => (isArabic ? _ar : _en)[key] ?? key;

  String get appName => _value('appName');
  String get appTagline => _value('appTagline');
  String get greeting => _value('greeting');
  String get greetingSubtitle => _value('greetingSubtitle');
  String get totalInvoices => _value('totalInvoices');
  String get thisMonth => _value('thisMonth');
  String get recentInvoices => _value('recentInvoices');
  String get viewAll => _value('viewAll');
  String get addInvoice => _value('addInvoice');
  String get camera => _value('camera');
  String get gallery => _value('gallery');
  String get captureTitle => _value('captureTitle');
  String get captureBody => _value('captureBody');
  String get privateBadge => _value('privateBadge');
  String get offlineFirst => _value('offlineFirst');
  String get noCloud => _value('noCloud');
  String get home => _value('home');
  String get search => _value('search');
  String get notifications => _value('notifications');
  String get noNotifications => _value('noNotifications');
  String get notificationsBody => _value('notificationsBody');
  String get settings => _value('settings');
  String get searchHint => _value('searchHint');
  String get recentSearches => _value('recentSearches');
  String get searchResults => _value('searchResults');
  String get filter => _value('filter');
  String get amount => _value('amount');
  String get date => _value('date');
  String get documentType => _value('documentType');
  String get exactMatch => _value('exactMatch');
  String get semanticMatch => _value('semanticMatch');
  String get filteredMatch => _value('filteredMatch');
  String get noResults => _value('noResults');
  String get noResultsBody => _value('noResultsBody');
  String get addInvoiceTitle => _value('addInvoiceTitle');
  String get addInvoiceBody => _value('addInvoiceBody');
  String get useCamera => _value('useCamera');
  String get chooseGallery => _value('chooseGallery');
  String get cancel => _value('cancel');
  String get previewTitle => _value('previewTitle');
  String get previewBody => _value('previewBody');
  String get retake => _value('retake');
  String get useImage => _value('useImage');
  String get processingTitle => _value('processingTitle');
  String get processingBody => _value('processingBody');
  String get processingStepOne => _value('processingStepOne');
  String get processingStepTwo => _value('processingStepTwo');
  String get processingStepThree => _value('processingStepThree');
  String get showDraft => _value('showDraft');
  String get reviewTitle => _value('reviewTitle');
  String get reviewSubtitle => _value('reviewSubtitle');
  String get merchant => _value('merchant');
  String get purchaseDate => _value('purchaseDate');
  String get invoiceNumber => _value('invoiceNumber');
  String get total => _value('total');
  String get currency => _value('currency');
  String get warranty => _value('warranty');
  String get products => _value('products');
  String get addProduct => _value('addProduct');
  String get saveInvoice => _value('saveInvoice');
  String get fieldRequired => _value('fieldRequired');
  String get detailsTitle => _value('detailsTitle');
  String get edit => _value('edit');
  String get delete => _value('delete');
  String get detailsStoredLocally => _value('detailsStoredLocally');
  String get settingsTitle => _value('settingsTitle');
  String get appearance => _value('appearance');
  String get language => _value('language');
  String get arabic => _value('arabic');
  String get english => _value('english');
  String get darkMode => _value('darkMode');
  String get modelStatus => _value('modelStatus');
  String get modelReady => _value('modelReady');
  String get modelReadyDetails => _value('modelReadyDetails');
  String get modelChecking => _value('modelChecking');
  String get modelNotInstalled => _value('modelNotInstalled');
  String get modelArtifactBlocked => _value('modelArtifactBlocked');
  String get modelUnsupported => _value('modelUnsupported');
  String get modelVerificationFailed => _value('modelVerificationFailed');
  String get modelRuntimeUnavailable => _value('modelRuntimeUnavailable');
  String get modelError => _value('modelError');
  String get modelRequirement => _value('modelRequirement');
  String get modelRefresh => _value('modelRefresh');
  String get privacy => _value('privacy');
  String get privacyBody => _value('privacyBody');
  String get localStorage => _value('localStorage');
  String get localStorageBody => _value('localStorageBody');
  String get about => _value('about');
  String get version => _value('version');
  String get scanAgain => _value('scanAgain');
  String get invoiceImage => _value('invoiceImage');
  String get invoiceSummary => _value('invoiceSummary');
  String get sourceCamera => _value('sourceCamera');
  String get sourceGallery => _value('sourceGallery');
  String get chooseAnotherSource => _value('chooseAnotherSource');
  String get captureUnsupportedImage => _value('captureUnsupportedImage');
  String get captureImageTooLarge => _value('captureImageTooLarge');
  String get captureInvalidDimensions => _value('captureInvalidDimensions');
  String get captureCorruptedImage => _value('captureCorruptedImage');
  String get capturePickerError => _value('capturePickerError');
  String get captureRecoveryError => _value('captureRecoveryError');
  String get savedJustNow => _value('savedJustNow');
  String get searchModelNote => _value('searchModelNote');
  String get recentQueryMerchant => _value('recentQueryMerchant');
  String get recentQueryAmount => _value('recentQueryAmount');
  String get recentQueryCategory => _value('recentQueryCategory');

  String invoicesCount(int count) {
    if (isArabic) return '$count فاتورة';
    return '$count invoices';
  }

  String searchMatches(int count) {
    if (isArabic) return '$count نتائج مطابقة';
    return '$count matching results';
  }

  static const _ar = <String, String>{
    'appName': 'wara2a',
    'appTagline': 'ذكاء فواتيرك، على جهازك',
    'greeting': 'أهلاً بك، تذكّر كل فاتورة.',
    'greetingSubtitle': 'صوّر فاتورتك أو أضفها من المعرض، والباقي علينا.',
    'totalInvoices': 'إجمالي الفواتير',
    'thisMonth': 'هذا الشهر',
    'recentInvoices': 'الفواتير الأخيرة',
    'viewAll': 'عرض الكل',
    'addInvoice': 'إضافة فاتورة',
    'camera': 'الكاميرا',
    'gallery': 'المعرض',
    'captureTitle': 'أضف فاتورة جديدة',
    'captureBody': 'اختر مصدر الصورة. كل شيء يظل على جهازك.',
    'privateBadge': 'خصوصيتك أولاً',
    'offlineFirst': 'يعمل بدون إنترنت',
    'noCloud': 'لا توجد سحابة',
    'home': 'الرئيسية',
    'search': 'البحث',
    'notifications': 'الإشعارات',
    'noNotifications': 'لا توجد إشعارات جديدة',
    'notificationsBody': 'سنخبرك هنا إذا احتاجت فاتورة إلى مراجعة.',
    'settings': 'الإعدادات',
    'searchHint': 'ابحث عن متجر، منتج، أو مبلغ...',
    'recentSearches': 'عمليات البحث الأخيرة',
    'searchResults': 'نتائج البحث',
    'filter': 'فلترة',
    'amount': 'المبلغ',
    'date': 'التاريخ',
    'documentType': 'نوع المستند',
    'exactMatch': 'تطابق مباشر',
    'semanticMatch': 'تطابق بالمعنى',
    'filteredMatch': 'نتيجة مفلترة',
    'noResults': 'لا توجد نتائج بعد',
    'noResultsBody': 'جرّب البحث باسم متجر أو منتج مختلف.',
    'addInvoiceTitle': 'من أين نبدأ؟',
    'addInvoiceBody': 'اختر صورة فاتورة من الكاميرا أو المعرض.',
    'useCamera': 'تصوير فاتورة',
    'chooseGallery': 'اختيار من المعرض',
    'cancel': 'إلغاء',
    'previewTitle': 'راجع الصورة',
    'previewBody': 'تأكد أن الفاتورة واضحة وكل الحواف ظاهرة قبل التحليل.',
    'retake': 'إعادة التصوير',
    'useImage': 'استخدام الصورة',
    'processingTitle': 'نجهّز مسودة فاتورتك',
    'processingBody': 'يتم التحليل على جهازك فقط. راجع كل حقل قبل الحفظ.',
    'processingStepOne': 'تجهيز الصورة',
    'processingStepTwo': 'قراءة النص العربي والإنجليزي',
    'processingStepThree': 'تحضير المسودة للمراجعة',
    'showDraft': 'عرض المسودة',
    'reviewTitle': 'راجع الفاتورة',
    'reviewSubtitle': 'هذه مسودة قابلة للتعديل. لن يتم الحفظ إلا بعد تأكيدك.',
    'merchant': 'اسم المتجر',
    'purchaseDate': 'تاريخ الشراء',
    'invoiceNumber': 'رقم الفاتورة',
    'total': 'الإجمالي',
    'currency': 'العملة',
    'warranty': 'الضمان',
    'products': 'المنتجات',
    'addProduct': 'إضافة منتج',
    'saveInvoice': 'تأكيد وحفظ الفاتورة',
    'fieldRequired': 'هذا الحقل مطلوب',
    'detailsTitle': 'تفاصيل الفاتورة',
    'edit': 'تعديل',
    'delete': 'حذف',
    'detailsStoredLocally': 'محفوظة على جهازك فقط',
    'settingsTitle': 'الإعدادات',
    'appearance': 'المظهر',
    'language': 'اللغة',
    'arabic': 'العربية',
    'english': 'English',
    'darkMode': 'الوضع الداكن',
    'modelStatus': 'محرك استخراج الفواتير المحلي',
    'modelReady': 'جاهز للاستخدام بدون إنترنت',
    'modelReadyDetails':
        'تم التحقق من ملفات OCR وأبلغ مفسّر النص المحلي أنه متاح.',
    'modelChecking': 'جارٍ التحقق من المحرك المحلي',
    'modelNotInstalled': 'نماذج قراءة الفواتير غير مثبتة',
    'modelArtifactBlocked': 'ملف Qwen المتوافق مع LiteRT-LM غير متاح بعد',
    'modelUnsupported': 'الاستخراج المحلي غير مدعوم على هذا الجهاز حالياً',
    'modelVerificationFailed': 'فشل التحقق من ملفات النماذج',
    'modelRuntimeUnavailable': 'محرك قراءة الفواتير غير متاح',
    'modelError': 'تعذر فحص حالة النماذج',
    'modelRequirement':
        'يتطلب نحو 21 م.ب لملفات OCR وملف Qwen بصيغة .litertlm تم اختباره والتحقق منه.',
    'modelRefresh': 'إعادة التحقق',
    'modelSize': 'الحجم يعتمد على ملفات OCR ونموذج Qwen المثبت',
    'installModel': 'إدارة النموذج',
    'privacy': 'الخصوصية',
    'privacyBody':
        'الصور والبيانات لا تغادر جهازك. لا حسابات ولا تحليلات ولا خوادم خارجية.',
    'localStorage': 'التخزين المحلي',
    'localStorageBody': 'يتم حفظ فواتيرك داخل مساحة التطبيق الآمنة.',
    'about': 'عن wara2a',
    'version': 'الإصدار التجريبي 0.1.0',
    'scanAgain': 'مسح فاتورة أخرى',
    'invoiceImage': 'صورة الفاتورة',
    'invoiceSummary': 'ملخص الفاتورة',
    'sourceCamera': 'من الكاميرا',
    'sourceGallery': 'من المعرض',
    'chooseAnotherSource': 'اختيار مصدر آخر',
    'captureUnsupportedImage': 'اختر صورة فاتورة بصيغة JPEG أو PNG أو WebP.',
    'captureImageTooLarge': 'اختر صورة أصغر من 15 ميجابايت.',
    'captureInvalidDimensions': 'اختر صورة فاتورة واضحة بأبعاد مناسبة.',
    'captureCorruptedImage': 'تعذر فتح الصورة. اختر صورة أخرى.',
    'capturePickerError': 'تعذر فتح الكاميرا أو المعرض. حاول مرة أخرى.',
    'captureRecoveryError': 'تعذر استعادة الصورة. اخترها مرة أخرى.',
    'savedJustNow': 'تم الحفظ منذ لحظات',
    'searchModelNote': 'البحث يعمل محلياً ويحافظ على خصوصيتك.',
    'recentQueryMerchant': 'سامسونج',
    'recentQueryAmount': 'أكثر من ١٠٠٠ جنيه',
    'recentQueryCategory': 'إلكترونيات',
  };

  static const _en = <String, String>{
    'appName': 'wara2a',
    'appTagline': 'Invoice intelligence, on-device',
    'greeting': 'Welcome back, keep every receipt.',
    'greetingSubtitle': 'Capture an invoice or choose one from your gallery.',
    'totalInvoices': 'Total invoices',
    'thisMonth': 'This month',
    'recentInvoices': 'Recent invoices',
    'viewAll': 'View all',
    'addInvoice': 'Add invoice',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'captureTitle': 'Add a new invoice',
    'captureBody': 'Choose a source. Everything stays on your device.',
    'privateBadge': 'Privacy first',
    'offlineFirst': 'Works offline',
    'noCloud': 'No cloud',
    'home': 'Home',
    'search': 'Search',
    'notifications': 'Notifications',
    'noNotifications': 'No new notifications',
    'notificationsBody':
        'We will let you know here if an invoice needs your attention.',
    'settings': 'Settings',
    'searchHint': 'Search for a store, product, or amount...',
    'recentSearches': 'Recent searches',
    'searchResults': 'Search results',
    'filter': 'Filter',
    'amount': 'Amount',
    'date': 'Date',
    'documentType': 'Document type',
    'exactMatch': 'Direct match',
    'semanticMatch': 'Meaning match',
    'filteredMatch': 'Filtered result',
    'noResults': 'No results yet',
    'noResultsBody': 'Try searching for a different store or product.',
    'addInvoiceTitle': 'Where should we start?',
    'addInvoiceBody': 'Choose an invoice image from camera or gallery.',
    'useCamera': 'Take a photo',
    'chooseGallery': 'Choose from gallery',
    'cancel': 'Cancel',
    'previewTitle': 'Review the image',
    'previewBody': 'Make sure the invoice is clear and all edges are visible.',
    'retake': 'Retake',
    'useImage': 'Use this image',
    'processingTitle': 'Preparing your invoice draft',
    'processingBody':
        'Analysis runs only on your device. Review every field before saving.',
    'processingStepOne': 'Preparing image',
    'processingStepTwo': 'Reading Arabic and English text',
    'processingStepThree': 'Preparing the review draft',
    'showDraft': 'View draft',
    'reviewTitle': 'Review invoice',
    'reviewSubtitle':
        'This draft is editable. It will not be saved until you confirm.',
    'merchant': 'Merchant',
    'purchaseDate': 'Purchase date',
    'invoiceNumber': 'Invoice number',
    'total': 'Total',
    'currency': 'Currency',
    'warranty': 'Warranty',
    'products': 'Products',
    'addProduct': 'Add product',
    'saveInvoice': 'Confirm and save invoice',
    'fieldRequired': 'This field is required',
    'detailsTitle': 'Invoice details',
    'edit': 'Edit',
    'delete': 'Delete',
    'detailsStoredLocally': 'Stored only on your device',
    'settingsTitle': 'Settings',
    'appearance': 'Appearance',
    'language': 'Language',
    'arabic': 'العربية',
    'english': 'English',
    'darkMode': 'Dark mode',
    'modelStatus': 'Local invoice extraction engine',
    'modelReady': 'Ready to use offline',
    'modelReadyDetails':
        'OCR files are verified and the local text interpreter reports ready.',
    'modelChecking': 'Checking the local engine',
    'modelNotInstalled': 'Invoice-reading models are not installed',
    'modelArtifactBlocked':
        'A LiteRT-LM-compatible Qwen file is not available yet',
    'modelUnsupported': 'Local extraction is not supported on this device yet',
    'modelVerificationFailed': 'Model file verification failed',
    'modelRuntimeUnavailable': 'The invoice-reading runtime is unavailable',
    'modelError': 'Could not inspect local model status',
    'modelRequirement':
        'Requires about 21 MB of OCR files and a tested, verified Qwen .litertlm file.',
    'modelRefresh': 'Check again',
    'modelSize': 'Size depends on the installed OCR files and Qwen model',
    'installModel': 'Manage model',
    'privacy': 'Privacy',
    'privacyBody':
        'Images and data never leave your device. No accounts, analytics, or external servers.',
    'localStorage': 'Local storage',
    'localStorageBody': 'Your invoices are stored inside the app sandbox.',
    'about': 'About wara2a',
    'version': 'Beta 0.1.0',
    'scanAgain': 'Scan another invoice',
    'invoiceImage': 'Invoice image',
    'invoiceSummary': 'Invoice summary',
    'sourceCamera': 'From camera',
    'sourceGallery': 'From gallery',
    'chooseAnotherSource': 'Choose another source',
    'captureUnsupportedImage': 'Choose a JPEG, PNG, or WebP invoice image.',
    'captureImageTooLarge': 'Choose an image smaller than 15 MB.',
    'captureInvalidDimensions':
        'Choose a clear invoice image with suitable dimensions.',
    'captureCorruptedImage':
        'This image could not be opened. Choose another image.',
    'capturePickerError':
        'The camera or gallery could not be opened. Try again.',
    'captureRecoveryError':
        'The image could not be recovered. Choose it again.',
    'savedJustNow': 'Saved moments ago',
    'searchModelNote': 'Search runs locally and protects your privacy.',
    'recentQueryMerchant': 'Samsung',
    'recentQueryAmount': 'Over EGP 1,000',
    'recentQueryCategory': 'Electronics',
  };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      const ['ar', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
