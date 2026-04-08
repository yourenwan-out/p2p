# المانيوال المعماري — الجزء الثالث والأخير
# (الاختبارات الذاتية تفصيلاً، إعدادات Android، سيناريوهات الانقطاع، مستقبل المشروع)

> يكمل [الجزء الأول](./architecture_manual.md) و [الجزء الثاني](./architecture_manual_part2.md).

---

## 🔬 شرح الاختبارات الذاتية — كل اختبار وما يتحقق منه

نظام الاختبار الذاتي هو أداتك الأولى لتشخيص أي عطل. افهم كل اختبار حتى تعرف ماذا يعني فشله.

---

### مجموعة SYSTEM_ENGINE_CORE — `engine_tests.dart`

**اختبار 1: `Engine: Board Generation`**
```
يتحقق من:
  ✓ عدد البطاقات = 25 بالضبط
  ✓ البطاقات الحمراء = 9
  ✓ البطاقات الزرقاء = 8
  ✓ البطاقات المحايدة = 7
  ✓ بطاقة القاتل = 1

فشله يعني: تم تعديل _generateInitialState() بشكل خاطئ
```

**اختبار 2: `Engine: Card Revealing` (في الكود هو اختبار التلميح)**
```
يتحقق من:
  ✓ giveClue('TEST', 2) → currentClueWord = 'TEST'
  ✓ remainingGuesses = 3 (قانون N+1: 2+1=3)

فشله يعني: كُسر قانون N+1 في giveClue()
```

**اختبار 3: `Engine: Turn Switching`**
```
يتحقق من:
  ✓ كشف بطاقة نفس الفريق → الدور لا يتغير
  ✓ كشف بطاقة محايدة → الدور يتغير للفريق الآخر فوراً
  ✓ كشف بطاقة العدو → الدور يتغير فوراً

فشله يعني: منطق _switchTurn() أو شروط revealCard() تعطلت
```

**اختبار 4: `Engine: N+1 Rule`**
```
يتحقق من:
  يعطي تلميح برقم 2 (يسمح بـ 3 تخمينات)
  ✓ التخمين الأول: الدور لا يزال للفريق نفسه
  ✓ التخمين الثاني: الدور لا يزال للفريق نفسه
  ✓ التخمين الثالث (N+1): الدور ينتقل تلقائياً

فشله يعني: منطق نفاد التخمينات في revealCard() كُسر
```

**اختبار 5: `Engine: Win/Loss Conditions`**
```
Sub-Test أ — فوز الأحمر:
  ✓ كشف 9 بطاقات حمراء → isGameOver=true, winner=red

Sub-Test ب — القاتل:
  ✓ كشف بطاقة القاتل → isGameOver=true
  ✓ الفريق المقابل (الذي لم يكشف القاتل) يفوز

فشله يعني: شروط الفوز في revealCard() تعطلت
```

**اختبار 6: `Engine: Reset Game`**
```
يتحقق من:
  يقدم تلميحاً ويكشف بطاقة، ثم يريست
  ✓ لا توجد بطاقات مكشوفة بعد الريست
  ✓ currentClueWord = null
  ✓ isGameOver = false

فشله يعني: resetGame() لا يُعيد كل الحقول لحالتها الأولية
```

---

### مجموعة STARTUP_CHECKS — `startup_tests.dart`

**اختبار 1: `Startup: Hive initialization`**
```
يتحقق من:
  ✓ Hive.initFlutter() يعمل خلال 4 ثوانٍ
  ✓ settingsBox يمكن فتحه

فشله يعني:
  - مشكلة في تخزين الجهاز (نادر)
  - timeout لأن الجهاز بطيء جداً → زد الـ timeout في الكود
```

**اختبار 2: `Startup: Network IP fetching`**
```
يتحقق من:
  ✓ NetworkInterface.list() يعمل خلال 3 ثوانٍ

فشله يعني:
  - الجهاز ليس متصلاً بأي شبكة
  - صلاحية INTERNET غائبة من AndroidManifest (لكنها موجودة)
```

**اختبار 3: `Startup: Appwrite Anonymous Session`**
```
يتحقق من:
  ✓ AuthService.ensureAnonymousSession() يعمل خلال 20 ثانية
  ✓ Appwrite يقبل إنشاء أو إيجاد جلسة مجهولة

فشله يعني (بالأولوية):
  1. لا يوجد إنترنت
  2. خادم Appwrite بطيء أو تجاوزت الحد المجاني
  3. المشروع محذوف أو معطل في لوحة Appwrite
  4. Project ID أو Endpoint خاطئ في appwrite_providers.dart
```

