# ตั้งค่า Google Login — Monthly Flow

สถานะ: มี Firebase Project และไฟล์ตั้งค่า Android แล้ว การทดสอบ Google Login จริงยังต้องตรวจบนอุปกรณ์ โค้ดซิงค์ข้อมูลเพิ่มแล้ว ดู [การตั้งค่าซิงค์](CLOUD_SYNC_SETUP.md) สำหรับ Cloud Firestore และกฎสิทธิ์ก่อนใช้งานจริง

## ขอบเขตรอบนี้

- เข้าได้จาก ตั้งค่า → บัญชี → ดำเนินการต่อด้วย Google
- แสดงชื่อและอีเมลของผู้ใช้ที่ Firebase ยืนยันตัวตนแล้ว
- Firebase คืนสถานะบัญชีหลังเปิดแอปใหม่ และจัดการ session ให้
- ยกเลิก Google chooser แล้วอยู่หน้าเดิม; กดซ้ำระหว่างทำงานไม่ได้
- ออกจากระบบหลังยืนยัน โดยไม่ลบรายการเงินในเครื่อง
- แอปยังเปิดและใช้ข้อมูลออฟไลน์ได้ แม้ยังไม่ได้ตั้งค่า Firebase
- ข้อมูล SQLite แยกตาม Firebase UID แล้ว เมื่อเข้าสู่บัญชีแรกจะนำข้อมูลโหมดตั้งชื่อเข้าให้อัตโนมัติ ส่วนบัญชีอื่นไม่รับข้อมูลของบัญชีแรก
- ยังไม่ทำสมัครอีเมล ลบบัญชี ซิงก์ Excel หรือ Google Drive

## 1. สร้าง Firebase Project

