# المانيوال المعماري — الجزء الثاني
# (تكملة: الشاشات المتبقية، الاعتماديات، CI/CD، والنشر)

> هذا الملف يكمل [الجزء الأول](./architecture_manual.md). يُفضَّل قراءة الجزأين معاً.

---

## 📱 الشاشات المتبقية — تفصيل كامل

### `room_settings_screen.dart` — إعدادات إنشاء الغرفة العالمية

**تُفتح من:** زر "تشغيل خادم عالمي" في `start_screen.dart`  
**لا تستقبل معاملات (Parameters):** تقرأ كل ما تحتاجه من Hive و Providers

**الحالة الداخلية:**
```dart
bool _isPublic  = true;   // غرفة عامة أم خاصة
int _redCount   = 1;      // عدد اللاعبين الأحمر
int _blueCount  = 0;      // عدد اللاعبين الأزرق
String _roomCode;         // كود الغرفة المُولَّد تلقائياً
TextEditingController _roomNameController; // اسم الغرفة
```

**`_generateRoomCode()`:** ينشئ كوداً عشوائياً من 5 أحرف/أرقام كبيرة (A-Z + 0-9).

**`_handleCreateAndJoin()`** — الدالة الرئيسية:
```
 1. التحقق: عدد اللاعبين الكلي >= 2
 2. التحقق: اسم الغرفة غير فارغ
 3. إعادة محاولة تأكيد جلسة Appwrite المجهولة (في حال فشلها أثناء بدء التطبيق)
 4. جلب هوية المستخدم من Appwrite Account
 5. قراءة اسم المضيف من Hive (أو استخدام الاسم المُدخل إذا فشل Hive)
 6. استدعاء roomService.createRoom(...)
 7. الانتقال فوراً لـ MissionRoomScreen(isHost: true)
```

**ما يُمرَّر لـ Appwrite عند الإنشاء:**
```
hostId     = Appwrite user ID
hostName   = الاسم المحفوظ في Hive
roomName   = ما كتبه المستخدم
roomCode   = الكود المُولَّد عشوائياً (5 أحرف)
isPublic   = true/false
maxPlayers = redCount + blueCount
```

> [!NOTE]
> الكود الذي يُولَّد هنا هو ما يشاركه المضيف مع زملائه لينضموا بدون البحث في القائمة العامة.

---

### `public_rooms_screen.dart` — قائمة الغرف العامة / الانضمام بكود

**تُفتح من:** زر "انضمام لمهمة عالمية" في `start_screen.dart`

**ماذا يحدث عند الفتح (`initState` → `_loadData`):**
```
1. جلب هوية المستخدم من Appwrite Account
2. استدعاء roomService.getPublicRooms()
   (فقط الغرف: is_public=true AND status='waiting' مرتبة بالأحدث)
3. عرض القائمة أو رسالة "لا توجد غرف"
```

**طريقتا الانضمام:**

| الطريقة | الدالة | الخطوات |
|---|---|---|
| بالكود المباشر | `_joinByCode()` | قراءة الكود من حقل النص → `getRoomByCode(code)` → `joinRoom()` → الانتقال لـ `MissionRoomScreen` |
| بالنقر على غرفة | `_joinRoom(roomId)` | `joinRoom(roomId, myId, myName)` مباشرة → الانتقال لـ `MissionRoomScreen` |

**الـ Widget المساعدة:**
- `_RoomItem`: يعرض بطاقة غرفة واحدة (الاسم، عدد اللاعبين، اسم المضيف، زر انضمام)
- `_StatBadge`: شارة صغيرة ملونة لعرض إحصائية

**تحديث القائمة:** يدعم السحب للتحديث (Pull to Refresh) عبر `RefreshIndicator` الذي يستدعي `_loadData()` مجدداً.

**شرط الغرفة الممتلئة:**
```dart
isVip: currentPlayers >= maxPlayers  // يعرض "ممتلئة" ويمنع الانضمام
```

---

### `lobby_screen.dart` — غرفة الانتظار للشبكة المحلية (LAN)

