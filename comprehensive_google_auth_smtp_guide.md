# الدليل الشامل: تسجيل الدخول عبر Google والبريد الترحيبي (Gmail SMTP)
**Master Guide: Google Sign-In & Gmail SMTP Welcome Email**

هذا المستند هو المرجع الذهبي المتكامل لدمج ميزة تسجيل الدخول بحساب Google مع إرسال بريد ترحيبي تلقائي ومجاني باستخدام خوادم Gmail. يحتوي على **جميع الأوامر** و **الأكواد** اللازمة.

---

## 🛠️ المتطلبات التقنية (Prerequisites)
1.  حساب **Google Cloud Platform**.
2.  مشروع **Supabase**.
3.  حساب **Gmail** (للإرسال).
4.  تطبيق **Flutter**.
5.  **Node.js** (لتشغيل أوامر النشر دون الحاجة لتثبيت الـ CLI).

---

## 📋 المرحلة الأولى: إعداد جوجل (Google Cloud & Gmail)

### 1. تجهيز بريد الإرسال (Sender Email - Gmail)
*   **الهدف**: السماح للكود بالدخول لحسابك وإرسال الإيميلات.
*   **الخطوات**:
    1.  ادخل لحساب Google > **Security** > **2-Step Verification** (تأكد من تفعيله).
    2.  في نفس الصفحة، ابحث عن **App Passwords**.
    3.  أنشئ كلمة مرور جديدة باسم `Supabase App`.
    4.  🔴 **انسخ الكود (16 حرفاً)** واحتفظ به.

