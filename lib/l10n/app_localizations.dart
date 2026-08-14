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
  String get totalInvoices => _value('totalInvoices');
  String get thisMonth => _value('thisMonth');
  String get recentInvoices => _value('recentInvoices');
  String get viewAll => _value('viewAll');
  String get addInvoice => _value('addInvoice');
  String get camera => _value('camera');
  String get gallery => _value('gallery');
  String get captureTitle => _value('captureTitle');
  String get captureBody => _value('captureBody');
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
  String get exactMatch => _value('exactMatch');
  String get semanticMatch => _value('semanticMatch');
  String get filteredMatch => _value('filteredMatch');
  String get noResults => _value('noResults');
  String get noResultsBody => _value('noResultsBody');
  String get noInvoices => _value('noInvoices');
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
  String get processingManualTitle => _value('processingManualTitle');
  String get processingManualBody => _value('processingManualBody');
  String get processingFailureTitle => _value('processingFailureTitle');
  String get processingFailureBody => _value('processingFailureBody');
  String get continueManualReview => _value('continueManualReview');
  String get retry => _value('retry');
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
  String get product => _value('product');
  String get productName => _value('productName');
  String get quantity => _value('quantity');
  String get unitPrice => _value('unitPrice');
  String get lineTotal => _value('lineTotal');
  String get invalidValue => _value('invalidValue');
  String get currencyCodeHint => _value('currencyCodeHint');
  String get manualReviewNotice => _value('manualReviewNotice');
  String get rawOcrText => _value('rawOcrText');
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
  String get extractionModeTitle => _value('extractionModeTitle');
  String get extractionModeLocal => _value('extractionModeLocal');
  String get extractionModeCloud => _value('extractionModeCloud');
  String get extractionModeLocalDetails => _value('extractionModeLocalDetails');
  String get extractionModeCloudDetails => _value('extractionModeCloudDetails');
  String get openRouterApiKeyLabel => _value('openRouterApiKeyLabel');
  String get openRouterApiKeyHint => _value('openRouterApiKeyHint');
  String get openRouterExperimentalNote => _value('openRouterExperimentalNote');
  String get cloudProcessingConsentTitle =>
      _value('cloudProcessingConsentTitle');
  String get cloudProcessingConsentBody => _value('cloudProcessingConsentBody');
  String get modelStatus => _value('modelStatus');
  String get modelReady => _value('modelReady');
  String get modelReadyDetails => _value('modelReadyDetails');
  String get modelChecking => _value('modelChecking');
  String get modelNotInstalled => _value('modelNotInstalled');
  String get modelUnsupported => _value('modelUnsupported');
  String get modelVerificationFailed => _value('modelVerificationFailed');
  String get modelRuntimeUnavailable => _value('modelRuntimeUnavailable');
  String get modelError => _value('modelError');
  String get modelRequirement => _value('modelRequirement');
  String get modelRefresh => _value('modelRefresh');
  String get modelInstall => _value('modelInstall');
  String get modelInstalling => _value('modelInstalling');
  String get modelInstallDownloading => _value('modelInstallDownloading');
  String get modelInstallVerifying => _value('modelInstallVerifying');
  String get modelInstallActivating => _value('modelInstallActivating');
  String get modelInstallCheckingStorage =>
      _value('modelInstallCheckingStorage');
  String get modelCancelInstall => _value('modelCancelInstall');
  String get modelRemove => _value('modelRemove');
  String get modelRemoving => _value('modelRemoving');
  String get modelRemoveConfirm => _value('modelRemoveConfirm');
  String get modelInstallFailed => _value('modelInstallFailed');
  String get modelSize => _value('modelSize');
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
  String get searchSuggestions => _value('searchSuggestions');
  String get applyFilters => _value('applyFilters');
  String get clearFilters => _value('clearFilters');
  String get minimumAmount => _value('minimumAmount');
  String get maximumAmount => _value('maximumAmount');
  String get purchaseDateFilter => _value('purchaseDateFilter');
  String get warrantyEndDateFilter => _value('warrantyEndDateFilter');
  String get semanticCalibrationRequired =>
      _value('semanticCalibrationRequired');
  String get semanticModelUnavailable => _value('semanticModelUnavailable');
  String get semanticQueryTooLong => _value('semanticQueryTooLong');
  String get semanticRuntimeFailure => _value('semanticRuntimeFailure');
  String get keywordFallback => _value('keywordFallback');
  String get searchError => _value('searchError');
  String get allCurrencies => _value('allCurrencies');
  String get selectRange => _value('selectRange');
  String get invalidAmountRange => _value('invalidAmountRange');
  String get reindexInvoices => _value('reindexInvoices');

  String invoicesCount(int count) {
    if (isArabic) return '$count فاتورة';
    return '$count invoices';
  }

  String searchMatches(int count) {
    if (isArabic) return '$count نتائج مطابقة';
    return '$count matching results';
  }

  String searchIndexPending(int count) {
    if (isArabic) return '$count فاتورة في انتظار الفهرسة بالمعنى.';
    return '$count invoices are waiting for semantic indexing.';
  }

  String get searchIndexRunning => _value('searchIndexRunning');
  String get searchIndexNow => _value('searchIndexNow');
  String searchIndexSucceeded(int count) {
    if (isArabic) return 'تم فهرسة $count فاتورة بنجاح.';
    return 'Indexed $count invoices successfully.';
  }

  String searchIndexPartial(int indexed, int remaining) {
    if (isArabic) {
      return 'فُهرس $indexed وبقي $remaining بانتظار الفهرسة.';
    }
    return 'Indexed $indexed; $remaining still pending.';
  }

  String get searchIndexModelNotReady => _value('searchIndexModelNotReady');
  String get searchIndexFailed => _value('searchIndexFailed');
  String get searchIndexAlreadyDone => _value('searchIndexAlreadyDone');

  static const _ar = <String, String>{
    'appName': 'wara2a',
    'totalInvoices': 'إجمالي الفواتير',
    'thisMonth': 'هذا الشهر',
    'recentInvoices': 'الفواتير الأخيرة',
    'viewAll': 'عرض الكل',
    'addInvoice': 'إضافة فاتورة',
    'camera': 'الكاميرا',
    'gallery': 'المعرض',
    'captureTitle': 'أضف فاتورة جديدة',
    'captureBody': 'التقط صورة للفاتورة أو اخترها من المعرض.',
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
    'exactMatch': 'تطابق مباشر',
    'semanticMatch': 'تطابق بالمعنى',
    'filteredMatch': 'نتيجة مفلترة',
    'noResults': 'لا توجد نتائج بعد',
    'noResultsBody': 'جرّب البحث باسم متجر أو منتج مختلف.',
    'noInvoices': 'لا توجد فواتير',
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
    'processingBody':
        'يتم إرسال صورة الفاتورة إلى OpenRouter للتحليل. راجع كل حقل قبل الحفظ.',
    'processingStepOne': 'تجهيز الصورة',
    'processingStepTwo': 'إرسال الصورة واستخراج الحقول',
    'processingStepThree': 'تحضير المسودة للمراجعة',
    'processingManualTitle': 'تعذر إكمال الاستخراج',
    'processingManualBody':
        'يمكنك متابعة المراجعة يدوياً. لن يتم حفظ أي شيء قبل تأكيدك.',
    'processingFailureTitle': 'توقف الاستخراج بأمان',
    'processingFailureBody': 'حاول مرة أخرى أو ارجع لاختيار صورة أوضح.',
    'continueManualReview': 'المتابعة بالمراجعة اليدوية',
    'retry': 'إعادة المحاولة',
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
    'product': 'المنتج',
    'productName': 'اسم المنتج',
    'quantity': 'الكمية',
    'unitPrice': 'سعر الوحدة',
    'lineTotal': 'إجمالي البند',
    'invalidValue': 'أدخل قيمة صحيحة أو اترك الحقل فارغاً.',
    'currencyCodeHint': 'استخدم رمز عملة من 3 أحرف مثل EGP.',
    'manualReviewNotice':
        'لم يكتمل الاستخراج الآلي. أدخل أو صحح الحقول يدوياً ثم راجعها قبل الحفظ.',
    'rawOcrText': 'النص المقروء من الصورة',
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
    'extractionModeTitle': 'طريقة استخراج الفاتورة',
    'extractionModeLocal': 'محلي',
    'extractionModeCloud': 'قراءة الفواتير',
    'extractionModeLocalDetails': '',
    'extractionModeCloudDetails': 'مطلوب لقراءة الفواتير والبحث بالمعنى.',
    'openRouterApiKeyLabel': 'مفتاح الخدمة من OpenRouter',
    'openRouterApiKeyHint': 'الصق المفتاح هنا',
    'openRouterExperimentalNote':
        'تُرسل صورة الفاتورة ونصوص البحث إلى OpenRouter عند تفعيل المعالجة السحابية.',
    'cloudProcessingConsentTitle': 'السماح بالمعالجة السحابية',
    'cloudProcessingConsentBody':
        'أفهم أن صور الفواتير ونصوص البحث قد تُرسل إلى OpenRouter.',
    'modelStatus': '',
    'modelReady': '',
    'modelReadyDetails': '',
    'modelChecking': '',
    'modelNotInstalled': '',
    'modelUnsupported': '',
    'modelVerificationFailed': '',
    'modelRuntimeUnavailable': '',
    'modelError': '',
    'modelRequirement': '',
    'modelRefresh': '',
    'modelInstall': '',
    'modelInstalling': '',
    'modelInstallDownloading': '',
    'modelInstallVerifying': '',
    'modelInstallActivating': '',
    'modelInstallCheckingStorage': '',
    'modelCancelInstall': '',
    'modelRemove': '',
    'modelRemoving': '',
    'modelRemoveConfirm': '',
    'modelInstallFailed': '',
    'modelSize': '',
    'installModel': '',
    'privacy': 'الخصوصية',
    'privacyBody':
        'تبقى الفواتير على جهازك، لكن قد تُرسل الصور ونصوص البحث إلى OpenRouter عند تفعيل المعالجة السحابية.',
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
    'searchModelNote':
        'تأتي النتائج من قاعدة بياناتك المحلية بعد إرسال نص الفاتورة إلى OpenRouter للفهرسة.',
    'recentQueryMerchant': 'سامسونج',
    'recentQueryAmount': 'أكثر من ١٠٠٠ جنيه',
    'recentQueryCategory': 'إلكترونيات',
    'searchSuggestions': 'اقتراحات للبحث',
    'applyFilters': 'تطبيق الفلاتر',
    'clearFilters': 'مسح الكل',
    'minimumAmount': 'أقل مبلغ',
    'maximumAmount': 'أعلى مبلغ',
    'purchaseDateFilter': 'نطاق تاريخ الشراء',
    'warrantyEndDateFilter': 'نطاق انتهاء الضمان',
    'semanticCalibrationRequired':
        'البحث بالمعنى متوقف حتى يعتمد حد المسافة على مجموعة تقييم من 100 استعلام على الأقل.',
    'semanticModelUnavailable':
        'محرك التضمين عبر OpenRouter غير جاهز. أضف مفتاح API من الإعدادات.',
    'semanticQueryTooLong': 'الاستعلام أطول من الحد الآمن للتضمين.',
    'semanticRuntimeFailure': 'تعذر تشغيل محرك البحث بالمعنى عبر OpenRouter.',
    'keywordFallback': 'تم عرض التطابقات المباشرة التي تحقق الفلاتر فقط.',
    'searchError': 'تعذر إكمال البحث',
    'allCurrencies': 'كل العملات',
    'selectRange': 'اختر نطاقاً',
    'invalidAmountRange': 'يجب ألا يكون الحد الأدنى أكبر من الحد الأقصى.',
    'searchIndexRunning': 'جارٍ فهرسة الفواتير بالمعنى…',
    'searchIndexNow': 'فهرسة الآن',
    'searchIndexModelNotReady':
        'تعذرت الفهرسة: محرك OpenRouter غير جاهز. أضف مفتاح API من الإعدادات.',
    'searchIndexFailed': 'تعذرت فهرسة بعض الفواتير. أعد المحاولة لاحقاً.',
    'searchIndexAlreadyDone': 'لا توجد فواتير معلّقة للفهرسة.',
    'reindexInvoices': 'فهرسة الفواتير المعلقة',
  };

  static const _en = <String, String>{
    'appName': 'wara2a',
    'totalInvoices': 'Total invoices',
    'thisMonth': 'This month',
    'recentInvoices': 'Recent invoices',
    'viewAll': 'View all',
    'addInvoice': 'Add invoice',
    'camera': 'Camera',
    'gallery': 'Gallery',
    'captureTitle': 'Add a new invoice',
    'captureBody':
        'Take a photo of the invoice or choose one from your gallery.',
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
    'exactMatch': 'Direct match',
    'semanticMatch': 'Meaning match',
    'filteredMatch': 'Filtered result',
    'noResults': 'No results yet',
    'noResultsBody': 'Try searching for a different store or product.',
    'noInvoices': 'No invoices',
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
        'The invoice image is sent to OpenRouter for analysis. Review every field before saving.',
    'processingStepOne': 'Preparing image',
    'processingStepTwo': 'Sending the image and extracting fields',
    'processingStepThree': 'Preparing the review draft',
    'processingManualTitle': 'Extraction could not finish',
    'processingManualBody':
        'You can continue with manual review. Nothing is saved before you confirm.',
    'processingFailureTitle': 'Extraction stopped safely',
    'processingFailureBody': 'Try again or go back and choose a clearer image.',
    'continueManualReview': 'Continue with manual review',
    'retry': 'Try again',
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
    'product': 'Product',
    'productName': 'Product name',
    'quantity': 'Quantity',
    'unitPrice': 'Unit price',
    'lineTotal': 'Line total',
    'invalidValue': 'Enter a valid value or leave the field blank.',
    'currencyCodeHint': 'Use a 3-letter currency code such as EGP.',
    'manualReviewNotice':
        'Automatic extraction did not finish. Enter or correct fields manually and review them before saving.',
    'rawOcrText': 'Text read from the image',
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
    'extractionModeTitle': 'Invoice extraction mode',
    'extractionModeLocal': 'Local',
    'extractionModeCloud': 'Invoice reading',
    'extractionModeLocalDetails': '',
    'extractionModeCloudDetails':
        'Needed to read invoices and search by meaning.',
    'openRouterApiKeyLabel': 'OpenRouter service key',
    'openRouterApiKeyHint': 'Paste your key here',
    'openRouterExperimentalNote':
        'Invoice images and search text are sent to OpenRouter when cloud processing is enabled.',
    'cloudProcessingConsentTitle': 'Allow cloud processing',
    'cloudProcessingConsentBody':
        'I understand that invoice images and search text may be sent to OpenRouter.',
    'modelStatus': '',
    'modelReady': '',
    'modelReadyDetails': '',
    'modelChecking': '',
    'modelNotInstalled': '',
    'modelUnsupported': '',
    'modelVerificationFailed': '',
    'modelRuntimeUnavailable': '',
    'modelError': '',
    'modelRequirement': '',
    'modelRefresh': '',
    'modelInstall': '',
    'modelInstalling': '',
    'modelInstallDownloading': '',
    'modelInstallVerifying': '',
    'modelInstallActivating': '',
    'modelInstallCheckingStorage': '',
    'modelCancelInstall': '',
    'modelRemove': '',
    'modelRemoving': '',
    'modelRemoveConfirm': '',
    'modelInstallFailed': '',
    'modelSize': '',
    'installModel': '',
    'privacy': 'Privacy',
    'privacyBody':
        'Invoices stay on your device, but images and search text may be sent to OpenRouter when cloud processing is enabled.',
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
    'searchModelNote':
        'Results come from your local database after invoice text is sent to OpenRouter for indexing.',
    'recentQueryMerchant': 'Samsung',
    'recentQueryAmount': 'Over EGP 1,000',
    'recentQueryCategory': 'Electronics',
    'searchSuggestions': 'Search suggestions',
    'applyFilters': 'Apply filters',
    'clearFilters': 'Clear all',
    'minimumAmount': 'Minimum amount',
    'maximumAmount': 'Maximum amount',
    'purchaseDateFilter': 'Purchase date range',
    'warrantyEndDateFilter': 'Warranty expiry range',
    'semanticCalibrationRequired':
        'Semantic search stays disabled until its distance threshold is approved on at least 100 labeled queries.',
    'semanticModelUnavailable':
        'OpenRouter embeddings are not ready. Add an API key in Settings.',
    'semanticQueryTooLong': 'The query exceeds the embedding safety limit.',
    'semanticRuntimeFailure': 'OpenRouter semantic search failed.',
    'keywordFallback':
        'Only exact keyword matches that satisfy the filters are shown.',
    'searchError': 'Search could not be completed',
    'allCurrencies': 'All currencies',
    'selectRange': 'Select a range',
    'invalidAmountRange': 'The minimum amount must not exceed the maximum.',
    'searchIndexRunning': 'Indexing invoices for semantic search…',
    'searchIndexNow': 'Index now',
    'searchIndexModelNotReady':
        'Indexing failed: OpenRouter embeddings are not ready. Add an API key in Settings.',
    'searchIndexFailed': 'Some invoices could not be indexed. Try again later.',
    'searchIndexAlreadyDone': 'No invoices are waiting for indexing.',
    'reindexInvoices': 'Index pending invoices',
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
