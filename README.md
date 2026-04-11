# 🏥 نظام إدارة العيادة الطبية
## Clinic Management System — Flutter Desktop (Windows)

---

## 📋 متطلبات النظام

| المتطلب | الإصدار |
|---------|---------|
| Flutter SDK | >= 3.10.0 |
| Dart SDK | >= 3.0.0 |
| Windows | 10 أو أحدث (64-bit) |
| Visual Studio | 2022 مع C++ Desktop Workload |
| Git | أي إصدار |

---

## 🚀 خطوات التثبيت (5 دقائق)

### 1. أنشئ مشروع Flutter جديد

```bash
flutter create clinic_app --platforms=windows
cd clinic_app
```

### 2. انسخ ملفات المشروع

استخرج الـ ZIP وانسخ المحتوى بالكامل داخل مجلد `clinic_app`:

```
clinic_app/
├── lib/          ← انسخ المجلد كاملاً
├── database/     ← انسخ المجلد كاملاً
├── assets/       ← انسخ المجلد كاملاً
└── pubspec.yaml  ← استبدل الملف الموجود
```

> ⚠️ الملفات الموجودة مثل `lib/main.dart` يجب استبدالها بالملفات الجديدة.

### 3. حمّل خط Cairo

- انتقل إلى: https://fonts.google.com/specimen/Cairo
- اضغط **Download family**
- ضع هذه الملفات داخل `assets/fonts/`:

```
assets/fonts/
├── Cairo-Regular.ttf   ← إلزامي
├── Cairo-Bold.ttf      ← إلزامي
├── Cairo-SemiBold.ttf  ← إلزامي
└── Cairo-Light.ttf     ← إلزامي
```

### 4. ثبّت الحزم

```bash
flutter pub get
```

### 5. شغّل التطبيق

```bash
flutter run -d windows
```

### 6. بناء نسخة الإنتاج (اختياري)

```bash
flutter build windows --release
```

الملف التنفيذي في:
```
build/windows/x64/runner/Release/clinic_app.exe
```

---

## 🗂️ هيكل المشروع الكامل

```
lib/
├── main.dart
│
├── core/
│   ├── database/
│   │   ├── database_helper.dart       ← SQLite singleton + CRUD + Backup
│   │   └── database_provider.dart     ← Riverpod provider
│   ├── error/
│   │   └── failures.dart              ← Domain failures
│   ├── theme/
│   │   └── app_theme.dart             ← Material 3 + Arabic RTL
│   ├── router/
│   │   └── app_router.dart            ← GoRouter (13 مسار)
│   ├── utils/
│   │   └── date_utils.dart
│   ├── providers/
│   │   ├── repository_providers.dart  ← كل Repository providers
│   │   ├── service_providers.dart     ← كل Service providers + Notifiers
│   │   └── export_providers.dart      ← PDF / Excel providers
│   └── services/
│       ├── backup_service.dart        ← Backup + Restore + Auto-backup
│       ├── pdf_export_service.dart    ← Arabic RTL PDF
│       └── excel_export_service.dart  ← Multi-sheet Excel
│
├── shared/
│   └── widgets/
│       ├── app_widgets.dart           ← Buttons, Cards, Tables, Forms, Dialogs
│       ├── app_shell.dart             ← Sidebar + TopBar layout
│       └── export_button.dart         ← PDF/Excel export popup button
│
└── features/
    ├── dashboard/        ← لوحة التحكم (إحصائيات + خزينة + أطباء)
    ├── patients/         ← المرضى (CRUD + بحث + soft delete)
    ├── doctors/          ← الأطباء (CRUD + عمولة)
    ├── procedures/       ← الإجراءات الطبية (CRUD + تفعيل/تعطيل) ★ جديد
    ├── appointments/     ← المواعيد (بطاقات + فلترة + تغيير حالة) ★ جديد
    ├── visits/           ← الزيارات (CRUD + قفل)
    ├── invoices/         ← الفواتير (CRUD + دفعات + قفل)
    ├── expenses/         ← المصروفات (CRUD + فئات + فلترة) ★ جديد
    ├── inventory/        ← المخزون (أصناف + حركات + تحذير) ★ جديد
    ├── cash_box/         ← الخزينة (فتح/إغلاق + سجل) ★ جديد
    ├── reports/          ← التقارير (يومي/شهري/سنوي/أطباء)
    ├── backup/           ← النسخ الاحتياطي
    └── settings/         ← الإعدادات (بيانات العيادة + VACUUM) ★ جديد

database/
└── schema.sql            ← 13 جدول SQLite
```

