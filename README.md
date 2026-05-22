# LocalIStatsApp

## Overview / Genel Bakış

**LocalIStatsApp** is a macOS menu‑bar utility that shows real‑time system telemetry such as CPU load, memory usage, Disk SMART status, Wi‑Fi signal strength, and the top resource‑consuming processes. 

**LocalIStatsApp**, macOS menü çubuğundan CPU, bellek, disk SMART durumu, Wi‑Fi sinyali ve en çok kaynak tüketen süreçleri anlık izleyebileceğiniz bir uygulamadır.

---

## Requirements / Gereksinimler
- macOS 12.0 (Monterey) or newer / macOS 12.0 (Monterey) ya da daha yeni bir sürüm
- Xcode 15+ (Swift 5.9) – required for building from source / Xcode 15+ (Swift 5.9) – kaynak koddan derlemek için
- Git (to clone the repository) / Git (repo’yu klonlamak için)

---

## Installation Options / Kurulum Seçenekleri
### 1️⃣ Pre‑built .app package (simplest) – *En basit yöntem*
> **Note:** A release package will be added later. Until then, you can build the app yourself (see option 2).
> **Not:** Şu anda bir `Release` paketi yok; ileride GitHub Releases üzerinden ekleyeceğiz.

1. Download the `LocalIStatsApp.app.zip` from the **Releases** page on GitHub.
2. Unzip it and drag **LocalIStatsApp.app** into `/Applications`.
3. Open the app from Launchpad or Finder.
4. If macOS shows a security warning, go to **System Settings → Privacy & Security → General** and click “Open Anyway”.

### 2️⃣ Build from source (developers / advanced users) – *Geliştiriciler ve ileri kullanıcılar için*
#### Step 1 – Clone the repository / Repo’yu klonlayın
```bash
git clone https://github.com/gkhnlts/LocalIStatsApp.git
cd LocalIStatsApp
```
#### Step 2 – Open in Xcode / Xcode’da açın
```bash
open LocalIStatsApp.xcodeproj
```
Make sure the **LocalIStatsApp** scheme is selected.
#### Step 3 – Build and run / Derleyin ve çalıştırın
- Press **⌘ + B** to build.
- Press **⌘ + R** to launch. Xcode will place the app in the DerivedData folder and display the menu‑bar icon.
#### Step 4 – (Optional) Install to /Applications / /Applications’a taşıyın
```bash
# Find the built .app (example path)
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "LocalIStatsApp.app" | head -n 1)
# Copy (may require sudo)
sudo cp -R "$APP_PATH" /Applications/
```
Now you can start the app without Xcode.

---

## Usage / Kullanım
- Click the **I** icon in the menu bar.
- A pop‑over appears showing CPU, memory, disk SMART, Wi‑Fi RSSI, and the top 5 processes.
- Open **Settings** to adjust refresh interval and displayed units.

- Menü çubuğundaki **I** simgesine tıklayın.
- Açılan pop‑over’da CPU, bellek, disk SMART, Wi‑Fi RSSI ve en çok kaynak tüketen 5 süreç gösterilir.
- **Ayarlar** sekmesinden yenileme süresini ve birimleri özelleştirebilirsiniz.

---

## Troubleshooting / Sorun Giderme
- **“App is damaged and can’t be opened”** – Go to **System Settings → Privacy & Security → General** and click “Open Anyway”.
- **Disk SMART shows 0 / UNAVAILABLE** – `smartctl` works on Intel Macs; on Apple Silicon it may be limited.
- **Wi‑Fi RSSI not shown** – Ensure the app has permission to access Wi‑Fi information (macOS will prompt).

- **“Uygulama bozuk ve açılamıyor”** – **Sistem Ayarları → Gizlilik ve Güvenlik → Genel** sekmesinde “Yine de aç” seçeneğine tıklayın.
- **Disk SMART verisi 0 / UNAVAILABLE** – `smartctl` Intel‑tabanlı Mac’lerde çalışır; Apple Silicon’da sınırlı olabilir.
- **Wi‑Fi RSSI görüntülenmiyor** – Uygulamanın Wi‑Fi bilgisine erişim izni olduğundan emin olun (macOS izin penceresini onaylayın).

---

## Contributing / Katkıda Bulunma
1. Fork the repository.
2. Create a new branch (`git checkout -b feature‑name`).
3. Commit your changes and push (`git push origin feature‑name`).
4. Open a **Pull Request**.

1. Repo’yu fork edin.
2. Yeni bir branch oluşturun (`git checkout -b özellik‑adi`).
3. Değişiklikleri commit edin ve `git push origin özellik‑adi`.
4. Bir **Pull Request** açın.

---

## License / Lisans
This project is distributed under the **MIT License**. See the `LICENSE` file for details.

Bu proje **MIT Lisansı** altında dağıtılmaktadır. Ayrıntılar için `LICENSE` dosyasına bakın.

---

**Happy monitoring! / İyi izlemeler!**