---

### مجموعة P2P_NETWORK — `network_tests.dart`

هذه الاختبارات تتحقق من دورة حياة TCP كاملة:
```
✓ SocketHost يمكنه فتح المنفذ 4567
✓ SocketClient يمكنه الاتصال بـ localhost:4567
✓ تسلسل SocketMessage (JSON encode/decode يعمل صحيحاً)

فشله يعني:
  - المنفذ 4567 محجوز بعملية أخرى
  - جدار الحماية (Firewall) يمنع الاستماع
  - تعارض في النسخة يكسر JSON
```

---

### مجموعة STORAGE — `storage_tests.dart`

```
✓ Hive يمكنه حفظ قيمة وقراءتها من 'testBox'
✓ التعافي من الخطأ: لا يتعطل عند فتح صندوق غير موجود

فشله يعني:
  - الذاكرة الداخلية للجهاز ممتلئة
  - أذونات الكتابة للتطبيق محجوبة
```

---

## 🤖 إعدادات Android المهمة

### `AndroidManifest.xml` — الصلاحيات والإعدادات

**الصلاحية الوحيدة المطلوبة:**
```xml
<uses-permission android:name="android.permission.INTERNET" />
```
هذه تسمح لـ:
- الاتصال بـ Appwrite عبر HTTPS
- فتح خادم TCP محلي (socket)
- جلب Google Fonts

**اسم التطبيق في Android:**
```xml
android:label="الأسماء الرمزية"
```
هذا ما يظهر في قائمة التطبيقات وأثناء التثبيت.

**إعدادات Activity:**
```xml
android:launchMode="singleTop"       ← يمنع فتح نسخ متعددة من التطبيق
android:hardwareAccelerated="true"   ← تسريع الرسومات (مهم للـ animations)
android:windowSoftInputMode="adjustResize" ← لوحة المفاتيح تُصغّر الشاشة ولا تغطيها
```

> [!WARNING]
> إذا أضفت Push Notifications مستقبلاً، ستحتاج صلاحية `POST_NOTIFICATIONS` وإعدادات Firebase. لا تضف صلاحيات غير ضرورية.

---

### `styles.xml` — شاشة التحميل (Splash Screen)

```xml
<!-- اللون الذي يظهر قبل تحميل Flutter -->
<style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
  <item name="android:windowBackground">@drawable/launch_background</item>
  <item name="android:windowFullscreen">true</item>
</style>

<!-- اللون خلف واجهة Flutter أثناء التشغيل -->
<style name="NormalTheme" parent="@android:style/Theme.Black.NoTitleBar">
  <item name="android:windowBackground">#FF001429</item>  ← نفس _surface تماماً
  <item name="android:windowFullscreen">true</item>
</style>
```

**لماذا `#FF001429`؟**
هو نفس لون الخلفية الداكنة في التطبيق `const _surface = Color(0xFF001429)`. هذا يجعل الانتقال من شاشة التحميل للتطبيق سلساً بدون وميض.

> [!TIP]
> إذا غيّرت لون خلفية التطبيق، غيّر `#FF001429` هنا أيضاً لتتطابق.

---

### `build.gradle.kts` — إعدادات البناء

```kotlin
namespace = "com.example.p2p_codenames"   // معرّف التطبيق (Package ID)
applicationId = "com.example.p2p_codenames"

// Java 17 (مطلوب لـ Flutter الحديث)
sourceCompatibility = JavaVersion.VERSION_17
targetCompatibility = JavaVersion.VERSION_17

// اسم ملف الـ APK المُخصَّص
outputFileName = "الأسماء_الرمزية.apk"
```

> [!IMPORTANT]
> إذا أردت نشر التطبيق على Google Play يوماً ما، يجب تغيير `applicationId` من `com.example.p2p_codenames` إلى اسم نطاق خاص بك مثل `com.yourdomain.codenames`. لا يمكن تغييره بعد النشر.

---

## 🔌 سيناريوهات الانقطاع وكيفية التعامل معها

### سيناريو 1: انقطع الإنترنت أثناء لعبة Appwrite

