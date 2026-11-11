import fs from 'fs';
import path from 'path';
import { execSync } from 'child_process';

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

  const keystorePath = path.join(rootDir, 'app', 'android', 'app', 'key.jks');
  const apksignerPath = 'E:\\Android_SDK\\build-tools\\36.0.0\\apksigner.bat';

  let found = false;
  for (const d of dirs) {
    if (fs.existsSync(d)) {
      const targetPath = path.join(d, targetApkName);
      const src = path.join(d, 'app-release.apk');
      if (fs.existsSync(src)) {
        fs.copyFileSync(src, targetPath);
      }

      if (fs.existsSync(targetPath)) {
        // Tu dong ky so V1 (JAR) + V2 + V3 de moi dong Android deu cai duoc
        if (fs.existsSync(keystorePath) && fs.existsSync(apksignerPath)) {
          try {
            execSync(`"${apksignerPath}" sign --ks "${keystorePath}" --ks-pass "pass:baidoxe123" --ks-key-alias baidoxe --key-pass "pass:baidoxe123" --min-sdk-version 21 --v1-signing-enabled true --v2-signing-enabled true "${targetPath}"`, { stdio: 'ignore' });
          } catch (_) {}
        }

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
