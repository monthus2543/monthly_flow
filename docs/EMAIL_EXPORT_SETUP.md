# ส่งรายงาน Excel ไปอีเมลของบัญชี

สถานะ: เตรียมโค้ดแอปและ Cloud Function แล้ว ยังไม่ได้เผยแพร่ Function หรือตั้งค่า SMTP
จึงยังส่งอีเมลจริงไม่ได้ เมื่อบริการยังไม่พร้อม แอปจะแสดงข้อผิดพลาดและยังบันทึกไฟล์ลงเครื่องได้

## วิธีใช้

- ไม่ Login: ปลายทางมีเฉพาะ **ในอุปกรณ์** กดสร้างไฟล์แล้วเลือกตำแหน่งบันทึก
- Login: เมื่อกด **สร้างไฟล์ Excel** จะถามปลายทาง **บันทึกลงอุปกรณ์** หรือ **ส่งไปอีเมลที่ Login** พร้อมแสดงอีเมลบัญชี ไม่แสดงตัวเลือกปลายทางบนหน้าฟอร์ม
- ส่งอีเมล: สร้างไฟล์และส่งไฟล์แนบอัตโนมัติ ไม่เปิดแอปอีเมล และไม่ต้องให้สิทธิ์ Gmail/Drive
- ผู้รับตรวจจาก Firebase Authentication ฝั่งเซิร์ฟเวอร์ ต้องมีอีเมลที่ยืนยันแล้ว
  ไม่รับอีเมลผู้รับจากแอปหรือจากชื่อโปรไฟล์ที่แก้ไขเอง
- แนบ `.xlsx` ได้สูงสุด 5 MB หากใหญ่กว่านี้ให้เลือกปีน้อยลงหรือบันทึกลงอุปกรณ์

## สิ่งที่ต้องตั้งค่า

มีตัวช่วยตั้งค่าบนเครื่อง ให้กรอก Host/Username/From และรหัส SMTP แบบซ่อนค่า:

```powershell
cd D:\Code\monthly_flow
pwsh -File .\tools\setup_report_email.ps1 -SmtpPort 587
```

ตัวช่วยจะ Login Firebase ตรวจ SMTP โดยยังไม่ส่งอีเมล เก็บค่าผ่าน stdin ไป Secret Manager
แล้วทดสอบและเผยแพร่ Function ตามขั้นตอนด้านล่าง ไม่สร้างไฟล์รหัสผ่านและไม่เปิด billing ให้เอง

1. Firebase project `monthly-flow-75287` ต้องรองรับ Cloud Functions (แผน Blaze)
2. เลือกบริการ SMTP สำหรับบัญชีผู้ส่งของ Monthly Flow
   ตัวอย่างเช่นบริการ Transactional Email หรือบัญชี SMTP ที่คุณมี
   อีเมลผู้ส่งนี้เป็นของแอป ไม่ใช่บัญชีผู้ใช้ที่ Login
3. ยืนยันอีเมล/โดเมนผู้ส่งกับผู้ให้บริการ และตั้งค่า SPF/DKIM ตามคู่มือของผู้ให้บริการ
4. ใช้ Node.js 22 และ Firebase CLI เตรียมแพ็กเกจในโฟลเดอร์ `functions`:

```powershell
cd D:\Code\monthly_flow\functions
npm ci
npm test
```

5. ตั้ง Secret Manager โดยไม่ใส่รหัสผ่านใน Dart, Git หรือไฟล์ตั้งค่าที่ commit:

```powershell
firebase functions:secrets:set REPORT_SMTP_CONFIG --project monthly-flow-75287
```

เมื่อ CLI ขอค่า secret ให้ใส่ JSON ตามตัวอย่าง โดยแทนค่าจริงของผู้ให้บริการ:

```json
{"host":"smtp.example.com","port":587,"user":"SMTP_USERNAME","password":"SMTP_PASSWORD","from":"reports@your-domain.com"}
```

รองรับพอร์ต 587 พร้อม STARTTLS หรือ 465 พร้อม TLS
อย่าส่งรหัสผ่าน SMTP ในแชต และอย่า commit ค่า secret

6. เผยแพร่เฉพาะ Function ของรายงาน จากรากโปรเจกต์:

```powershell
cd D:\Code\monthly_flow
firebase deploy --only functions:report-email --project monthly-flow-75287
```

Function ชื่อ `emailExcelReport` อยู่ region `us-central1` ตรงกับโค้ด Flutter
การเปลี่ยน secret ของ Function ที่เผยแพร่แล้วต้องเผยแพร่ Function ใหม่
ไม่ต้องเปิด Drive API และไม่ต้องติดตั้ง Trigger Email extension สำหรับโค้ดชุดนี้

## การส่งซ้ำและความผิดพลาด

- ใช้ hash ของชื่อไฟล์และเนื้อหาไฟล์เป็นรหัสคำขอ แยกตาม UID
- ผลสำเร็จเดิมจะตอบกลับว่าส่งแล้ว โดยไม่ส่งอีเมลซ้ำ
- หาก SMTP ปฏิเสธแน่นอน ให้ลองคำขอเดิมใหม่ได้
- หากการเชื่อมต่อขาดระหว่างส่ง อาจส่งสำเร็จแล้ว จึงล็อกสถานะเป็น `uncertain`
  ไม่ส่งซ้ำอัตโนมัติ ผู้ดูแลต้องตรวจ log ของผู้ให้บริการก่อนแก้สถานะ
- จำกัด 20 คำขอต่อ UID ต่อวัน UTC และห่างกันอย่างน้อย 60 วินาที
- Firestore ใช้ `reportEmailJobs/{uid}/reports/{requestId}` และ `reportEmailLimits/{uid}`
  กฎเดิมไม่เปิดสิทธิ์ collection เหล่านี้แก่แอป เซิร์ฟเวอร์เป็นผู้จัดการเท่านั้น
- ไม่เก็บเนื้อหาไฟล์หรือรหัส SMTP ลง Firestore และไม่บันทึกข้อมูลใบเสร็จหรือ PIN ในไฟล์
- ผล `sent` หมายถึง SMTP ยอมรับอีเมลแล้ว การถึงกล่อง Inbox ต้องตรวจกับผู้ให้บริการ
  และควรตรวจ Spam ด้วย

## ทดสอบจริงหลังตั้งค่า

รันแอปใหม่เพราะเพิ่ม native dependency `cloud_functions`
ทดสอบทั้งไม่ Login, Login บันทึกในเครื่อง, Login ส่งอีเมล, ยกเลิกบันทึก,
เน็ตหลุด, ออกจากระบบระหว่างส่ง และลองไฟล์เดิมซ้ำ
ตรวจผู้รับตรงกับบัญชี Login และเปิดไฟล์แนบเพื่อตรวจชีต/ยอด/วันที่/กราฟ

อ้างอิง: [Firebase callable functions](https://firebase.google.com/docs/functions/callable),
[Firebase secrets](https://firebase.google.com/docs/functions/config-env),
[Nodemailer](https://nodemailer.com/usage/)