**ماذا يحدث؟**
```
- Realtime WebSocket ينقطع
- لا يصل _heartbeatTimer بعد 60 ثانية
- الـ Subscription تبقى مفتوحة لكن لا تستقبل شيئاً
- اللعبة "تتجمد" — اللاعبون يرون اللوحة لكن لا تحديثات
```

**ماذا يحدث للغرفة في Appwrite؟**
```
- Appwrite لا يحذف الغرفة فوراً
- بعد 5 دقائق من آخر heartbeat → cleanupOldRooms() ستحذفها
  (لكن هذه الدالة تُستدعى فقط عند إنشاء غرفة جديدة!)
```

**الحل الحالي في الكود:** لا يوجد إعادة اتصال تلقائية (Auto-reconnect).

**كيف تحله يدوياً (للمستخدم):** اضغط زر العودة → ستظهر الشاشة الرئيسية → ابحث عن الغرفة مجدداً إن لم تُحذف.

**كيف تُضيف Auto-reconnect مستقبلاً:**
```dart
// في joinAppwriteGame() بعد subscription.stream.listen()
subscription.stream.handleError((e) {
  // أعد الاشتراك بعد 3 ثوانٍ
  Future.delayed(Duration(seconds: 3), () => joinAppwriteGame(...));
});
```

---

### سيناريو 2: خرج الـ Host من لعبة LAN أثناء اللعب

**ماذا يحدث؟**
```
- _serverSocket تُغلق
- كل الـ clients يحصلون على onDone في socket_client.dart
- SocketClient يطبع "Disconnected from host" لكن لا يفعل شيئاً آخر
- اللاعبون يرون اللوحة مجمدة بدون أخطاء واضحة
```

**الحل الحالي:** لا إشعار "انقطع الاتصال بالمضيف".

**كيف تُضيف إشعاراً مستقبلاً في `socket_client.dart`:**
```dart
onDone: () {
  _logger.i('Disconnected from host');
  // أضف هذا:
  onMessageReceived(SocketMessage(type: 'HOST_DISCONNECTED', payload: {}));
}
// ثم في _handleMessage() في connection_provider.dart:
else if (message.type == 'HOST_DISCONNECTED') {
  setError('انقطع الاتصال بالمضيف');
}
```

---

### سيناريو 3: أنقطع الاتصال باللاعب في LAN (Client)

**ماذا يحدث؟**
```
- socket_host._handleDisconnect(client) تُستدعى
- اللاعب يُحذف من _players
- _broadcastLobbyUpdate() يُرسل قائمة محدّثة للجميع
- اللاعبون الآخرون يرون اسمه يختفي من القائمة
```
هذا يعمل بشكل صحيح بالفعل ✅

---

### سيناريو 4: الـ Host يضغط زر العودة من لوحة اللعب (Appwrite)

```
_handleExitGame() في game_board_screen.dart:
  1. disconnect() → يُغلق Realtime Subscription + يُلغي Heartbeat Timer
  2. إذا كان Host: deleteRoom(appwriteRoomId) → يحذف الغرفة نهائياً
  3. Navigator.pop() → العودة للشاشة السابقة

ماذا يحدث للـ Clients؟
  - يتلقون حدث Realtime "تم حذف المستند"
  - الـ stream.listen() يحصل على payload فارغ أو حدث حذف
  - لا يوجد كود لمعالجة هذا الحدث حالياً → يتجمدون في لوحة اللعب
```

**كيف تُضيف معالجة للـ Clients عند خروج الـ Host:**
```dart
// في joinAppwriteGame() عند الاستماع للـ Realtime stream:
subscription.stream.listen((event) {
  // أضف هذا للتحقق من حذف المستند:
  if (event.events.any((e) => e.contains('delete'))) {
    // الغرفة حُذفت! عد للبداية
    disconnect();
    // أضف callback للـ UI لإظهار رسالة وإغلاق الشاشة
  }
  // ... باقي الكود
});
```

---

## ⚖️ مقارنة: LAN مقابل Appwrite — متى تستخدم كلاً منهما؟