---

## 🗄️ قاعدة البيانات

**الموقع التلقائي:**
```
<مجلد_التطبيق>/data/clinic.db
```

### الجداول:

| المجموعة | الجداول |
|----------|---------|
| الطبي | `patients` `doctors` `procedures` `appointments` `visits` `visit_procedures` |
| المحاسبة | `invoices` `invoice_items` `payments` `expenses` |
| المخزون | `items` `stock_movements` |
| النظام | `cash_box` `audit_log` `app_settings` |

---

## 🖥️ الشاشات (13 شاشة)

| # | الشاشة | الميزات الرئيسية |
|---|--------|-----------------|
| 1 | لوحة التحكم | إحصائيات يومية، خزينة، أداء الأطباء |
| 2 | المرضى | جدول، بحث، CRUD كامل |
| 3 | الأطباء | CRUD، نسبة عمولة |
| 4 | الإجراءات | CRUD، تفعيل/إيقاف، بحث |
| 5 | المواعيد | بطاقات ملونة، فلترة يومية، تغيير حالة سريع |
| 6 | الزيارات | CRUD، ربط بإجراءات وفواتير، قفل |
| 7 | الفواتير | CRUD، دفعات جزئية، قفل تلقائي |
| 8 | المصروفات | CRUD، فئات ذكية، فلترة + إجمالي |
| 9 | المخزون | أصناف + حركات، تحذير منخفض |
| 10 | الخزينة | فتح/إغلاق يومي، شريط تقدم، سجل |
| 11 | التقارير | يومي/شهري/سنوي/أطباء + تصدير |
| 12 | النسخ الاحتياطي | يدوي + تلقائي + استعادة |
| 13 | الإعدادات | بيانات العيادة، VACUUM |

---

## 📤 التصدير

| النوع | الملفات |
|-------|---------|
| **PDF عربي RTL** | فواتير، تقارير يومية، تقارير فترة، إيرادات الأطباء |
| **Excel متعدد الأوراق** | مرضى، فواتير، تقارير، إيرادات الأطباء |

للاستخدام: زر **تصدير** في كل شاشة يفتح قائمة PDF / Excel.

---

## 🔒 قواعد الأعمال

```
المسار الكامل:
  زيارة → إجراءات → فاتورة (تلقائية) → دفعات

حالات الفاتورة:
  unpaid  ← لا دفعات
  partial ← دفعات جزئية
  paid    ← مدفوعة بالكامل (تُقفل تلقائياً)

حماية البيانات:
  ✗ لا دفع أكثر من المتبقي (overpayment protection)
  ✗ لا تعديل زيارة مقفلة
  ✗ لا تعديل فاتورة مقفلة
  ✗ لا إخراج مخزون أكثر من المتاح (negative stock protection)
  ✓ سجل تدقيق كامل لكل INSERT/UPDATE/DELETE
```

---

## 📦 الحزم المستخدمة

```yaml
sqflite_common_ffi: ^2.3.3    # SQLite للـ Desktop
flutter_riverpod: ^2.5.1      # إدارة الحالة
go_router: ^13.2.0            # التنقل
google_fonts: ^6.2.1          # خط Cairo
pdf: ^3.10.8                  # تصدير PDF
printing: ^5.13.1             # طباعة PDF
excel: ^4.0.3                 # تصدير Excel
file_picker: ^8.0.3           # اختيار ملفات/مجلدات
intl: ^0.19.0                 # تنسيق أرقام وتواريخ
```

---

## 🆘 المشاكل الشائعة

**MissingPluginException:**
```bash
flutter clean && flutter pub get && flutter run -d windows
```

**خطأ Visual Studio:**
ثبّت **Visual Studio 2022** مع:
- Desktop development with C++
- Windows 10 SDK (10.0.19041.0)

**الخط العربي لا يظهر:**
تأكد أن ملفات Cairo TTF موجودة في `assets/fonts/`

**قاعدة البيانات مقفلة:**
أغلق أي نسخة أخرى تعمل من نفس الـ executable.

---

*Flutter 3 + Riverpod + Clean Architecture + SQLite*
*دعم كامل للعربية RTL — خط Cairo*
