clinic_app/
│
├── README.md                                    ← تعليمات التثبيت والتشغيل
├── pubspec.yaml                                 ← تبعيات المشروع
├── STRUCTURE.md                                 ← هذا الملف
│
├── database/
│   └── schema.sql                               ← مخطط قاعدة البيانات (13 جدول)
│
├── assets/
│   ├── fonts/                                   ← ضع هنا ملفات خط Cairo
│   └── images/                                  ← الصور (اختياري)
│
└── lib/
    │
    ├── main.dart                                ← نقطة البداية
    │
    ├── core/
    │   ├── database/
    │   │   ├── database_helper.dart             ← SQLite Singleton + CRUD + Backup + Audit
    │   │   └── database_provider.dart           ← Riverpod Provider
    │   ├── error/
    │   │   └── failures.dart                    ← Domain Failures
    │   ├── theme/
    │   │   └── app_theme.dart                   ← Material 3 + AppColors + AppSpacing
    │   ├── router/
    │   │   └── app_router.dart                  ← GoRouter (13 route)
    │   ├── utils/
    │   │   └── date_utils.dart
    │   ├── providers/
    │   │   ├── repository_providers.dart        ← كل Repository Providers
    │   │   ├── service_providers.dart           ← كل Service Providers + AsyncNotifiers
    │   │   └── export_providers.dart            ← PDF/Excel Providers
    │   └── services/
    │       ├── backup_service.dart              ← Backup + Restore + Auto-backup + Verify
    │       ├── pdf_export_service.dart          ← Arabic RTL PDF (فواتير + تقارير)
    │       └── excel_export_service.dart        ← Excel متعدد الأوراق
    │
    ├── shared/
    │   └── widgets/
    │       ├── app_widgets.dart                 ← PrimaryButton, AppCard, AppTable,
    │       │                                       AppTextField, StatusChip, EmptyState...
    │       ├── app_shell.dart                   ← Sidebar (13 عنصر) + TopBar
    │       └── export_button.dart               ← زر تصدير PDF/Excel موحد
    │
    └── features/
        │
        ├── dashboard/
        │   └── presentation/screens/
        │       └── dashboard_screen.dart        ← إحصائيات يومية + خزينة + أداء الأطباء
        │
        ├── patients/
        │   ├── domain/
        │   │   ├── entities/patient.dart
        │   │   └── repositories/patient_repository.dart   ← Abstract
        │   ├── data/repositories/
        │   │   └── patient_repository_impl.dart           ← CRUD + Search + Audit
        │   └── presentation/screens/
        │       ├── patients_screen.dart                   ← جدول + بحث
        │       └── patient_form_screen.dart               ← نموذج إضافة/تعديل
        │
        ├── doctors/
        │   ├── domain/
        │   │   ├── entities/doctor.dart
        │   │   ├── repositories/doctor_repository.dart    ← Abstract
        │   │   └── services/doctor_revenue_service.dart   ← إيرادات + عمولة
        │   ├── data/repositories/
        │   │   └── doctor_repository_impl.dart
        │   └── presentation/screens/
        │       └── doctors_screen.dart                    ← جدول + Dialog CRUD
        │
        ├── procedures/                                    ★ جديد
        │   ├── domain/entities/procedure.dart
        │   ├── data/repositories/
        │   │   └── procedure_repository_impl.dart         ← CRUD + toggle active
        │   └── presentation/screens/
        │       └── procedures_screen.dart                 ← جدول + بحث + Switch
        │
        ├── appointments/                                  ★ جديد
        │   ├── domain/entities/appointment.dart           ← AppointmentStatus enum
        │   ├── data/repositories/
        │   │   └── appointment_repository_impl.dart       ← CRUD + status + counts
        │   └── presentation/screens/
        │       └── appointments_screen.dart               ← بطاقات + فلترة يومية
        │
        ├── visits/
        │   ├── domain/entities/visit.dart
        │   ├── data/repositories/
        │   │   └── visit_repository_impl.dart             ← CRUD + Lock + Procedures JOIN
        │   └── presentation/screens/
        │       └── visits_screen.dart                     ← جدول + نموذج + فلتر
        │
        ├── invoices/
        │   ├── domain/
        │   │   ├── entities/invoice.dart                  ← Invoice + InvoiceItem + Payment + Expense
        │   │   └── services/invoice_service.dart          ← Auto-create + Discount + Lock
        │   ├── data/repositories/
        │   │   └── invoice_repository_impl.dart           ← Transaction Payments + Recalculate
        │   └── presentation/screens/
        │       └── invoices_screen.dart                   ← جدول + تفاصيل + دفعات
        │
        ├── expenses/                                      ★ جديد
        │   ├── data/repositories/
        │   │   └── expense_repository_impl.dart           ← CRUD + categories
        │   └── presentation/screens/
        │       └── expenses_screen.dart                   ← جدول + فلترة + إجمالي
        │
        ├── inventory/                                     ★ جديد
        │   ├── domain/entities/inventory.dart             ← InventoryItem + StockMovement + CashBox
        │   ├── data/repositories/
        │   │   └── inventory_repository_impl.dart         ← Items + Movements Transaction + CashBox
        │   └── presentation/screens/
        │       └── inventory_screen.dart                  ← تبويبان: أصناف + حركات
        │
        ├── cash_box/                                      ★ جديد
        │   ├── domain/services/cash_box_service.dart      ← فتح/إغلاق تلقائي
        │   └── presentation/screens/
        │       └── cash_box_screen.dart                   ← تبويبان: اليوم + السجل
        │
        ├── reports/
        │   ├── domain/services/report_service.dart        ← يومي/شهري/سنوي/أطباء/إجراءات
        │   └── presentation/screens/
        │       └── reports_screen.dart                    ← 4 تبويبات + تصدير
        │
        ├── backup/
        │   └── presentation/screens/
        │       └── backup_screen.dart                     ← يدوي + تلقائي + استعادة + قائمة
        │
        └── settings/                                      ★ جديد
            └── presentation/screens/
                └── settings_screen.dart                   ← بيانات العيادة + VACUUM