| المعيار | شبكة محلية LAN | عالمي Appwrite |
|---|---|---|
| **الاتصال المطلوب** | Wi-Fi أو Hotspot مشترك | إنترنت |
| **السرعة** | فورية (< 1ms) | 100-500ms |
| **الحد الأقصى للاعبين** | غير محدود عملياً | حسب خطة Appwrite |
| **الإعداد** | لا إعداد — فقط نفس الشبكة | يحتاج إنشاء غرفة |
| **عند انقطاع الاتصال** | الـ Client يعرف فوراً | قد يتأخر الإشعار |
| **التحكم بالألوان** | الـ Host يُخفيها عن الـ Operative ✅ | لا إخفاء — كل حالة ترتفع كاملة ⚠️ |
| **الـ Heartbeat** | لا يحتاج | كل 60 ثانية لمنع الحذف التلقائي |

> [!WARNING]
> **ثغرة أمنية في وضع Appwrite:** الـ Operative يستطيع نظرياً قراءة حقل `game_state` من Appwrite مباشرة ويرى ألوان البطاقات. في وضع LAN، الـ Host يُرسل نسخة مُحجبة للـ Operative حيث كل البطاقات غير المكشوفة تظهر كـ `neutral`.  
> هذا ليس مشكلة عملية لأن اللعبة تعتمد على الثقة، لكن احتفظ بهذا الفرق في ذهنك.

---

## 🗂 الفرق بين وضعَي الاتصال في الكود

```dart
// في ConnectionNotifier — كيف تعرف أي وضع أنت فيه:

if (state.appwriteRoomId != null) {
  // ← وضع Appwrite العالمي
  // الأحداث ترتفع لـ Appwrite → تنزل لجميع اللاعبين عبر Realtime
} else if (state.isHost) {
  // ← وضع LAN كـ Host
  // الأحداث تُعالج محلياً ثم تُبث عبر TCP
} else {
  // ← وضع LAN كـ Client
  // الأحداث تُرسل للـ Host عبر TCP وتنتظر الرد
}
```

---

## 📝 فهم ملفات `*.freezed.dart` و `*.g.dart`

هذه الملفات مُولَّدة تلقائياً ولا تعدّلها يدوياً. لكن من الجيد أن تفهم ما تفعله:

### `game_state.freezed.dart` يُنشئ تلقائياً:
```dart
// نسخة .copyWith() للتعديل الآمن:
state.copyWith(currentTurn: Team.blue)
// بدل: state.currentTurn = Team.blue (مستحيل لأنها immutable)

// مقارنة بالقيمة (==) بدل بالمرجع
// toString() تفيد في الـ debugging
```

### `game_state.g.dart` يُنشئ تلقائياً:
```dart
// GameState.fromJson(map) ← تحويل JSON القادم من الشبكة لـ object
// state.toJson()          ← تحويل object لـ JSON للرفع للشبكة
```

**ماذا تفعل إذا رأيت خطأ مثل:**
```
Error: No method 'copyWith' found for 'GameState'
```
الحل: شغّل `dart run build_runner build --delete-conflicting-outputs`

---

## 🌱 توصيات التطوير المستقبلي

### القريب — يمكن تنفيذه بسهولة

1. **إشعار انقطاع الاتصال للـ Clients (Appwrite)**
   - المكان: `joinAppwriteGame()` في `connection_provider.dart`
   - استمع لأحداث الـ delete في stream

2. **حفظ النتائج تاريخياً**
   - المكان: `game_board_screen.dart` عند `isGameOver == true`
   - احفظ في Hive: الفائز + التاريخ + عدد الجولات

3. **إضافة مؤقت للدور (Timer)**
   - المكان: أضف حقل `DateTime? turnStartTime` في `GameState`
   - أضف Provider يعدّ تنازلياً ويستدعي `passTurn()` عند الانتهاء

4. **ضبط الألوان للـ Operative في Appwrite**
   - المكان: `_pushGameStateToAppwrite()` في `connection_provider.dart`
   - بدل رفع الـ state الكامل، ارفع نسخة محجوبة للـ Operatives

### المتوسط — يحتاج تصميم

5. **دعم أكثر من لغة للكلمات**
   - أضف `enum Language { arabic, english }` في `GameState`
   - أضف قاموس إنجليزي في `word_database.dart`
   - في `_generateInitialState()` اختر القاموس بناءً على الإعداد

6. **وضع المشاهد (Spectator Mode)**
   - أضف `Role.spectator` في `player.dart`
   - في `GameBoardScreen` عرض لوحة للقراءة فقط بدون ألوان