**تُفتح من:** بعد نجاح `startHosting()` أو `joinGame()` في `start_screen.dart`  
**الفرق عن `mission_room_screen`:** هذه للشبكة المحلية عبر TCP مباشرة — لا Appwrite هنا.

**آلية التحديث التلقائي:**
```dart
// تستمع لتغييرات connectionProvider
ref.listen<ConnectionState>(connectionProvider, (previous, next) {
  if (next.isGameStarted && previous?.isGameStarted != true) {
    // الانتقال التلقائي للوحة اللعب عند بدء اللعبة
    Navigator.pushReplacement(context, ...GameBoardScreen());
  }
});
```

أي تحديث يصل عبر TCP (LOBBY_UPDATE من Host) يُحدِّث `connectionProvider` مما يعيد بناء هذه الشاشة تلقائياً.

**شروط بدء اللعبة (LAN) في `_handleStartGame()`:**
```
1. عدد اللاعبين >= 4
2. الفريق الأحمر لديه spymaster واحد على الأقل
3. الفريق الأزرق لديه spymaster واحد على الأقل
4. [مرحلة حقن الكلمات] يقوم المضيف بقراءة customWordsProvider لبدء لعبة بكلمات مخصصة عبر الدالة `resetGame(customWords)`.
→ استدعاء connectionProvider.startGame()
  → يُرسل START_GAME لجميع العملاء عبر TCP
  → يضبط isGameStarted = true
```

**بطاقة عنوان IP (`_buildIPCard`):**
يعرض IP المحلي للمضيف ويتيح نسخه. هذا هو الـ IP الذي يُدخله اللاعبون الآخرون في حقل "عنوان IP المستهدف".

**تغيير الفريق والدور:**
```dart
ref.read(connectionProvider.notifier).updateLocalPlayer(Team.red, localPlayer.role)
→ إذا كان Host: socket_host.handlePlayerUpdate()
→ إذا كان Client: يُرسل PLAYER_UPDATE للـ Host عبر TCP
```

---

### `network_helper.dart` — مساعد الشبكة (ثانوي)

ملف بسيط يحتوي على `NetworkHelper.getLocalIpAddress()`. وظيفته مطابقة `IPUtils.getIPAddress()` تقريباً لكن بتصفية أقل دقة.

> [!NOTE]
> `IPUtils` هو الأحدث والأكثر دقة في التصفية. `NetworkHelper` موجود كإرث برمجي. في حال وجود تعارض، ثق بـ `IPUtils`.

---

## 📦 الاعتماديات الكاملة (Dependencies)

### `pubspec.yaml` — كل حزمة وسبب وجودها

```yaml
# الإصدار
version: 1.0.0+1

# حد Flutter SDK
environment:
  sdk: '>=3.0.0 <4.0.0'
```

| الحزمة | الإصدار | الوظيفة | ملاحظات |
|---|---|---|---|
| `flutter_riverpod` | ^2.4.9 | إدارة الحالة | **لا تغيّره — واجهة API قد تتكسر** |
| `hive` | ^2.2.3 | تخزين محلي | لا يحتاج إنترنت |
| `hive_flutter` | ^1.1.0 | تهيئة Hive لـ Flutter | `Hive.initFlutter()` |
| `json_annotation` | ^4.8.1 | توليد كود JSON | مطلوب لـ freezed |
| `freezed_annotation` | ^2.4.1 | تعريف النماذج الـ immutable | مطلوب runtime |
| `go_router` | ^12.1.3 | نظام التنقل | موجود لكن غير مستخدم فعلياً (التنقل يحدث بـ Navigator) |
| `flutter_screenutil` | ^5.9.0 | تجاوب المقاسات | تصميم أساس: 375×812 |
| `logger` | ^2.0.2+1 | تسجيل الأحداث | **معطّل في Release!** |
| `google_fonts` | ^6.2.1 | الخطوط: SpaceGrotesk, NotoSansArabic, PlusJakartaSans | تُنزَّل تلقائياً |
| `appwrite` | ^23.0.0 | عميل Appwrite السحابي | **لا تغيّر الإصدار بدون اختبار** |

**اعتماديات التطوير فقط:**

