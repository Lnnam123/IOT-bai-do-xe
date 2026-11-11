import fs from 'fs';
import path from 'path';

try {
  // 1. Doc phien ban tu pubspec.yaml
  const pubspecPath = path.resolve('app', 'pubspec.yaml');
  const pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
  const match = pubspecContent.match(/version:\s*([0-9]+\.[0-9]+)/);
  const version = match ? match[1] : '1.0';
  const targetApkName = `baidoxe_V${version}.apk`;

  // 2. Thu muc chua file build apk
  const dirs = [
    path.resolve('app', 'build', 'app', 'outputs', 'flutter-apk'),
    path.resolve('app', 'build', 'app', 'outputs', 'apk', 'release')
  ];

  let found = false;
  for (const d of dirs) {
    if (fs.existsSync(d)) {
      const src = path.join(d, 'app-release.apk');
      if (fs.existsSync(src)) {
        const dest = path.join(d, targetApkName);
        fs.copyFileSync(src, dest);
        console.log(`\n🎉 [XUẤT APK THÀNH CÔNG] Đã tạo file: ${dest}`);
        found = true;
      }
    }
  }

  if (!found) {
    console.log(`\n[LƯU Ý] Không tìm thấy file app-release.apk để đổi tên sang ${targetApkName}.`);
  }
} catch (e) {
  console.error('Lỗi khi đổi tên APK:', e.message);
}

