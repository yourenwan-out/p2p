# المانيوال المعماري الشامل — الأسماء السرية (P2P Codenames)

> هذا المانيوال مبني على قراءة الكود الحقيقي سطراً بسطر.  
> هدفه أن تستطيع بمفردك: فهم كيف يعمل كل جزء، تعديل ما تريد، حل أي مشكلة، إضافة ميزات جديدة.

---

## الفهرس

1. [البنية التقنية العامة](#-1-البنية-التقنية-العامة)
2. [خريطة الملفات الكاملة](#-2-خريطة-الملفات-الكاملة)
3. [نقطة البداية — main.dart](#-3-نقطة-البداية--maindart)
4. [طبقة Core — الخدمات المشتركة](#-4-طبقة-core--الخدمات-المشتركة)
5. [ميزة الاتصال والغرف — connection](#-5-ميزة-الاتصال-والغرف--connection)
6. [محرك اللعبة — game_board](#-6-محرك-اللعبة--game_board)
7. [نظام الفحص الذاتي — testing](#-7-نظام-الفحص-الذاتي--testing)
8. [تدفق البيانات الكامل خطوة بخطوة](#-8-تدفق-البيانات-الكامل-خطوة-بخطوة)
9. [أنواع الرسائل بين اللاعبين](#-9-أنواع-الرسائل-بين-اللاعبين)
10. [دليل التعديل والصيانة](#-10-دليل-التعديل-والصيانة)
11. [دليل حل المشاكل الشائعة](#-11-دليل-حل-المشاكل-الشائعة)

---

## 🏗 1. البنية التقنية العامة

### التقنيات المستخدمة

| التقنية | الدور | الملاحظة |
|---|---|---|
| **Flutter / Dart** | إطار العمل الأساسي | UI + منطق اللعبة |
| **Riverpod** | إدارة الحالة (State Management) | كل Provider هو مصدر حقيقة واحد |
| **Appwrite** | قاعدة البيانات السحابية + Realtime | للعب العالمي بين الأجهزة |
| **Hive** | تخزين محلي | حفظ الاسم وآخر IP |
| **freezed** | توليد كود النماذج تلقائياً | يجعل النماذج immutable |
| **Google Fonts** | الخطوط | SpaceGrotesk + NotoSansArabic |
| **logger** | تسجيل أحداث التشغيل | معطّل في release لمنع ANR |

- **`connectionProvider`:** يدير حالة الاتصال (`ConnectionState`) للعملاء والمضيفين في الوضع المحلي (LAN) والعالمي (Appwrite). يدير الاتصال بالـ Sockets في الـ LAN واشتراكات الـ Realtime بالشبكة العالمية.
- **`customWordsProvider`:** `StateProvider<List<String>?>` بسيط يخزن قائمة الكلمات المخصصة التي يدخلها المضيف عبر واجهة اختيار الكلمات (أو يرفعها عبر ملف) حتى موعد بدء اللعبة حيث يتم تمريرها إلى `gameProvider.resetGame(customWords)`.

### المعمارية المتبعة: Feature-First

```
lib/
├── main.dart              ← نقطة الدخول الوحيدة
├── core/                  ← خدمات مشتركة بين كل الميزات
└── features/              ← كل ميزة مستقلة بنفسها
    ├── connection/        ← كل ما يتعلق بإنشاء/الانضمام للغرف
    ├── game_board/        ← كل ما يتعلق باللعبة نفسها
    └── testing/           ← فحص وتشخيص الأنظمة
```

> **القاعدة الذهبية:** كل ميزة تحتوي على: `models/` (البيانات) + `providers/` (المنطق) + `presentation/` (الواجهة). لا تمزج بينها.

---

## 📁 2. خريطة الملفات الكاملة

```
lib/
├── main.dart
├── core/
│   ├── appwrite/
│   │   ├── appwrite_providers.dart       ← عميل Appwrite + توثيق مجهول
│   │   └── appwrite_room_service.dart    ← CRUD للغرف + Realtime
│   ├── constants/
│   │   └── word_database.dart            ← قاعدة الكلمات العربية
│   ├── network/
│   │   ├── connection_provider.dart      ← المتحكم الرئيسي للاتصال
│   │   ├── ip_utils.dart                 ← اكتشاف IP المحلي
│   │   ├── network_helper.dart           ← أدوات مساعدة للشبكة
│   │   ├── socket_host.dart              ← خادم TCP للشبكة المحلية
│   │   ├── socket_client.dart            ← عميل TCP للشبكة المحلية
│   │   └── models/
│   │       └── socket_message.dart       ← نموذج رسائل Socket
│   └── utils/
│       └── validators.dart               ← التحقق من صحة IP والأسماء
├── features/
│   ├── connection/
│   │   └── presentation/
│   │       ├── start_screen.dart         ← الشاشة الرئيسية
│   │       ├── room_settings_screen.dart ← إعدادات إنشاء الغرفة
│   │       ├── public_rooms_screen.dart  ← قائمة الغرف العامة
│   │       ├── mission_room_screen.dart  ← غرفة الانتظار (Lobby)
│   │       └── lobby_screen.dart         ← Lobby للشبكة المحلية
│   ├── game_board/
│   │   ├── models/
│   │   │   ├── game_state.dart           ← حالة اللعبة الكاملة
│   │   │   ├── word_card.dart            ← نموذج البطاقة
│   │   │   └── player.dart               ← نموذج اللاعب
│   │   ├── providers/
│   │   │   └── game_provider.dart        ← محرك اللعبة وقواعدها
│   │   └── presentation/
│   │       └── game_board_screen.dart    ← لوحة اللعب الرئيسية
│   └── testing/
│       ├── models/
│       │   └── test_result.dart          ← نموذج نتيجة الاختبار
│       ├── presentation/
│       │   └── test_runner_screen.dart   ← واجهة عرض الاختبارات
│       └── suites/
│           ├── engine_tests.dart         ← اختبارات محرك اللعبة
│           ├── network_tests.dart        ← اختبارات الشبكة المحلية
│           ├── validator_tests.dart      ← اختبارات التحقق
│           ├── storage_tests.dart        ← اختبارات Hive
│           ├── state_tests.dart          ← اختبارات الحالة
│           ├── edge_case_tests.dart      ← اختبارات الحالات الحدية
│           ├── appwrite_tests.dart       ← اختبارات Appwrite
│           └── startup_tests.dart        ← اختبارات بدء التشغيل
```

---

## 🚀 3. نقطة البداية — `main.dart`

**الملف:** `lib/main.dart` (60 سطر)

### ماذا يفعل بالترتيب:

```dart
void main() async {
  // 1. تهيئة بيئة Flutter قبل أي شيء آخر (إلزامي)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. إيقاف Logger في release لتفادي ANR على الأجهزة الحقيقية
  Logger.level = kReleaseMode ? Level.off : Level.warning;

  // 3. تهيئة Hive مع timeout 4 ثوانٍ للأمان
  await Future.microtask(() async {
    await Hive.initFlutter();
    await Hive.openBox('settingsBox');
  }).timeout(const Duration(seconds: 4));

  // 4. تشغيل التطبيق
  runApp(ProviderScope(child: MyApp()));
}
```

### لماذا يوجد `timeout` على Hive؟
بعض المحاكيات أو الأجهزة القديمة تتعلق في عملية `Hive.initFlutter()` وتسبب ANR (التطبيق لا يستجيب). الـ timeout يضمن أن التطبيق يُشغَّل حتى لو فشل Hive.

### الـ `MyApp` Widget:
- `ScreenUtilInit`: يحسب مقاسات الـ UI بناءً على حجم شاشة iPhone X (375×812) كأساس.
- `Directionality.rtl`: يجعل كل الواجهة عربية (من اليمين لليسار) تلقائياً.

---

## ⚙️ 4. طبقة Core — الخدمات المشتركة

### 4.1 خدمات Appwrite

---

#### `appwrite_providers.dart`

**الثوابت المهمة:**
```dart
const String appwriteProjectId = '69cc14ce000d6ee3e15b';
const String appwriteEndpoint  = 'https://fra.cloud.appwrite.io/v1';
```

> [!CAUTION]
> هذان الثابتان هما مفتاح الاتصال بحساب Appwrite الخاص بك. إذا أنشأت مشروعاً جديداً في Appwrite، يجب تغييرهما هنا.

**الـ Providers المُعرَّفة:**

| Provider | النوع | الوظيفة |
|---|---|---|
| `appwriteClientProvider` | `Client` | عميل الاتصال الأساسي بسحابة Appwrite |
| `appwriteAccountProvider` | `Account` | للتوثيق وإنشاء الجلسات |
| `appwriteDatabasesProvider` | `Databases` | للقراءة والكتابة في قاعدة البيانات |
| `appwriteRealtimeProvider` | `Realtime` | للاستماع للتغييرات اللحظية |
| `authServiceProvider` | `AuthService` | لإدارة الجلسة المجهولة |

**دالة `AuthService.ensureAnonymousSession()`:**
```
إذا كان المستخدم مسجلاً → لا تفعل شيئاً
إذا لم يكن مسجلاً → أنشئ جلسة مجهولة تلقائياً
خطأ 403 (Invalid Origin) → يجب إضافة com.example.p2p_codenames لمنصة Android في Appwrite!
أي خطأ آخر → أعد رميه للمعالجة في الأعلى
```

---

#### `appwrite_room_service.dart`

**الثوابت:**
```dart
static const String databaseId         = '69ccd7f90036a2e58f2c';
static const String roomsCollectionId  = 'rooms';
```

> [!IMPORTANT]
> هذان يحددان أين تُخزَّن الغرف في Appwrite. إذا حذفت الـ Collection وأنشأت أخرى، غيّر `roomsCollectionId`.

**الدوال وما تفعله:**

| الدالة | المدخلات | الوظيفة |
|---|---|---|
| `createRoom(...)` | hostId, hostName, roomCode, isPublic, maxPlayers | تنظف الغرف القديمة أولاً، ثم تنشئ مستنداً جديداً في Appwrite |
| `joinRoom(roomId, playerId, playerName)` | - | تقرأ قائمة اللاعبين، تتحقق عدم وجود اللاعب، تضيفه |
| `updatePlayer(roomId, playerId, updates)` | Map من التحديثات | تعدل بيانات لاعب محدد بدون لمس باقي اللاعبين |
| `leaveRoom(roomId, playerId)` | - | تحذف اللاعب؛ إذا فرغت الغرفة تحذف المستند كله |
| `startGame(roomId)` | - | تغير `status` من `waiting` إلى `active` |
| `updateGameState(roomId, jsonStr)` | سلسلة JSON | ترفع حالة اللعبة المشفرة للسحابة |
| `getPublicRooms()` | - | تجلب الغرف العامة في حالة `waiting` مرتبة بالأحدث |
| `getRoomByCode(code)` | كود الغرفة | تبحث عن غرفة بالكود؛ تعيد ID أو `null` |
| `updateHeartbeat(roomId)` | - | يُحدِّث الغرفة بنفس قيمتها ليُجدِّد `$updatedAt` |
| `deleteRoom(roomId)` | - | يحذف الغرفة (يُستدعى عند نهاية اللعبة أو خروج الـ Host) |
| `cleanupOldRooms()` | - | يحذف الغرف التي لم يُحدَّث `$updatedAt` منذ 5 دقائق |
| `subscribeToRoom(roomId)` | - | يُعيد `RealtimeSubscription` للاستماع للتغييرات لحظياً |

**آلية تخزين اللاعبين:**
اللاعبون يُخزَّنون كـ `List<String>` حيث كل عنصر هو JSON مُشفَّر:
```json
[
  "{\"id\":\"xxx\",\"name\":\"أحمد\",\"team\":\"red\",\"role\":\"spymaster\",\"is_host\":true}",
  "{\"id\":\"yyy\",\"name\":\"محمود\",\"team\":\"blue\",\"role\":\"field_agent\",\"is_host\":false}"
]
```

---

### 4.2 أدوات الشبكة

#### `ip_utils.dart` — `IPUtils.getIPAddress()`

تبحث في واجهات الشبكة المحلية للجهاز لإيجاد أفضل IP صالح للاستضافة.

**منطق التصفية:**
1. تتجاهل: Loopback، vmnet، vethernet (Hyper-V)
2. تتجاهل: `10.111.*`، `10.112.*` (محولات Windows الافتراضية)، `169.254.*` (link-local)، `10.0.2.15` (Android Emulator)
3. تُفضّل: عناوين `192.168.*` أو `10.0.*` - `10.2.*` أو `172.16.*` - `172.31.*`
4. إذا لم تجد مفضلاً → تعيد أول IP صالح كـ fallback
5. كل ذلك بـ timeout 3 ثوانٍ

**متى تحتاج تعديلها؟** إذا كانت شبكتك تستخدم نطاق IP غير معتاد لا يُغطيه `_isPreferred`.

---

#### `validators.dart` — `Validators.validateIPAddress(String?)`

يتحقق من صحة عنوان IPv4 بتعبير نمطي (Regex).

- الصيغة المطلوبة: `X.X.X.X` حيث كل X بين 0 و 255
- **يعيد:** `null` إذا كان العنوان صحيحاً، أو رسالة خطأ إذا كان غلطاً

---

#### `socket_message.dart` — `SocketMessage`

نموذج بسيط (Freezed) لتمثيل الرسالة المرسلة بين الأجهزة عبر TCP:
```dart
class SocketMessage {
  String type;                     // نوع الرسالة (REQ_JOIN, CARD_FLIP...)
  Map<String, dynamic> payload;    // البيانات المرفقة
}
```

---

#### `socket_host.dart` — `SocketHost`

**الوظيفة:** يُشغِّل خادم TCP على المنفذ `4567` للشبكة المحلية.

**دورة الحياة:**
```
startServer(hostName, hostId)
  → فتح منفذ TCP 4567
  → إنشاء قائمة لاعبين (Host فقط)
  → الاستماع لاتصالات جديدة
    → لكل اتصال → _handleClient()
      → REQ_JOIN: تسجيل اللاعب وإرسال حالة اللعبة له
      → PLAYER_UPDATE: تحديث بيانات اللاعب
      → باقي الأحداث: إعادة توجيهها لـ ConnectionNotifier

stopServer()
  → إغلاق كل الاتصالات وتنظيف القوائم
```

**ميزة حجب الألوان عن الـ Operative:**
```dart
void _sendGameStateToPlayer(Player player, GameState state, Socket socket) {
  if (player.role == Role.operative) {
    // يُخفي ألوان البطاقات غير المكشوفة!
    final redactedCards = state.cards.map((c) {
      if (!c.isRevealed) return c.copyWith(color: CardColor.neutral);
      return c;
    }).toList();
    playerState = state.copyWith(cards: redactedCards);
  }
  // إرسال الحالة المُعدَّلة
}
```

---

#### `socket_client.dart` — `SocketClient`

**الوظيفة:** يتصل بخادم TCP اللاعب الـ Host.

**دورة الحياة:**
```
connect(ip, playerName)
  → Socket.connect(ip, 4567) مع timeout 5 ثوانٍ
  → إرسال REQ_JOIN فور الاتصال
  → بدء الاستماع للرسائل القادمة

sendMessage(message)
  → تحويل الرسالة إلى JSON + \n ثم إرسالها

disconnect()
  → إغلاق الـ socket
```

---

#### `connection_provider.dart` — `ConnectionNotifier` ⭐

> هذا الملف هو **قلب التطبيق** ومركز التحكم. كل أمر في اللعبة يمر عبره.

**الـ `ConnectionState` يحتوي على:**

| الحقل | النوع | المعنى |
|---|---|---|
| `isConnected` | bool | هل الاتصال قائم؟ |
| `isConnecting` | bool | هل نحن في منتصف الاتصال؟ |
| `error` | String? | آخر رسالة خطأ |
| `players` | List\<Player\> | قائمة اللاعبين الحاليين |
| `localPlayerId` | String? | هوية هذا الجهاز |
| `isHost` | bool | هل هذا الجهاز هو المضيف؟ |
| `isGameStarted` | bool | هل بدأت اللعبة؟ |
| `socketHost` | SocketHost? | مرجع خادم TCP (إن وُجد) |
| `socketClient` | SocketClient? | مرجع عميل TCP (إن وُجد) |
| `appwriteRoomId` | String? | ID الغرفة في Appwrite (إن وُجد) |
| `appwriteSubscription` | RealtimeSubscription? | الاشتراك الفعلي في Realtime |

**الدوال الرئيسية:**

**`joinAppwriteGame(...)`** — الدخول للعب العالمي:
```
1. قطع أي اتصال قديم
2. إعادة تعيين اللوحة (لتفادي ظهور لوحة قديمة)
3. تحديث الحالة بمعلومات اللاعب والغرفة
4. الاشتراك في Realtime لتلقي:
   - تحديثات game_state → تحديث GameNotifier
   - تحديثات players   → تحديث قائمة اللاعبين
5. بدء Heartbeat Timer (كل 60 ثانية) لإبقاء الغرفة حية
```

**`sendCardFlip(index)`** — إرسال حدث قلب البطاقة:
```
إذا كان Appwrite:
  → revealCard(index) محلياً
  → رفع GameState لـ Appwrite
إذا كان LAN (Host):
  → معالجة محلية مباشرة
إذا كان LAN (Client):
  → إرسال رسالة CARD_FLIP للـ Host
```

**`sendClue(word, number)`** — إرسال التلميح:
```
نفس منطق sendCardFlip بنوع رسالة CLUE_GIVEN
```

**`sendPassTurn()`** — تمرير الدور:
```
نفس المنطق بنوع رسالة PASS_TURN
```

**`disconnect()`** — قطع الاتصال الكامل:
```
1. إلغاء Heartbeat Timer
2. إغلاق Appwrite RealtimeSubscription
3. إيقاف خادم TCP أو قطع عميل TCP
4. مسح الحالة كاملاً
```

---

## 🖥 5. ميزة الاتصال والغرف — `connection`

### `start_screen.dart` — الشاشة الرئيسية

**ماذا يحدث عند فتح الشاشة (`initState`):**
1. تحميل آخر IP واسم من Hive (`_loadValues`). في حال فشل Hive (مثلاً بسبب Timeout)، يتم تعيين الاسم الافتراضي إلى "العميل" لمنع تعليق المستخدم في واجهة الإدخال.
2. جلب IP المحلي (`_fetchLocalIP`)
3. بدء جلسة Appwrite المجهولة بشكل **غير متزامن وغير محجوب** بـ timeout 8 ثوانٍ

**الأزرار وما تفعله:**

| الزر | الدالة | ما يحدث |
|---|---|---|
| تشغيل خادم عالمي | `_handleHostGlobalGame` | الانتقال لـ `RoomSettingsScreen` |
| تشغيل خادم محلي | `_handleHostLocalGame` | يستدعي `startHosting(name)` ثم الانتقال لـ `LobbyScreen` |
| انضمام لمهمة عالمية | `_handleJoinGlobalGame` | الانتقال لـ `PublicRoomsScreen` |
| انضمام محلي (بالضغط على الأيقونة) | `_handleJoinLocalGame` | يتحقق من IP ثم يستدعي `joinGame(ip, name)` |
| الاختبار الذاتي | - | الانتقال لـ `TestRunnerScreen` |

**التصميم المرئي:**
- `_glowBlob`: دوائر ضوء ملونة في الخلفية
- `_MeshGrid`/`_MeshPainter`: شبكة نقاط رمادية خفيفة تُرسم بـ CustomPainter
- `_GradientButton`: زر قابل لإعادة الاستخدام بتدرج لوني

---

### `mission_room_screen.dart` — غرفة الانتظار (Appwrite)

تستقبل: `roomId` (String) + `isHost` (bool)

**ماذا يحدث عند فتح الشاشة (`initState` → `_initRoom`):**
1. جلب هوية المستخدم من Appwrite Account
2. جلب بيانات الغرفة (`_fetchRoomData`)
3. الاشتراك في Realtime للغرفة
4. الاستماع للتغييرات:
   - إذا تغيرت البيانات → تحديث `_roomData` و إعادة رسم الشاشة
   - إذا أصبح `status == 'active'` → بدء اللعبة!

**عند بدء اللعبة:**
```dart
// يُحوِّل بيانات Appwrite إلى Player objects
final mappedPlayers = _players.map((p) => Player(...)).toList();

// يدخل في وضع اللعب عبر ConnectionNotifier
notifier.joinAppwriteGame(_myId!, mappedPlayers, widget.isHost, widget.roomId!);

// الانتقال للوحة اللعب
Navigator.pushReplacement(context, MaterialPageRoute(
  builder: (_) => const GameBoardScreen()
));
```

**دالة `_launchMission()`** (Host فقط):
```
1. resetGame() → توليد لوحة عشوائية جديدة
2. انتظار 50ms لضمان تحديث الحالة
3. قراءة GameState وتحويلها لـ JSON
4. رفع JSON للسحابة عبر updateGameState()
5. تغيير status إلى 'active' عبر startGame()
  → هذا يُطلق حدث Realtime على أجهزة باقي اللاعبين
```

**دالة `_updateMyAgent(team, role)`:**
تُحدِّث فريق ودور اللاعب في Appwrite مباشرة. التغيير ينعكس فوراً على شاشات الجميع عبر Realtime.

---

## 🎮 6. محرك اللعبة — `game_board`

### 6.1 النماذج (Models)

#### `word_card.dart` — بطاقة الكلمة

```dart
enum CardColor { red, blue, neutral, assassin }

class WordCard {
  int id;          // رقم البطاقة (0-24)
  String word;     // الكلمة العربية
  CardColor color; // اللون الحقيقي (مخفي عن الـ Operative)
  bool isRevealed; // هل تم الكشف عنها؟ (default: false)
}
```

#### `player.dart` — اللاعب

```dart
enum Role { spymaster, operative }

class Player {
  String id;     // هوية فريدة (timestamp-based)
  String name;   // الاسم الرمزي
  Team team;     // red أو blue
  Role role;     // spymaster أو operative
  bool isHost;   // هل هو مضيف الغرفة؟
}
```

#### `game_state.dart` — حالة اللعبة الكاملة

```dart
class GameState {
  List<Player> players;       // قائمة اللاعبين
  List<WordCard> cards;       // 25 بطاقة
  Team currentTurn;           // من عنده الدور الآن
  String? currentClueWord;    // كلمة التلميح الحالية
  int? currentClueNumber;     // رقم التلميح
  int remainingGuesses;       // عدد التخمينات المتبقية
  bool isGameOver;            // هل انتهت اللعبة؟
  Team? winner;               // من فاز
  int redScore;               // نقاط الأحمر المكشوفة
  int blueScore;              // نقاط الأزرق المكشوفة
  CardColor? lastRevealedColor; // لون آخر بطاقة كُشفت (للتغذية الراجعة)
}
```

> هذه الفئة **مبنية بـ `@freezed`** مما يعني أنها غير قابلة للتعديل المباشر (Immutable). لتعديلها تستخدم `.copyWith(...)` فقط.

---

### 6.2 محرك اللعبة — `game_provider.dart` ⭐

هذا هو **عقل اللعبة**. يحتوي على كل قوانين اللعبة.

#### `_generateInitialState()` — لوح جديد

```
1. سحب كلمات عشوائية من WordDatabase
2. توزيع الألوان:
   - 9 بطاقات حمراء (الفريق الذي يبدأ)
   - 8 بطاقات زرقاء
   - 7 بطاقات محايدة (Neutral)
   - 1 بطاقة قاتل (Assassin)
3. خلط الكلمات والألوان عشوائياً
4. الفريق الأحمر يبدأ دائماً
```

> [!NOTE]
> في القواعد الرسمية، الفريق الذي يبدأ يحصل على 9 بطاقات والآخر 8. هنا الأحمر دائماً هو من يبدأ.

#### `giveClue(word, number)` — إعطاء تلميح

```dart
int guesses = (number == 99 || number == 0) ? 99 : (number + 1);
```
- رقم `0` أو `99` → تخمينات **لا نهائية**
- أي رقم آخر → `رقم + 1` (القاعدة الرسمية: يحق لك تخمين إضافي واحد)

#### `revealCard(index)` — كشف بطاقة ⭐⭐

هذه أهم دالة في المشروع. منطقها:

```
1. التحقق من الفهرس (0-24) وإلا رمي خطأ
2. إذا انتهت اللعبة → توقف
3. إذا لم تتبق تخمينات → توقف
4. إذا البطاقة مكشوفة مسبقاً → توقف
5. الكشف عن البطاقة

6. إذا كانت (assassin):
   → اللعبة تنتهي والفريق المقابل يفوز

7. إذا كانت لون الفريق الحالي (صحيحة):
   → إنقاص remainingGuesses بمقدار 1
   → إذا وصلت الأحمر لـ 9 مكشوفة → فوز أحمر
   → إذا وصلت الأزرق لـ 8 مكشوفة → فوز أزرق
   → إذا نفدت التخمينات → تحويل الدور

8. إذا كانت لون خاطئ (محايدة أو لون العدو):
   → تحويل الدور فوراً
```

#### `passTurn()` — تمرير الدور طوعياً

يستدعي `_switchTurn()` فقط، بعد التحقق أن اللعبة لم تنته.

#### `_switchTurn()` — تحويل الدور

```
- تغيير currentTurn للفريق الآخر
- مسح currentClueWord و currentClueNumber
- تصفير remainingGuesses
```

#### `resetGame()` — إعادة اللعبة

يستدعي `_generateInitialState()` وهذا هو كل شيء.

#### `updateState(GameState newState)` — تحديث من الشبكة

يستبدل الحالة المحلية بالحالة القادمة من السحابة مباشرة.

---

### 6.3 واجهة لوحة اللعب — `game_board_screen.dart`

**تقرأ من Provider-ين:**
- `gameProvider` → حالة اللعبة
- `connectionProvider` → معلومات الاتصال والاعبين

**تحدد دور اللاعب المحلي:**
```dart
final localPlayer = connectionState.players
    .firstWhere((p) => p.id == connectionState.localPlayerId);
final isSpymaster = localPlayer?.role == Role.spymaster;
```

**ثم تُظهر:**
- `isSpymaster == true` → `_buildSpymasterBoard` (يرى الألوان)
- `isSpymaster == false` → `_buildOperativeBoard` (لا يرى الألوان)

**شرط النقر على بطاقة (`_canClickCard`):**
```
البطاقة غير مكشوفة
AND اللعبة لم تنته
AND اللاعب موجود
AND دور اللاعب = operative
AND دور الفريق = دور الفريق الحالي
AND يوجد تلميح حالي
AND تبقى تخمينات
```

**عند الخروج من اللعبة (`_handleExitGame`):**
```
1. قطع الاتصال (disconnect)
2. إذا كان Host في Appwrite → حذف الغرفة
3. العودة للشاشة السابقة
```

---

## 🔬 7. نظام الفحص الذاتي — `testing`

### `test_result.dart`

```dart
enum TestStatus { pending, running, passed, failed }

class TestResult {
  String name;
  TestStatus status;
  String? errorMessage;
  Duration? duration;
}
```

### `test_runner_screen.dart`

تُشغِّل كل مجموعات الاختبار بالتوالي وتعرض النتائج:
- ورقة خضراء ✅ = passed
- دائرة حمراء ✖ = failed
- PENDING = لم يُشغَّل بعد
- مؤشر دوار = running

### مجموعات الاختبار

| المجموعة | الملف | ما تختبره |
|---|---|---|
| SYSTEM_ENGINE_CORE | `engine_tests.dart` | توليد اللوحة، كشف البطاقات، تبديل الأدوار، قاعدة N+1، شروط الفوز/الخسارة، إعادة التعيين |
| P2P_NETWORK | `network_tests.dart` | دورة حياة الـ Host، دورة الـ Client، التسلسل (Serialization) |
| VALIDATORS | `validator_tests.dart` | التحقق من IP |
| STORAGE | `storage_tests.dart` | حفظ وقراءة Hive، التعافي من الأخطاء |
| STATE_MACHINE | `state_tests.dart` | انتقالات الاتصال، تحديثات الحالة |
| EDGE_CASES_VOL4 | `edge_case_tests.dart` | النقر السريع، العميل المارق |
| GLOBAL_NETWORK | `appwrite_tests.dart` | تهيئة عميل Appwrite، حقن RoomService |
| STARTUP_CHECKS | `startup_tests.dart` | تهيئة Hive، جلب IP، جلسة Appwrite |

---

## 🔄 8. تدفق البيانات الكامل خطوة بخطوة

### سيناريو: لعبة عالمية عبر Appwrite

```
أحمد (Host)                          محمود (Client)
────────────────────────────────────────────────────
1. يفتح التطبيق
   main.dart: تهيئة Hive + Appwrite

2. يكتب اسمه → الانتقال لـ RoomSettingsScreen
   → ضبط إعدادات الغرفة (اسم + كود + عام/خاص)

3. إنشاء الغرفة:
   appwrite_room_service.createRoom()
   → Appwrite يُنشئ Document برقم فريد
   → الانتقال لـ MissionRoomScreen

4. اشتراك في Realtime لهذه الغرفة            
   roomService.subscribeToRoom(roomId)          

                                    5. يفتح التطبيق
                                       → يضغط "انضمام عالمي"
                                       → PublicRoomsScreen
                                    
                                    6. يختار الغرفة أو يكتب الكود
                                       getRoomByCode(code) → roomId
                                       appwriteRoomService.joinRoom()
                                    
                                    7. الانتقال لـ MissionRoomScreen
                                       → اشتراك في Realtime

8. ← أحمد يرى محموداً في القائمة
   (Realtime أرسل حدث تغيير في players)

9. أحمد يختار الفريق والدور
   updatePlayer(roomId, _myId, {team, role})
   → حدث Realtime → محمود يرى تغيير أحمد

10. محمود يختار فريقه ودوره
                                    → حدث Realtime → أحمد يراه

11. أحمد يضغط "بدء المهمة":
    _launchMission():
    a. resetGame() → لوحة عشوائية جديدة
    b. قراءة GameState.toJson()
    c. updateGameState(roomId, jsonStr) → upload
    d. startGame(roomId) → status = 'active'
    
    ← Realtime يُرسل حدث للجميع (status=active)

12. على جهاز الجميع:                           
    MissionRoomScreen يكتشف status=active
    → joinAppwriteGame(...) في ConnectionNotifier
    → Navigator.pushReplacement → GameBoardScreen

13. أحمد (Spymaster) يكتب التلميح:
    connectionProvider.sendClue("بحر", 2)
    → gameProvider.giveClue("بحر", 2)
    → _pushGameStateToAppwrite()
    → Realtime يُرسل للجميع
                                    ← محمود يرى التلميح فوراً

14. محمود (Operative) يضغط بطاقة:
    notifier.sendCardFlip(12)
                                    → gameProvider.revealCard(12)
                                    → _pushGameStateToAppwrite()
                                    → Realtime يُرسل

15. ← أحمد يرى البطاقة مكشوفة
```

---

## 📨 9. أنواع الرسائل بين اللاعبين

### رسائل Appwrite Realtime (حقل `game_state` في Document)

الحالة الكاملة تُرفع كـ JSON في حقل `game_state`. أي تغيير يُطلق إشعاراً لكل المشتركين.

### رسائل TCP للشبكة المحلية (SocketMessage)

| النوع | المرسَل من | البيانات | الوظيفة |
|---|---|---|---|
| `REQ_JOIN` | Client → Host | id, name, team, role | طلب الانضمام للغرفة |
| `LOBBY_UPDATE` | Host → Clients | players: [] | تحديث قائمة اللاعبين |
| `STATE_UPDATE` | Host → Clients | GameState JSON | تحديث حالة اللعبة |
| `CARD_FLIP` | Client → Host | index: int | طلب كشف بطاقة |
| `CLUE_GIVEN` | Client → Host | word, number | إرسال تلميح |
| `PASS_TURN` | Client → Host | {} | تمرير الدور |
| `PLAYER_UPDATE` | Client → Host | player: Player | تحديث دور/فريق |
| `START_GAME` | Host → Clients | {} | إشارة بدء اللعبة |

---

## 🛠 10. دليل التعديل والصيانة

### تغيير الألوان والتصميم

كل شاشة تعرّف ألوانها في أعلى الملف:
```dart
const _primary          = Color(0xFFFFB77A);  // البرتقالي الذهبي
const _secondary        = Color(0xFF95CEEF);  // الأزرق الفاتح
const _surface          = Color(0xFF001429);  // الخلفية الداكنة
const _surfaceContainerLow = Color(0xFF001D36);
```

> [!TIP]
> لتغيير اللون الأساسي للتطبيق، غيّر `_primary` في **كل شاشة**. الملفات: `start_screen.dart`، `mission_room_screen.dart`، `game_board_screen.dart`، `test_runner_screen.dart`.

### إضافة كلمات جديدة

**الملف:** `lib/core/constants/word_database.dart`
```dart
static const List<String> arabicWords = [
  'بحر', 'جبل', 'سمك', // ... أضف كلماتك هنا
];
```

### تعديل قوانين اللعبة

**الملف:** `lib/features/game_board/providers/game_provider.dart`

| ماذا تريد تغيير؟ | أين تعدّل؟ |
|---|---|
| توزيع الألوان (9-8-7-1) | `_generateInitialState()` في قسم `colors.addAll(...)` |
| الفريق الذي يبدأ | `currentTurn: Team.red` في نهاية `_generateInitialState()` |
| قانون N+1 | `int guesses = ...` في `giveClue()` |
| شرط الفوز (9 للأحمر) | `if (redCards == 9)` في `revealCard()` |
| منطق القاتل | `if (card.color == CardColor.assassin)` |

### إضافة نوع بطاقة جديد

1. أضف القيمة في `enum CardColor` في `word_card.dart`
2. أضف منطق التوزيع في `_generateInitialState()`
3. أضف حالة الكشف في `revealCard()` في `game_provider.dart`
4. أضف عرضاً مرئياً في `_SpymasterCard._getSpymasterStyle()`

### تغيير حد timeout لـ Appwrite

في `startup_tests.dart`:
```dart
.timeout(const Duration(seconds: 20)); // غيّر هذا الرقم
```

في `start_screen.dart`:
```dart
.ensureAnonymousSession()
.timeout(const Duration(seconds: 8)); // غيّر هذا الرقم
```

---

## 🆘 11. دليل حل المشاكل الشائعة

### مشكلة: HIVE_INIT فشل في الاختبار الذاتي

**السبب:** Hive لم يُهيَّأ قبل محاولة فتح Box في بيئة الاختبار.  
**الحل:** تم إضافة `try { await Hive.initFlutter(); } catch (_) {}` في بداية كل اختبار يستخدم Hive.

### مشكلة: APPWRITE_SESS فشل في الاختبار الذاتي

**الأسباب المحتملة:**
1. لا يوجد إنترنت
2. خادم Appwrite بطيء الاستجابة
3. الـ timeout قصير جداً (تم رفعه لـ 20 ثانية)
4. وصل مشروع Appwrite للحد المجاني

**الحل:** افحص الإنترنت أولاً. ثم تحقق من لوحة تحكم Appwrite أن المشروع نشط.

### مشكلة: اللوحة لا تُحدَّث عند باقي اللاعبين

**الأسباب المحتملة:**
1. انتهت جلسة Realtime Subscription
2. الـ game_state JSON أُفسد عند الرفع
3. فشلت `updateGameState()` بصمت

**الحل:**
- اتصل لاختبار `GLOBAL_NETWORK` في Test Runner
- راقب لوجات `_pushGameStateToAppwrite()` في Debug mode

### مشكلة: ANR (التطبيق يتجمد) عند البدء

**السبب:** عملية ثقيلة على الـ Main Thread.  
**الحل:** تم إضافة `timeout` على Hive وجعل تهيئة Appwrite غير محجوبة في `start_screen.dart`.

### مشكلة: لا يظهر IP المحلي

**السبب:** جهازك يستخدم واجهة شبكة ذات نطاق غير معتاد.  
**الحل:** افتح `ip_utils.dart` وأضف النطاق في دالة `_isPreferred()`.

### مشكلة: ENGINE تظهر حمراء في الاختبارات

**السبب:** تعديل خاطئ في `game_provider.dart`.  
**الحل:** راجع الشروط في `revealCard()` للتأكد أنها مطابقة لقواعد اللعبة الأصلية.

### مشكلة: بعد إعادة بناء المشروع يظهر خطأ في الـ freezed

**السبب:** الملفات المُولَّدة (`*.freezed.dart`, `*.g.dart`) قديمة.  
**الحل:**
```powershell
dart run build_runner build --delete-conflicting-outputs
```

---

*المانيوال مبني على: الكود الفعلي للمشروع بتاريخ أبريل 2026.*  
*أي تعديل جوهري في الملفات الأساسية يستوجب تحديث هذا المستند.*
