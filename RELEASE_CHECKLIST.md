# Android Release Checklist

## Current Release Settings

- App name: Reading
- Package ID: `com.brainrot.reading`
- Version: `1.0.0+1`
- Support email: `theluqmanmalik@gmail.com`
- Privacy policy draft: `PRIVACY_POLICY.md`

## Signing

Release signing is configured to use `android/key.properties` when that file exists. The file is ignored by Git and should not be committed.

Copy `android/key.properties.example` to `android/key.properties`, then replace the passwords and keystore path.

Recommended keystore path:

`C:\Users\Luqman Malik\Documents\keystores\reading-upload-keystore.jks`

Generate the upload keystore with your own secure passwords:

```powershell
keytool -genkeypair -v -keystore "C:\Users\Luqman Malik\Documents\keystores\reading-upload-keystore.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias reading-upload
```

Then build:

```powershell
C:\flutter\bin\flutter.bat build appbundle --release
```

## Remaining Before Play Upload

- Host the privacy policy and add its public URL to Play Console.
- Generate the upload keystore and fill `android/key.properties`.
- Build a signed `.aab`.
- Test the release build on a real Android device.
- Complete Play Console store listing, content rating, target audience, ads declaration, and Data safety form.