### 2. إعداد مشروع Google Cloud (للمصادقة)
*   **الرابط**: [Google Cloud Console](https://console.cloud.google.com/)
*   **الخطوات**:
    1.  **OAuth Consent Screen**:
        *   User Type: **External**.
        *   **Support Email** & **Developer Contact Info**: (إجباري).
    2.  **Android Client ID**:
        *   Package Name: (اسم حزمة تطبيقك، مثل `com.example.app`).
        *   SHA-1: استخرجه بالأمر التالي في التيرمينال:
            ```bash
            # Windows
            keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
            
            # Mac/Linux
            keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
            ```
    3.  **Web Client ID** (⚠️ الأهم):
        *   Type: **Web application**.
        *   Authorized redirect URI: `https://<YOUR_PROJECT_REF>.supabase.co/auth/v1/callback`
        *   🔴 **انسخ الـ Web Client ID**.

---

## ⚙️ المرحلة الثانية: إعداد Flutter

### 1. إضافة المكتبات
نفذ في التيرمينال:
```bash
flutter pub add google_sign_in supabase_flutter
flutter pub get
```

### 2. كود المصادقة (AuthService.dart)
استخدم **Web Client ID** وليس Android ID:

```dart
// ... imports

Future<AuthResult> signInWithGoogle() async {
  // ⚠️ Web Client ID من Google Cloud Console
  const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId: webClientId,
  );

  final googleUser = await googleSignIn.signIn();
  if (googleUser == null) return AuthResult.error('تم إلغاء تسجيل الدخول');

  final googleAuth = await googleUser.authentication;
  final accessToken = googleAuth.accessToken;
  final idToken = googleAuth.idToken; // هذا ما يحتاجه Supabase

  if (idToken == null) return AuthResult.error('فشل في استرجاع ID Token');

  // تسجيل الدخول في Supabase
  final response = await _supabase.auth.signInWithIdToken(
    provider: OAuthProvider.google,
    idToken: idToken,
    accessToken: accessToken,
  );

  // بعد النجاح: استدعاء الدالة السحابية
  if (response.user != null) {
      // إرسال الاسم والإيميل للدالة
      await _supabase.functions.invoke('welcome-email', body: {
          'email': response.user!.email,
          'name': response.user!.userMetadata?['full_name']
      });
  }
  // ...
}
```

---

## ☁️ المرحلة الثالثة: إعداد السيرفر (Supabase Backend)

### 1. الأوامر الأولية (Terminal Commands)
شغل هذه الأوامر في مجلد المشروع لربط حسابك:

```bash
# 1. تسجيل الدخول لـ Supabase (سيفتح المتصفح)
npx -y supabase login

# 2. ربط المشروع (استبدل xxx بالكود الخاص بمشروعك)
# تجد الـ Reference في رابط الداشبورد: supabase.com/dashboard/project/xxx
npx -y supabase link --project-ref xxx
```

### 2. تخزين المفاتيح السرية (Environment Variables)
لحفظ إيميل وكلمة مرور الجيميل بأمان:

```bash
npx -y supabase secrets set GMAIL_USER="your-email@gmail.com" GMAIL_APP_PASSWORD="xxxx xxxx xxxx xxxx" --project-ref xxx
```

### 3. إنشاء الدالة
أنشئ ملف `supabase/functions/welcome-email/index.ts` وضع فيه الكود التالي:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createTransport } from "npm:nodemailer@6.9.13"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // 1. Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, name } = await req.json()
    if (!email) throw new Error('Email is required')

    // 2. Setup Gmail Transporter
    const transporter = createTransport({
      service: 'gmail',
      auth: {
        user: Deno.env.get("GMAIL_USER"),
        pass: Deno.env.get("GMAIL_APP_PASSWORD"),
      },
    })

    // 3. Send Email (Arabic TemplateHTML)
    const info = await transporter.sendMail({
      from: `"Balanceer App" <${Deno.env.get("GMAIL_USER")}>`,
      to: email,
      subject: `مرحبًا ${name || 'عزيزي'} | بداية جديدة`,
      html: `
        <div style="direction:rtl;font-family:Tahoma;background:#f4f6f9;padding:30px 0">
          <div style="max-width:600px;margin:auto;background:#fff;border-radius:10px;padding:20px;">
            <h2 style="color:#2a5298">أهلاً بك في Balanceer!</h2>
            <p>سعداء بانضمامك إلينا.</p>
          </div>
        </div>
      `,
    })

    return new Response(JSON.stringify({ messageId: info.messageId }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { 
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
    })
  }
})
```

### 4. نشر الدالة (Deploy) 🚀
هذا الأمر يرفع الكود للسيرفر ويجعله حياً:

```bash
npx -y supabase functions deploy welcome-email --no-verify-jwt --project-ref xxx
```

---

## ⚡ ملخص الأوامر السريعة (Terminal Cheat Sheet)

| المهمة | الأمر |
| :--- | :--- |
| **Login** | `npx -y supabase login` |
| **Link Project** | `npx -y supabase link --project-ref <REF>` |
| **List Secrets** | `npx -y supabase secrets list --project-ref <REF>` |
| **Set Secrets** | `npx -y supabase secrets set KEY=VALUE --project-ref <REF>` |
| **Deploy Function** | `npx -y supabase functions deploy <NAME> --no-verify-jwt --project-ref <REF>` |
| **Check Logs** | `npx -y supabase functions logs --project-ref <REF>` |
| **Get SHA-1** | `keytool -list -v ...` |

---

**تم بحمد الله. هذا الدليل شامل لكل خطوة من الصفر حتى الإطلاق!** 🎯




























**من هنا يبدا الدليل القديم !** 🎯


# الدليل الشامل: تسجيل الدخول عبر Google والبريد الترحيبي (Gmail SMTP)
**Master Guide: Google Sign-In & Gmail SMTP Welcome Email**

هذا المستند هو مرجع كامل وخطوة بخطوة لدمج ميزة تسجيل الدخول بحساب Google مع إرسال بريد ترحيبي تلقائي ومجاني باستخدام خوادم Gmail.

---

## 🛠️ المتطلبات التقنية (Prerequisites)
1.  حساب **Google Cloud Platform**.
2.  مشروع **Supabase**.
3.  حساب **Gmail** (للإرسال).
4.  تطبيق **Flutter**.
5.  **Node.js** (لتشغيل أوامر النشر).

---

## 📋 المرحلة الأولى: إعداد جوجل (Google Cloud & Gmail)

### 1. تجهيز بريد الإرسال (Sender Email)
*   **الهدف**: السماح للكود بالدخول لحسابك وإرسال الإيميلات.
*   **الخطوات**:
    1.  ادخل لحساب Google > **Security** > **2-Step Verification** (تأكد من تفعيله).
    2.  في نفس الصفحة، ابحث عن **App Passwords**.
    3.  أنشئ كلمة مرور جديدة باسم `Supabase App`.
    4.  🔴 **انسخ الكود (16 حرفاً)** واحتفظ به، لن تحتاج لكلمة مرورك الأصلية.

### 2. إعداد مشروع Google Cloud (للمصادقة)
*   **الهدف**: الحصول على مفاتيح الربط (Client IDs).
*   **الخطوات**:
    1.  أنشئ مشروعاً جديداً في [Google Cloud Console](https://console.cloud.google.com/).
    2.  **OAuth Consent Screen**:
        *   اضبط `User Type` إلى **External**.
        *   **مهم جداً**: عبئ حقول **Support Email** و **Developer Contact Info** (بدونهما لن يعمل التطبيق).
    3.  **Create Credentials (Android ID)**:
        *   النوع: **Android**.
        *   Package Name: (اسم حزمة تطبيقك، مثل `com.example.app`).
        *   SHA-1: استخرجه من جهازك باستخدام الأمر:
            `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey`
    4.  **Create Credentials (Web ID)**: ⚠️ **هذا هو الأهم!**
        *   النوع: **Web application**.
        *   Authorized redirect URI: `https://<YOUR_PROJECT_ID>.supabase.co/auth/v1/callback`
        *   🔴 **احتفظ بهذا الـ Web Client ID**، سنستخدمه في كل مكان.