| الحزمة | الوظيفة |
|---|---|
| `build_runner` | تشغيل مولّدات الكود |
| `json_serializable` | توليد `fromJson/toJson` |
| `freezed` | توليد كود النماذج الـ immutable |
| `flutter_launcher_icons` | توليد أيقونات التطبيق |
| `flutter_lints` | قواعد جودة الكود |

---

## ⚡ الـ Assets والموارد

```yaml
flutter:
  assets:
    - AppIcons/        ← أيقونات التطبيق
    - assets/images/   ← صور الشاشات (header_bg.png لـ public_rooms)
```

> [!WARNING]
> إذا أضفت صورة جديدة ولم تُدرجها في `assets:` ستحصل على خطأ `Unable to load asset`. تأكد دائماً من إضافة المسار.

---

## 🔄 توليد الكود (Code Generation)

المشروع يستخدم `freezed` لتوليد كود النماذج. كل ملف نموذج يحتوي على:

```dart
part 'game_state.freezed.dart';  // ← ملف مُولَّد تلقائياً
part 'game_state.g.dart';        // ← ملف JSON مُولَّد تلقائياً
```

**متى تحتاج إعادة التوليد؟**
- عند إضافة حقل جديد لأي نموذج (GameState, WordCard, Player, SocketMessage)
- عند تغيير نوع بيانات حقل
- عند إنشاء نموذج جديد بـ `@freezed`

**أمر إعادة التوليد:**
```powershell
# من مجلد المشروع
dart run build_runner build --delete-conflicting-outputs
```

**إذا أردت المراقبة المستمرة أثناء التطوير:**
```powershell
dart run build_runner watch --delete-conflicting-outputs
```

> [!IMPORTANT]
> لا تعدّل يدوياً ملفات `*.freezed.dart` أو `*.g.dart` — سيتم الكتابة فوقها عند التوليد القادم.

---

## 🔑 إعداد Appwrite من الصفر

إذا احتجت يوماً إعادة ربط المشروع بحساب Appwrite جديد:

### الخطوة 1 — الثوابت
```dart
// lib/core/appwrite/appwrite_providers.dart
const String appwriteProjectId = 'YOUR_NEW_PROJECT_ID';
const String appwriteEndpoint  = 'https://REGION.cloud.appwrite.io/v1';
```

### الخطوة 2 — Collection
```dart
// lib/core/appwrite/appwrite_room_service.dart
static const String databaseId        = 'YOUR_DATABASE_ID';
static const String roomsCollectionId = 'rooms'; // أو أي اسم تختاره
```

### الخطوة 3 — تسجيل خادم Android (Origin)
لضمان عدم رفض الاتصال بخطأ `Invalid Origin (403)`:
1. في قائمة مشاريع Appwrite، اذهب إلى المشهد الرئيسي (Overview).
2. تحت `Platforms`، اضغط `Add Platform` واختر `Android`.
3. اكتب **الاسم**: الأسماء الرمزية.
4. اكتب **Package Name**: `com.example.p2p_codenames`  (هذا ما يبحث عنه الخادم).
5. قم بحفظ التعديلات (لا داعي لخطوات إضافية بالـ SDK هنا لأننا برمجناها بالفعل).

### الخطوة 4 — بنية الـ Collection في لوحة Appwrite

قم بإنشاء Collection باسم `rooms` بالحقول التالية:

| اسم الحقل | النوع | ملاحظة |
|---|---|---|
| `name` | String (255) | اسم الغرفة |
| `code` | String (10) | الرمز السري |
| `host_name` | String (100) | اسم المضيف |
| `status` | String (20) | القيم: `waiting`, `active` |
| `is_public` | Boolean | عامة/خاصة |
| `max_players` | Integer | الحد الأقصى |
| `players` | String[] (Array) | قائمة اللاعبين كـ JSON strings |
| `game_state` | String (65535) | حالة اللعبة كـ JSON |

### الخطوة 4 — صلاحيات Collection
في لوحة Appwrite، اضبط صلاحيات الـ Collection:
- `Read`: Any
- `Create`: Users
- `Update`: Users
- `Delete`: Users

### الخطوة 5 — تفعيل Realtime
تأكد أن Realtime مفعّل في مشروع Appwrite (Settings → Realtime).

