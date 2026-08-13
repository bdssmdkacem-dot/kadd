# قائمة تحقق قبل نشر كدّ على Play Store

هذا الملف يغطي كل ما لازم قبل رفع أول نسخة. بعض النقط أنا كتبتها ليك جاهزة
(توقيع، سياسة الخصوصية)، وبعضها لازم تديرها بنفسك لأنها مرتبطة بحسابك على
Google Play (ما حدش غيرك يقدر يديرها).

## 1. التوقيع (Signing) — إلزامي، والبناء الحالي ما يكفيش لـ Play Store

`flutter build apk --release` بلا إعداد توقيع خاص بك كيخرج APK **موقّع
بمفتاح debug**، وPlay Store ما يقبلوش. الخطوات:

```bash
# 1. أنشئ مفتاح توقيع (مرة واحدة، واحفظه في مكان آمن — إذا ضاع ما تقدرش
#    تحدّث التطبيق فالمستقبل بنفس الـ listing)
keytool -genkey -v -keystore ~/kadd-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias kadd

# 2. أنشئ android/key.properties (بعد `flutter create` أو `build_local.sh`)
cat > android/key.properties << EOF
storePassword=<كلمة السر ديال المتجر>
keyPassword=<كلمة السر ديال المفتاح>
keyAlias=kadd
storeFile=/المسار/الكامل/لـ/kadd-release-key.jks
EOF
```

3. فـ `android/app/build.gradle` (أو `build.gradle.kts` حسب نسخة Flutter
   عندك — كتب هذا يدويًا لأن الصيغة تختلف بين Groovy وKotlin DSL، وتصحيح
   تلقائي هنا خطر يكسر البناء):

**Groovy (`build.gradle`):**
```groovy
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

**Kotlin DSL (`build.gradle.kts`):**
```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

4. **لا تدفع `key.properties` ولا ملف `.jks` لـ GitHub أبدًا** — أضفهما لـ
   `.gitignore` (`android/` كامل مذكور فيه أصلًا، لكن احتفظ بنسخة احتياطية
   من الملفين فمكان آمن خارج المستودع، مثل مدير كلمات سر).

**بديل أبسط:** إذا بغيتي Google يدير التوقيع نيابة عنك (موصى به من Google
نفسه)، فعّل **Play App Signing** من Play Console عند أول رفع — كتحتاج غير
مفتاح "upload key" مؤقت (بنفس أوامر `keytool` أعلاه)، وGoogle كيدير مفتاح
التوقيع النهائي بنفسه بشكل أأمن.

## 2. الأيقونة — منجزة

أيقونة حقيقية بألوان العلامة (قفل + حلقة الجهد) موجودة فـ
`assets/icon/icon.png` و`icon_foreground.png`، ومربوطة عبر
`flutter_launcher_icons` فـ `pubspec.yaml`. `build_local.sh` والـ CI كيولدوها
تلقائيًا. ألقِ نظرة عليها بعد أول بناء (`android/app/src/main/res/mipmap-*`)
وقوليا إذا حاب تعديل فالألوان أو الشكل.

## 3. الصلاحيات الحساسة — لازم تبرير واضح فـ Play Console

كدّ يطلب 3 صلاحيات حساسة، وPlay Console غادي يطلب منك تبرير كل وحدة عند
الرفع (نموذج "Permissions Declaration" + أحيانًا فيديو توضيحي):

| الصلاحية | التبرير المقترح (بالإنجليزية، كيف تكتبها فالنموذج) |
|---|---|
| `PACKAGE_USAGE_STATS` | "Used solely to detect which app is currently in the foreground, in order to show a screen-lock overlay the user has configured. No usage data is collected, stored remotely, or shared." |
| `CAMERA` | "Used on-device only, to count exercise repetitions via pose detection and to verify a prayer rug photo before unlocking. No images or video are uploaded or stored outside the device." |
| `QUERY_ALL_PACKAGES` | "Used to let the user pick which of their own installed apps to lock behind an exercise/prayer check. The app only reads app names and icons for display in this picker — it does not collect, transmit, or analyze the list of installed apps." |