---

## ⚙️ المرحلة الثانية: إعداد Supabase

### 1. تفعيل Google Auth
*   اذهب إلى **Authentication** > **Providers** > **Google**.
*   **Authorized Client IDs**: أضف **Web Client ID** (الذي أنشأناه في الخطوة السابقة).
*   *(اختياري)*: يمكنك إضافة Android Client ID أيضاً، لكن Web ID هو الأساس.

### 2. إعداد المتغيرات السرية (Secrets)
*   لتخزين بيانات Gmail بأمان بعيداً عن الكود.
*   نفذ الأمر التالي في التيرمينال (داخل مجلد المشروع):
    ```bash
    npx -y supabase secrets set GMAIL_USER="your-email@gmail.com" GMAIL_APP_PASSWORD="your-app-password" --project-ref <your-project-ref>
    ```

---

## 💻 المرحلة الثالثة: كود التطبيق (Flutter)

### 1. الإعدادات (Setup)
*   `pubspec.yaml`: أضف `google_sign_in` و `supabase_flutter`.
*   `android/app/build.gradle`: تأكد من `minSdkVersion 21` أو أعلى.

### 2. كود المصادقة (AuthService)
النقطة الجوهرية هنا هي استخدام **Web Client ID** في خانة `serverClientId` (حتى لو كنت تبرمج للأندرويد).

```dart
Future<AuthResult> signInWithGoogle() async {
  // ⚠️ استخدم Web Client ID هنا
  const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';

  final GoogleSignIn googleSignIn = GoogleSignIn(
    serverClientId: webClientId,
  );

  final googleUser = await googleSignIn.signIn();
  // ... بقية خطوات استخراج التوكن وتسجيل الدخول في Supabase
  
  // بعد النجاح: استدعاء الدالة السحابية
  if (response.user != null) {
      _supabase.functions.invoke('welcome-email', body: {
          'email': response.user!.email,
          'name': response.user!.userMetadata?['full_name']
      });
  }
}
```

---

## ☁️ المرحلة الرابعة: الدالة السحابية (Edge Function)

### 1. الكود (index.ts)
نستخدم مكتبة `nodemailer` للربط مع Gmail SMTP.

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createTransport } from "npm:nodemailer@6.9.13"

serve(async (req) => {
    // ... (CORS Handling) ...
    
    const { email, name } = await req.json()
    
    // إعداد ناقل Gmail
    const transporter = createTransport({
        service: 'gmail',
        auth: {
            user: Deno.env.get("GMAIL_USER"), // يقرأ من Secrets
            pass: Deno.env.get("GMAIL_APP_PASSWORD"),
        },
    });

    // إرسال الإيميل
    await transporter.sendMail({
        from: `"App Name" <${Deno.env.get("GMAIL_USER")}>`,
        to: email, // يرسل لأي مستخدم
        subject: "Welcome! 🎉",
        html: `<h1>Welcome ${name}</h1>...`
    });
    
    // ...
})
```

### 2. النشر (Deployment)
لنشر الدالة مباشرة باستخدام `npx`:
```bash
npx -y supabase functions deploy welcome-email --no-verify-jwt --project-ref <your-project-ref>
```

---

## ✅ خطة الاختبار (Testing Checklist)
1.  [ ] تأكد من مطابقة SHA-1 في جهازك مع Google Console.
2.  [ ] تأكد من وجود **Support Email** في شاشة الموافقة.
3.  [ ] تأكد من استخدام **Web Client ID** كـ `serverClientId` في Flutter وكـ `Authorized Client ID` في Supabase.
4.  [ ] سجل الدخول بحساب جديد.
5.  تحقق من وصول الإيميل! (بما أننا نستخدم Gmail، سيصل لأي إيميل).

---

**هذا الدليل صالح للاستخدام مع أي مشروع Flutter + Supabase مستقبلاً.** 🚀





npx -y supabase functions deploy welcome-email --no-verify-jwt --project-ref yaaarlufcephyhoutrpj