---

## 🚀 دليل CI/CD و GitHub Actions

### كيف يعمل البناء التلقائي

عند الـ Push لـ GitHub، يُشغَّل ملف `.github/workflows/*.yml` لبناء APK تلقائياً.

**الخطوات الرئيسية في الـ Workflow:**
```yaml
1. Checkout الكود
2. تثبيت Java (Zulu JDK 17)
3. تثبيت Flutter (Stable 3.41.6)
4. flutter pub get        ← تحميل الاعتماديات
5. flutter analyze lib    ← فحص جودة الكود (يفشل Build إذا وُجدت أخطاء!)
6. flutter build apk --release
7. رفع الـ APK كـ Artifact
```

### لماذا يفشل البناء أحياناً؟

| السبب | الحل |
|---|---|
| `flutter analyze` يجد خطأ | شغّل `flutter analyze lib` محلياً أولاً وأصلح الأخطاء |
| خطأ في `*.g.dart` | نفّذ `dart run build_runner build` ثم commit الملفات المولَّدة |
| مفقود Asset | تأكد من إضافة المسار في `pubspec.yaml` في قسم `assets:` |
| مشكلة في `minSdkVersion` | راجع `android/app/build.gradle` |

---

## 🗺 خريطة التنقل بين الشاشات (Navigation Map)

```
StartScreen (الشاشة الرئيسية)
│
├── [تشغيل خادم عالمي]
│   └── RoomSettingsScreen
│       └── [تأكيد الإنشاء] → MissionRoomScreen (isHost: true)
│           └── [بدء المهمة] → GameBoardScreen
│
├── [تشغيل خادم محلي]
│   └── startHosting() → LobbyScreen
│       └── [بدء اللعبة] → GameBoardScreen
│
├── [انضمام لمهمة عالمية]
│   └── PublicRoomsScreen
│       ├── [انضمام بالكود] → MissionRoomScreen (isHost: false)
│       └── [انضمام من القائمة] → MissionRoomScreen (isHost: false)
│           └── [status = active] → GameBoardScreen
│
├── [انضمام محلي (بالضغط على الأيقونة)]
│   └── joinGame(ip) → LobbyScreen
│       └── [بدء اللعبة] → GameBoardScreen
│
└── [الاختبار الذاتي]
    └── TestRunnerScreen
        └── [رجوع] → StartScreen
```

---

## 🧠 مرجع سريع: "أريد أن أفعل X"

| ما تريده | الملف | ما تعدّله |
|---|---|---|
| تغيير الخلفية الداكنة | أي شاشة | `const _surface = Color(0xFF001429)` |
| تغيير اللون الذهبي-البرتقالي | أي شاشة | `const _primary = Color(0xFFFFB77A)` |
| تغيير الخط | أي شاشة | `GoogleFonts.spaceGrotesk(...)` أو `GoogleFonts.notoSansArabic(...)` |
| إضافة كلمات للعبة | `word_database.dart` | أضف للقائمة `arabicWords` |
| تغيير توزيع الكروت (9-8-7-1) | `game_provider.dart` | في `_generateInitialState()` |
| تغيير من يبدأ أولاً | `game_provider.dart` | `currentTurn: Team.red` في نهاية `_generateInitialState()` |
| تغيير قانون N+1 | `game_provider.dart` | سطر `int guesses = ...` في `giveClue()` |
| إضافة حقل جديد لحالة اللعبة | `game_state.dart` | أضف الحقل، ثم `build_runner` |
| تغيير مدة تنظيف الغرف | `appwrite_room_service.dart` | في `cleanupOldRooms()` → `Duration(minutes: 5)` |
| تغيير مدة الـ Heartbeat | `connection_provider.dart` | في `joinAppwriteGame()` → `Duration(seconds: 60)` |
| تغيير منفذ TCP المحلي | `socket_host.dart` و `socket_client.dart` | `static const int port = 4567` |
| تعطيل Logger كلياً | `main.dart` | `Logger.level = Level.off` (بدون قيد) |
| رفع حد timeout لـ Appwrite | `startup_tests.dart` | الرقم في `Duration(seconds: 20)` |
| إضافة شاشة جديدة | مجلد `features/*/presentation/` | أنشئ ملف `.dart` جديد |
| إضافة Provider جديد | بجانب Provider المرتبط به | استخدم `final myProvider = Provider(...)` |

