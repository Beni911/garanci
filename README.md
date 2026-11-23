# GaranciaŐr

Magyar nyelvű Flutter alkalmazás a garanciák és számlák helyi nyilvántartására. Androidra és iOS-re készül, a felület magyar nyelvű, és világos, sötét vagy rendszer szerinti témát használhat.

## Funkciók

- Garanciák offline mentése, keresése és kategória szerinti szűrése.
- Blokkfotó készítése vagy kiválasztása, majd kézi adatbevitel vagy Gemini-alapú adatkinyerés.
- Helyi emlékeztetők ütemezése 14 és 3 nappal a lejárat előtt.
- Számlaképek nagyítása és megosztása.
- JSON biztonsági mentés, valamint világos/sötét téma.

## Fejlesztői indítás

Telepítsd a Flutter stabil csatornáját, az Android Studio Android SDK-ját, illetve iOS buildhez macOS-en az Xcode-ot. A projekt Flutter 3.50.1 és Dart 3.14 vagy újabb verzióra van beállítva.

```bash
flutter pub get
flutter run
```

Android-emulátoron vagy USB-n csatlakoztatott eszközön:

```bash
flutter run -d <android-device-id>
```

iOS-szimulátoron vagy csatlakoztatott eszközön (macOS szükséges):

```bash
flutter run -d <ios-device-id>
```

## Gemini API-kulcs

A kulcs megadható az alkalmazás Beállítások képernyőjén; ilyenkor helyben, az alkalmazás SharedPreferences tárában mentődik. Alternatívaként build-időben is átadható:

```bash
flutter run --dart-define=GEMINI_API_KEY=SAJAT_API_KULCS
flutter build apk --release --dart-define=GEMINI_API_KEY=SAJAT_API_KULCS
```

A `.env.example` csak emlékeztető a változónévhez: a Flutter nem tölti be automatikusan a `.env` fájlokat. A `--dart-define` értéke a kliensalkalmazásból kinyerhető, ezért ne használj benne korlátlan vagy bizalmas kulcsot; állíts be Google Cloud/API-korlátokat. Az AI-beolvasás a felhasználó kérésére elküldi a kiválasztott blokk képét a Gemini API-nak.

## Helyi build

Android release APK:

```bash
flutter build apk --release
```

Aláíratlan iOS release build (macOS-en):

```bash
flutter build ios --release --no-codesign
```

Az iOS alkalmazás App Store-ba küldéséhez Apple fejlesztői fiók, tanúsítvány és aláírás szükséges.

## GitHub Actions

A `.github/workflows/build.yml` pushra és kézi indításra Android APK-t és iOS IPA artifactot készít. A workflow mindkettőt aláírás nélkül építi; az iOS artifact a `.app` csomag `Payload` mappába helyezett ZIP-je, nem App Store-ba közvetlenül feltölthető, aláírt csomag.

## Tesztek és statikus ellenőrzés

```bash
dart format lib test
flutter analyze
flutter test
```