**ملاحظة:** صلاحية الموقع (`ACCESS_FINE_LOCATION`) تمت إزالتها — مواقيت
الصلاة دابا تُحسب عبر اختيار المدينة يدويًا (`lib/models/city.dart`)، بلا
حاجة لأي بيانات موقع حقيقية. تبرير أقل = مراجعة Play Store أسرع.

الخدمة الأمامية (`LockForegroundService`) محتاجة كذلك تبرير
`FOREGROUND_SERVICE_SPECIAL_USE` — النص موجود مسبقًا فـ
`android_additions/manifest_application.xml`، تأكد يعكس الاستعمال الحقيقي
قبل الرفع.

## 4. سياسة الخصوصية — مسودة جاهزة، لازم تستضيفها

Play Console يطلب رابط سياسة خصوصية عام (Public URL) بمجرد ما تطلب صلاحية
الكاميرا أو الموقع. مسودة جاهزة فـ `PRIVACY_POLICY.md` — بدّل `[بريدك
الإلكتروني]` و`[تاريخ]`، ثم انشرها كصفحة ويب حقيقية (GitHub Pages من نفس
المستودع أسهل طريقة: فعّل Pages من إعدادات المستودع، اختر فرع `main`
ومجلد `/` أو `/docs`) وحط رابطها فـ Play Console.

**تنويه:** أنا ماشي محامي، وهاد النص مسودة تقنية دقيقة تعكس السلوك الفعلي
للكود، ماشي استشارة قانونية. إذا التطبيق غادي يستهدف بلدان بقوانين حماية
بيانات صارمة (مثل GDPR الأوروبي)، يستحسن مراجعة محامٍ قبل النشر النهائي.

## 5. نموذج Data Safety فـ Play Console

عند تعبئة النموذج (Data safety section)، بناءً على الكود الفعلي:

- **App info and performance (installed apps list)**: يُجمع محليًا فقط
  لعرضه فقائمة اختيار التطبيقات المراد قفلها، **لا يُخزَّن ولا يُشارَك**
  خارج الجهاز.
- **Photos/videos (Camera)**: **لا يُجمع ولا يُخزَّن** فيما يخص العقلات
  (المعالجة كاملة فالذاكرة، لا حفظ). صورة سجادة الصلاة **تُلتقط وتُحلَّل
  محليًا** لكن لا تُرفع لأي خادم — صرّح أنها "Processed ephemerally, not
  stored".
- **App activity (Usage stats)**: يُجمع محليًا فقط لغرض القفل، **لا
  يُخزَّن بشكل دائم ولا يُشارَك** مع أي طرف.
- **لا بيانات موقع** — الميزة دابا تعتمد على اختيار المدينة يدويًا، بلا
  GPS ولا أي صلاحية موقع.
- **لا بيانات شخصية أخرى تُجمع بواسطة تطبيقنا مباشرة** (لا حساب مستخدم، لا
  بريد إلكتروني).
- **Device or other IDs / Advertising ID**: يُجمع بواسطة **AdMob SDK**
  (وليس بواسطة كود التطبيق نفسه) لغرض عرض وقياس الإعلانات، ويُشارَك مع
  Google. صرّح فـ Data Safety: "Advertising ID — collected, shared with
  third party (Google), purpose: Advertising or marketing". راجع قسم
  AdMob أسفله للتفاصيل الكاملة اللي خاصك تصرّح بيها.

## 6. AdMob — الإعلانات

الكود دابا فيه إعلان بانر (فالصفحة الرئيسية) وإعلان بيني (يظهر بعد كل 3
مرات فتح بالتمارين، ماشي بعد فتح سجادة الصلاة). لكن خدام حاليًا **بمعرّفات
تجريبية** — لازم تبدلهم بمعرّفاتك الحقيقية قبل النشر:

1. سجّل/سجّل الدخول فـ https://apps.admob.com بحساب Google ديالك.
2. **Apps → Add app**. اختار "No" إذا التطبيق ماشي منشور بعد على Play
   Store (تقدر تربطه لاحقًا بعد أول نشر)، أو "Yes" وحدد التطبيق إذا كان
   منشور أصلًا.
3. من نفس الخطوة، AdMob غادي يعطيك **App ID** (كيبدا بـ `ca-app-pub-...~...`).
   بدّل بيه القيمة التجريبية فـ:
   `android_additions/manifest_application.xml` (سطر `APPLICATION_ID`).
4. **Ad units → Add ad unit** — دير وحدة **Banner** ووحدة **Interstitial**
   (كل وحدة عندها معرّف `ca-app-pub-...-/...`). بدّل بيهم القيم التجريبية
   فـ `lib/services/ads_service.dart` داخل كلاس `AdUnitIds`
   (`kAndroidBannerTestId` و `kAndroidInterstitialTestId`).
5. أعد بناء الـ APK/AAB (`./scripts/build_local.sh` أو GitHub Actions) —
   التعديل فـ manifest_application.xml محتاج يتزريق من جديد عبر
   `patch_manifest.py` كيفما سبق شرحه.
6. فـ Play Console، قسم **App content → Ads**: صرّح "Yes, my app contains
   ads".
7. لا داعي لأي إعداد إضافي لـ Families/COPPA — كدّ ماشي موجّه للأطفال
   (استمارة تصنيف المحتوى غادي تأكد هذا).
8. موافقة GDPR/UK (UMP) مبرمجة أصلًا فـ `AdsService` — كتظهر تلقائيًا
   للمستخدمين فأوروبا/بريطانيا عند أول فتح. ما خاصك دير شي حاجة زايدة، غير
   تأكد فـ AdMob console إن **Privacy & messaging → EU consent message**
   مفعّل (Google كيفعّلها افتراضيًا لكل حساب جديد).
9. تذكر تحدّث رابط سياسة الخصوصية (`PRIVACY_POLICY.md`) فـ Play Console
   وفـ AdMob's app-level privacy policy field — القسم الخاص بالإعلانات
   مزيد فيها من قبل.

**ملاحظة:** الإعلانات التجريبية (test ads) ما كتربح حتى فلوس، وGoogle
كيبان ليه بسهولة إذا نشرتي تطبيق بمعرّفات تجريبية Production — تأكد بدّلتي
الكل (App ID + الوحدتين) قبل الرفع لـ Play Store.



## 7. أشياء لازم تديرها بنفسك (حسابك أنت)

- إنشاء حساب Play Console (رسم لمرة واحدة ~25$)
- لقطات شاشة حقيقية من التطبيق (على الأقل 2 للهاتف) — نقدر نجهزهم بعد ما
  يخدم التطبيق على جهازك، أو نستعمل نفس المخططات (`kadd-mockups.html`)
  كمرجع تصميم للقطات حقيقية
- نص وصف التطبيق بالعربية (وبالإنجليزية إذا بغيتي جمهور أوسع) — نقدر
  نكتبه ليك
- استمارة تصنيف المحتوى (Content rating questionnaire) — أسئلة بسيطة،
  التطبيق ما فيهش محتوى حساس
- رفع أول نسخة على **Internal Testing track** أولًا (وليس مباشرة
  Production) — يعطيك وقت تتأكد الـ APK يخدم بلا مشاكل قبل ما يوصل لأي
  مستخدم حقيقي

## 8. آخر شيء قبل الرفع

- تأكد `pubspec.yaml`'s `version:` صار رقم حقيقي (مثلًا `1.0.0+1`)، مش
  `0.1.0` كيف هو دابا
- بدّل `applicationId`/`org` من `com.comptaflow.kadd` إذا بغيتي اسم حزمة
  مختلف — **لا يمكن تغييره بعد أول نشر**، فتأكد قبل
- جرب `flutter build appbundle --release` بدل `apk` للنشر النهائي —
  Play Store دابا كيفضّل `.aab` (Android App Bundle) على `.apk` مباشرة