---

## 🔐 بيانات الوصول والمعرّفات الحساسة

> [!CAUTION]
> لا تشارك هذه البيانات أبداً وحافظ على نسخة اسودة منها:

| الثابت | موقعه في الكود | القيمة الحالية |
|---|---|---|
| `appwriteProjectId` | `appwrite_providers.dart` | `69cc14ce000d6ee3e15b` |
| `appwriteEndpoint` | `appwrite_providers.dart` | `https://fra.cloud.appwrite.io/v1` |
| `databaseId` | `appwrite_room_service.dart` | `69ccd7f90036a2e58f2c` |
| `roomsCollectionId` | `appwrite_room_service.dart` | `rooms` |
| منفذ TCP المحلي | `socket_host.dart` | `4567` |

---

## 📋 قائمة تحقق عند إضافة ميزة جديدة

```
□ 1. هل أنشأت النموذج (Model) في مجلد models/ المناسب؟
□ 2. هل أضفت @freezed للنموذج إذا كان immutable؟
□ 3. هل نفّذت build_runner بعد تعديل النماذج؟
□ 4. هل أنشأت Provider في مجلد providers/؟
□ 5. هل استخدمت ref.watch() وليس ref.read() في الـ build()؟
□ 6. هل أضفت Assets الجديدة في pubspec.yaml؟
□ 7. هل نفّذت flutter analyze lib وتأكدت من عدم وجود أخطاء؟
□ 8. هل أضفت اختباراً في مجلد testing/suites/ للميزة الجديدة؟
□ 9. هل حدّثت هذا المانيوال بوصف الميزة الجديدة؟
```

---

## 🖥 تشغيل المشروع محلياً للمطور

```powershell
# من مجلد المشروع c:\Users\gaa77\Desktop\pro2\p2p

# تحميل الاعتماديات
flutter pub get

# توليد كود freezed (مطلوب عند أول مرة أو بعد تعديل النماذج)
dart run build_runner build --delete-conflicting-outputs

# تشغيل على محاكي أو جهاز
flutter run

# بناء APK للنشر
flutter build apk --release

# بناء APK باسم مخصص
flutter build apk --release --build-name=1.2.0 --build-number=5

# فحص الكود (يجب أن لا يوجد أخطاء قبل النشر)
flutter analyze lib
```

---

## 📊 ملخص Provider Tree (شجرة الـ Providers)

```
ProviderScope (main.dart)
│
├── appwriteClientProvider        → Client (Appwrite connection)
│   ├── appwriteAccountProvider   → Account (authentication)
│   ├── appwriteDatabasesProvider → Databases (CRUD)
│   └── appwriteRealtimeProvider  → Realtime (WebSocket)
│       └── appwriteRoomServiceProvider → AppwriteRoomService
│
├── authServiceProvider           → AuthService (anonymous login)
│
├── gameProvider                  ← StateNotifierProvider
│   (GameNotifier / GameState)
│   - generateBoard()
│   - revealCard()
│   - giveClue()
│   - passTurn()
│   - resetGame()
│   - updateState()  ← يُستدعى من connectionProvider
│
└── connectionProvider            ← StateNotifierProvider
    (ConnectionNotifier / ConnectionState)
    - يقرأ gameProvider
    - يقرأ appwriteRoomServiceProvider
    - joinAppwriteGame()
    - startHosting()
    - joinGame()
    - sendCardFlip()
    - sendClue()
    - sendPassTurn()
    - disconnect()
```

**القاعدة:**
- `gameProvider` لا يعرف شيئاً عن الشبكة
- `connectionProvider` هو الجسر بين الشبكة ومحرك اللعبة
- الـ UI يقرأ من كليهما ويكتب عبر `connectionProvider` فقط

---

*الجزء الثاني مكتمل. راجع [الجزء الأول](./architecture_manual.md) للفهم الشامل.*