1. เปิด [Firebase Console](https://console.firebase.google.com/) และสร้าง Project สำหรับ Monthly Flow
2. เปิด Authentication → Sign-in method → Google → Enable และเลือกอีเมลติดต่อของโปรเจกต์
3. Google Login ใช้ Authentication; การซิงค์ข้อมูลรอบใหม่ต้องเปิด Cloud Firestore และตั้งกฎตาม CLOUD_SYNC_SETUP.md ส่วน Storage ยังไม่ใช้

## 2. เชื่อม Android ก่อน

1. ใน Project settings → Your apps เพิ่ม Android app
2. Android package name ปัจจุบันคือ `com.example.monthly_flow` ให้ใช้ตรงกับ `android/app/build.gradle`
3. เพิ่ม SHA-1 และ SHA-256 ของใบรับรองที่ใช้เซ็นแอปที่ติดตั้งจริง สำหรับเครื่องพัฒนาใช้ debug keystore ของเครื่องนี้

หากมี keytool ใน PATH ใช้คำสั่งนี้เพื่อดู fingerprint ของ debug keystore:

```powershell
keytool -list -v -alias androiddebugkey -keystore "$env:USERPROFILE\.android\debug.keystore" -storepass android -keypass android
```

4. ดาวน์โหลด `google-services.json` ฉบับใหม่หลังเปิด Google provider และเพิ่ม fingerprint แล้ว วางที่ `android/app/google-services.json`
5. ไฟล์ต้องมี OAuth client แบบ Web (`client_type: 3`) สำหรับ Google Sign-In 7.x ซึ่ง Gradle ใช้สร้าง `default_web_client_id`
6. โค้ดเปิด Google Services plugin เมื่อพบไฟล์จริงแล้ว ไม่มีค่า Firebase ตัวอย่างในแอป
7. ติดตั้งใหม่ด้วย `flutter run` บนอุปกรณ์ Android ที่มี Google Play services
8. เข้า ตั้งค่า → บัญชี → Google Login และตรวจรายชื่อผู้ใช้ที่ Firebase Authentication → Users

แอป release ปัจจุบันยังใช้ debug signing ส่วน APK ที่สร้างใน CI อาจใช้ใบรับรอง debug คนละใบ ต้องลงทะเบียน fingerprint ของใบรับรองที่เซ็น APK นั้นจริง หรือกำหนดกุญแจเซ็นที่คงที่ก่อนใช้ทดสอบ Login ผ่าน APK จาก CI

## แก้ Google Login บน Emulator

ถ้า Google Login แสดง `providerConfigurationError` และ log มี `SERVICE_VERSION_UPDATE_REQUIRED` ให้ตรวจเวอร์ชัน Google Play services ของเครื่องทดสอบก่อนแก้ Firebase หรือ SHA อีกครั้ง

พบปัญหานี้กับ `Pixel_3a_API_33_x86_64`: Google Play services เป็น `22.50.14` (`225014047`) แต่ Credential Manager ที่ใช้อยู่ต้องการอย่างน้อย `230815045` จึงคืนข้อความ `getCredentialAsync no provider dependencies found` แม้แพ็กเกจ Google Sign-In จะรวม dependency ของ provider แล้ว

เตรียมเครื่องทดสอบใหม่ `Monthly_Flow_Pixel_6_API_35_Play` (Android 15 / API 35 / Google Play x86_64) แล้ว ตรวจพบ Play Store และ Google Play services `24.23.35` (`242335041`) พร้อมติดตั้งแอป Debug สำเร็จ ยังต้องให้ผู้ใช้เลือกหรือเพิ่มบัญชี Google และทดสอบ Login/Logout จริงก่อนถือว่าตรวจรับ OAuth สำเร็จ

- ใช้ Emulator ที่มีสัญลักษณ์ **Google Play** และอัปเดต Google Play services ผ่าน Play Store หรือใช้มือถือ Android จริงที่อัปเดตแล้ว
- เปิดบัญชี Google บนเครื่องทดสอบด้วยตนเอง แล้วลองเข้า ตั้งค่า → บัญชี → Google Login อีกครั้ง
- การเปลี่ยน Emulator บนเครื่องพัฒนาเดิมยังใช้ debug keystore เดิม จึงไม่ต้องเพิ่ม SHA ใหม่เพียงเพราะเปลี่ยน Emulator
- โหมด Debug บันทึกรหัสข้อผิดพลาด Google/Firebase สำหรับวิเคราะห์ปัญหา โดยไม่บันทึก OAuth token หรือข้อมูล credentials

## 3. เชื่อม iOS เมื่อพร้อมทดสอบบน Mac

- Bundle ID ปัจจุบัน: `com.monthus2543.monthlyflow`
- Firebase packages ที่ใช้ต้องการ iOS 15.0 ขึ้นไป จึงปรับ deployment target ของโปรเจกต์เป็น 15.0 แล้ว
- เพิ่ม iOS app ใน Firebase และดาวน์โหลด `GoogleService-Info.plist` หลังเปิด Google provider
- เพิ่มไฟล์ลง Runner target ใน Xcode ให้รวมใน Copy Bundle Resources เพื่อให้ `Firebase.initializeApp()` อ่านการตั้งค่าได้
- ใน `ios/Runner/Info.plist` เพิ่ม `GIDClientID` โดยใช้ค่า `CLIENT_ID` จากไฟล์จริง
- เพิ่ม `CFBundleURLTypes` / `CFBundleURLSchemes` โดยใช้ค่า `REVERSED_CLIENT_ID` จากไฟล์จริง
- หากมี Podfile ต้องใช้ `platform :ios, '15.0'` หรือสูงกว่า จากนั้นติดตั้ง dependencies และทดสอบบน iPhone/Simulator ที่รองรับ
- ยังไม่ใส่ client ID หรือ URL scheme ที่แต่งขึ้น ต้องใช้ค่าจาก Firebase Project จริง

## ทางเลือก FlutterFire CLI

ใช้ [FlutterFire CLI ตามเอกสาร Firebase](https://firebase.google.com/docs/flutter/setup) เพื่อช่วยลงทะเบียนแอปและเตรียม native config ได้ โค้ดรอบนี้ใช้ native config ผ่าน `Firebase.initializeApp()` ไม่ได้ import `firebase_options.dart` ที่ยังไม่มีอยู่ ให้ตรวจไฟล์ native และการตั้งค่า Google OAuth ตามด้านบนด้วย

## ตรวจรับก่อนส่งมอบ Login จริง

- เข้า Google ได้ และชื่อ/อีเมลตรงกับ Firebase Authentication Users
- ปิดแล้วเปิดแอปใหม่ยังเห็นบัญชีเดิม
- Cancel chooser ไม่มีข้อความผิดพลาด และกด Login ใหม่ได้
- เน็ตหลุดแสดงข้อผิดพลาดที่ลองใหม่ได้
- Logout และเปิดแอปใหม่เป็นสถานะยังไม่เข้าสู่ระบบ
- เปลี่ยนบัญชีแล้วชื่อ/อีเมลถูกต้อง แต่ยังแสดงคำอธิบายว่าข้อมูลการเงินเป็นข้อมูลของเครื่อง
- PIN และการใช้งานออฟไลน์ยังทำงานเหมือนเดิม
- ทดสอบ Light/Dark จอเล็กและขนาดข้อความใหญ่

ชุดทดสอบใน repository ใช้ AuthRepository จำลองเพื่อทดสอบ state และ UI ไม่ใช่หลักฐานว่า OAuth/native config ใช้งานได้จริง ต้องทดสอบบนอุปกรณ์หลังใส่การตั้งค่าจริง

เอกสาร: [Firebase Flutter Authentication](https://firebase.google.com/docs/auth/flutter/start), [Google Sign-In Android](https://pub.dev/packages/google_sign_in_android), [Google Sign-In iOS](https://pub.dev/packages/google_sign_in_ios)
