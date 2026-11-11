import fs from 'fs';
import path from 'path';

try {
  // 1. Tim file pubspec.yaml du chay tu thu muc goc hay thu muc app
  const pubspecPath = fs.existsSync('pubspec.yaml')
    ? path.resolve('pubspec.yaml')
    : path.resolve('app', 'pubspec.yaml');

  if (!fs.existsSync(pubspecPath)) {
    process.exit(0);
  }

  const pubspecContent = fs.readFileSync(pubspecPath, 'utf8');
  const match = pubspecContent.match(/version:\s*([0-9]+\.[0-9]+)/);
  const version = match ? match[1] : '1.0';
  const targetApkName = `baidoxe_V${version}.apk`;

  // 2. Xac dinh thu muc build
  const rootDir = fs.existsSync('pubspec.yaml') ? path.resolve('..') : path.resolve('.');
  const dirs = [
    path.join(rootDir, 'app', 'build', 'app', 'outputs', 'flutter-apk'),
    path.join(rootDir, 'app', 'build', 'app', 'outputs', 'apk', 'release')
  ];

  let found = false;
  for (const d of dirs) {
    if (fs.existsSync(d)) {
      const targetPath = path.join(d, targetApkName);
      if (fs.existsSync(targetPath)) {
        console.log(`\n==================================================`);
        console.log(`🎉 [XUẤT APK THÀNH CÔNG] File cài đặt: ${targetPath}`);
        console.log(`==================================================`);
        found = true;
        continue;
      }
      const src = path.join(d, 'app-release.apk');
      if (fs.existsSync(src)) {
        fs.copyFileSync(src, targetPath);
        console.log(`\n==================================================`);
        console.log(`🎉 [XUẤT APK THÀNH CÔNG] File cài đặt: ${targetPath}`);
        console.log(`==================================================`);
        found = true;
      }
    }
  }
} catch (e) {
  // Bo qua loi khong can thiet
}