7. **إشعارات Push عند بدء اللعبة**
   - يحتاج Firebase + صلاحية `POST_NOTIFICATIONS`

### البعيد — يحتاج معمارية جديدة

8. **تاريخ الألعاب والإحصائيات**
   - قاعدة بيانات محلية أكثر تعقيداً (SQLite أو Hive TypeAdapters)

9. **بطاقات مخصصة (Custom Word Packs)**
   - واجهة لإضافة كلمات من قبل المستخدم
   - حفظها في Hive وتحميلها بدل القاموس الافتراضي

---

## 🧪 كيف تكتب اختباراً جديداً للنظام الذاتي

إذا أضفت ميزة جديدة وتريد اختبارها في شاشة الفحص الذاتي:

**الخطوة 1:** أنشئ ملف في `lib/features/testing/suites/my_feature_tests.dart`:
```dart
import '../models/test_result.dart';

class MyFeatureTests {
  static Future<List<TestResult>> run() async {
    return [
      await _testMyFeature(),
    ];
  }

  static Future<TestResult> _testMyFeature() async {
    final startTime = DateTime.now();
    try {
      // اعمل الاختبار هنا
      final result = myFeatureFunction();
      if (result != expectedValue) {
        throw Exception('Expected $expectedValue, got $result');
      }
      return TestResult(
        name: 'MyFeature: Description',
        status: TestStatus.passed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      return TestResult(
        name: 'MyFeature: Description',
        status: TestStatus.failed,
        errorMessage: e.toString(),
      );
    }
  }
}
```

**الخطوة 2:** أضف المجموعة في `test_runner_screen.dart`:
```dart
// في قائمة _suites:
TestSuite(
  id: 'MY_FEATURE',
  name: 'MY_FEATURE_TESTS',
  runner: MyFeatureTests.run,
),
```

---

## 📌 الملفات التي تُعدَّل الأكثر (Hot Spots)

بناءً على تاريخ التطوير، هذه الملفات كانت الأكثر تعديلاً:

| الملف | لماذا يُعدَّل كثيراً | ما تحذر منه عند تعديله |
|---|---|---|
| `game_provider.dart` | قوانين اللعبة تحتاج ضبطاً دائماً | أي تغيير يُكسر اختبار ENGINE |
| `connection_provider.dart` | منطق الشبكة معقد | تأكد من معالجة كلا الوضعَين (LAN + Appwrite) |
| `appwrite_room_service.dart` | Appwrite API يتغير | تحقق من توافق إصدار Appwrite SDK |
| `start_screen.dart` | أول ما يراه المستخدم | أي تعديل يؤثر على تجربة الانطلاق |
| `game_board_screen.dart` | الواجهة الأكثر تعقيداً | تحقق من _canClickCard() عند تعديل قوانين اللعب |

---

## 🔚 ختام — حالة المشروع الراهنة

المشروع في حالة ممتازة ومستقرة وفق هذه المعطيات:

```
✅ flutter analyze lib → No issues found
✅ جميع اختبارات Engine تنجح
✅ جميع اختبارات Storage تنجح
✅ اختبار Appwrite Session يعمل (20 ثانية timeout)
✅ طبقة Hive آمنة من ANR (timeout + non-blocking)
✅ Logger معطّل في Release لمنع تجمد الجهاز
✅ Realtime Subscription + Heartbeat Timer يحافظان على الغرفة

⚠️ نقاط تحتاج انتباه مستقبلاً:
  - لا يوجد Auto-reconnect عند انقطاع الإنترنت
  - لا يوجد إشعار للـ Clients عند خروج الـ Host (Appwrite)
  - الـ Operative يستطيع رؤية ألوان البطاقات من Appwrite مباشرة
```

---

*هذا الجزء الثالث يُكمل المانيوال الكامل المكوّن من ثلاثة أجزاء.*  
*تاريخ الإنشاء: أبريل 2026 — بناءً على قراءة الكود الفعلي سطراً بسطر.*

```
الملفات الثلاثة:
  Part 1 → architecture_manual.md       (المعمارية، الـ Core، محرك اللعبة، تدفق البيانات)
  Part 2 → architecture_manual_part2.md (الشاشات، Appwrite، CI/CD، خريطة التنقل)
  Part 3 → architecture_manual_part3.md (الاختبارات، Android، سيناريوهات الانقطاع، المستقبل)
```
