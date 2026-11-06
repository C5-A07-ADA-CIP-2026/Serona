#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Adafruit_AS7341.h>
#include <Wire.h>

#define SERVICE_UUID "4FAFC201-1FB5-459E-8FCC-C5C9C331914B"
#define CHARACTERISTIC_UUID "BEA57604-1C34-45B5-927A-94943E992383"
#define I2C_SDA_PIN 6
#define I2C_SCL_PIN 7
#define AS7341_I2C_ADDRESS 0x39
// Arus LED onboard AS7341 (mA, 4-258, kelipatan 2). Naikkan bertahap kalau kurang
// terang di tempat tertutup; turunkan kalau board reset (brownout) atau pembacaan saturasi.
#define AS7341_LED_CURRENT_MA 20
// Integrasi per siklus = (ATIME + 1) * (ASTEP + 1) * 2,78 us, jadi 30 * 600 * 2,78 us ~ 50 ms.
// Satu pembacaan penuh memakai dua siklus (F1-F4, lalu F5-F8). Mengubah nilai ini atau gain
// mengubah skala visibleAverage, sehingga warna awal di aplikasi harus ditetapkan ulang.
<<<<<<< HEAD
#define AS7341_ATIME           29
#define AS7341_ASTEP           599
=======
#define AS7341_ATIME 29
#define AS7341_ASTEP 599
>>>>>>> 756a939 (fix: real-time sensor)
#define MEASUREMENT_INTERVAL_MS 200
// 0 = serial monitor hanya menampilkan satu baris "pH | Kepekatan" per pembacaan.
// 1 = tampilkan juga channel mentah, payload BLE, dan log debug pH.
#define SERIAL_DEBUG 0
// 1 = tampilkan rincian perhitungan kepekatan tiap pembacaan (channel mentah, rasio terhadap clear,
// baseline, transmitansi per channel). Ini hanya untuk debugging awal: kepekatan yang dipakai aplikasi
// dihitung di aplikasi dari channel mentah di payload BLE, dengan baseline dari tombol "tetapkan warna awal".
#define SERIAL_DETAIL 1
// 1 = tampilkan byte balasan sensor pH (sekali per detik) untuk mencari kenapa pH tidak terbaca.
#define PH_DEBUG 1

// Sensor pH RS485 Modbus RTU lewat modul TTL-RS485 (default pabrik SN-*-PH-N01:
// 4800 baud 8N1, alamat 1, register 0x0000 = pH x100).
#define PH_RX_PIN 20  // modul TXD -> GPIO20
#define PH_TX_PIN 21  // modul RXD <- GPIO21
#define PH_BAUD_RATE 4800
#define PH_SLAVE_ADDRESS 1
#define PH_REGISTER 0x0000
#define PH_SCALE 100.0f
#define PH_POLL_INTERVAL_MS 1000
#define PH_MAX_AGE_MS 3000
#define PH_RESPONSE_TIMEOUT_MS 150

BLEServer *pServer = NULL;
BLECharacteristic *pCharacteristic = NULL;
Adafruit_AS7341 as7341;
bool deviceConnected = false;
bool oldDeviceConnected = false;
bool sensorReady = false;
unsigned long lastMeasurementAt = 0;
float lastPh = 0;
bool phKnown = false;
unsigned long lastPhAt = 0;
unsigned long lastPhPollAt = 0;
// Pembanding kepekatan di serial monitor (hanya untuk debugging; aplikasi menghitung sendiri).
// Baseline TIDAK diambil otomatis: kirim karakter apa saja lewat serial monitor saat warna awal sudah
// siap (sama seperti menekan "tetapkan warna awal" di aplikasi). Sebelum itu kepekatan tampil "--".
// baselineRatio = rasio F_n / clear tiap channel F1..F8 pada saat itu.
<<<<<<< HEAD
float baselineRatio[8] = {0};
=======
float baselineRatio[8] = { 0 };
>>>>>>> 756a939 (fix: real-time sensor)
bool baselineRatioReady = false;
bool baselineRequested = false;

// callback otomatis fungsi terjadi
<<<<<<< HEAD
class ServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        deviceConnected = true;
        Serial.println(">> iPhone Terhubung!");
    }
    void onDisconnect(BLEServer* pServer) {
        deviceConnected = false;
        Serial.println(">> iPhone Terputus!");
    }
=======
class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    deviceConnected = true;
    Serial.println(">> iPhone Terhubung!");
  }
  void onDisconnect(BLEServer *pServer) {
    deviceConnected = false;
    Serial.println(">> iPhone Terputus!");
  }
>>>>>>> 756a939 (fix: real-time sensor)
};

// untuk menghitung CRC. crc adalah data berisi byte, length adalah panjang data
uint16_t modbusCrc(const uint8_t *data, size_t length) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < length; i++) {
    crc ^= data[i];
    for (uint8_t bit = 0; bit < 8; bit++) {
      crc = (crc & 1) ? (crc >> 1) ^ 0xA001 : crc >> 1;
    }
  }
  return crc;
}

// Baca pH lewat Modbus fungsi 0x03 (pH dan suhu). Mengembalikan false kalau gagal
// atau nilai di luar 0-14, supaya aplikasi tidak menerima angka palsu.
bool readPh(float *ph) {
  uint8_t request[8] = {
    PH_SLAVE_ADDRESS, 0x03, PH_REGISTER >> 8, PH_REGISTER & 0xFF, 0x00, 0x02, 0, 0
  };
  uint16_t requestCrc = modbusCrc(request, 6);
  request[6] = requestCrc & 0xFF;
  request[7] = requestCrc >> 8;

  while (Serial1.available()) {
    Serial1.read();
  }
  Serial1.write(request, sizeof(request));
  Serial1.flush();

  uint8_t response[9];
  size_t received = 0;
  unsigned long startedAt = millis();
  while (received < sizeof(response) && millis() - startedAt < PH_RESPONSE_TIMEOUT_MS) {
    while (Serial1.available() && received < sizeof(response)) {
      response[received++] = Serial1.read();
    }
<<<<<<< HEAD
    if (received < sizeof(response)) {
#if PH_DEBUG
        Serial.printf("pH debug: hanya %u dari %u byte masuk:", (unsigned)received, (unsigned)sizeof(response));
        for (size_t i = 0; i < received; i++) {
            Serial.printf(" %02X", response[i]);
        }
        Serial.println();
#endif
        return false;
=======
    delay(1);
  }
  if (received < sizeof(response)) {
#if PH_DEBUG
    Serial.printf("pH debug: hanya %u dari %u byte masuk:", (unsigned)received, (unsigned)sizeof(response));
    for (size_t i = 0; i < received; i++) {
      Serial.printf(" %02X", response[i]);
>>>>>>> 756a939 (fix: real-time sensor)
    }
    Serial.println();
#endif
    return false;
  }

<<<<<<< HEAD
    uint16_t expectedCrc = modbusCrc(response, 7);
    uint16_t receivedCrc = response[7] | (response[8] << 8);
    if (expectedCrc != receivedCrc || response[0] != PH_SLAVE_ADDRESS
        || response[1] != 0x03 || response[2] != 4) {
#if PH_DEBUG
        Serial.print("pH debug: balasan salah (CRC/alamat/fungsi):");
        for (size_t i = 0; i < sizeof(response); i++) {
            Serial.printf(" %02X", response[i]);
        }
        Serial.println();
#endif
        return false;
=======
  uint16_t expectedCrc = modbusCrc(response, 7);
  uint16_t receivedCrc = response[7] | (response[8] << 8);
  if (expectedCrc != receivedCrc || response[0] != PH_SLAVE_ADDRESS
      || response[1] != 0x03 || response[2] != 4) {
#if PH_DEBUG
    Serial.print("pH debug: balasan salah (CRC/alamat/fungsi):");
    for (size_t i = 0; i < sizeof(response); i++) {
      Serial.printf(" %02X", response[i]);
>>>>>>> 756a939 (fix: real-time sensor)
    }
    Serial.println();
#endif
    return false;
  }

  float value = ((response[3] << 8) | response[4]) / PH_SCALE;
  if (value < 0.0f || value > 14.0f) {
    return false;
  }
  *ph = value;
  return true;
}

void updatePh() {
<<<<<<< HEAD
    float ph;
    if (readPh(&ph)) {
        lastPh = ph;
        lastPhAt = millis();
        phKnown = true;
#if SERIAL_DEBUG
        Serial.printf("pH sensor: %.2f\n", ph);
    } else {
        Serial.println("pH sensor: tidak ada jawaban atau nilai tidak valid.");
#endif
    }
=======
  float ph;
  if (readPh(&ph)) {
    lastPh = ph;
    lastPhAt = millis();
    phKnown = true;
#if SERIAL_DEBUG
    Serial.printf("pH sensor: %.2f\n", ph);
  } else {
    Serial.println("pH sensor: tidak ada jawaban atau nilai tidak valid.");
#endif
  }
>>>>>>> 756a939 (fix: real-time sensor)
}

bool phIsFresh() {
  return phKnown && millis() - lastPhAt <= PH_MAX_AGE_MS;
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial1.begin(PH_BAUD_RATE, SERIAL_8N1, PH_RX_PIN, PH_TX_PIN);
  Serial.printf(
    "Sensor pH RS485 dimulai: RX=GPIO%d, TX=GPIO%d, %d baud, alamat %d\n",
    PH_RX_PIN, PH_TX_PIN, PH_BAUD_RATE, PH_SLAVE_ADDRESS);

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  Serial.printf(
    "I2C dimulai: SDA=GPIO%d, SCL=GPIO%d\n",
    I2C_SDA_PIN,
    I2C_SCL_PIN);
  scanI2C();

<<<<<<< HEAD
    sensorReady = as7341.begin(AS7341_I2C_ADDRESS, &Wire);
    if (sensorReady) {
        Serial.println("AS7341 siap di alamat I2C 0x39.");

        as7341.setATIME(AS7341_ATIME);
        as7341.setASTEP(AS7341_ASTEP);
        as7341.setGain(AS7341_GAIN_64X);
        as7341.setLEDCurrent(AS7341_LED_CURRENT_MA);
        as7341.enableLED(true);
        Serial.printf("LED AS7341 dinyalakan (%d mA).\n", AS7341_LED_CURRENT_MA);
    } else {
        Serial.println(
            "AS7341 tidak ditemukan di 0x39. Periksa power, GND, SDA, SCL, "
            "atau alamat breakout."
        );
    }
=======
  sensorReady = as7341.begin(AS7341_I2C_ADDRESS, &Wire);
  if (sensorReady) {
    Serial.println("AS7341 siap di alamat I2C 0x39.");
>>>>>>> 756a939 (fix: real-time sensor)

    as7341.setATIME(AS7341_ATIME);
    as7341.setASTEP(AS7341_ASTEP);
    as7341.setGain(AS7341_GAIN_64X);
    as7341.setLEDCurrent(AS7341_LED_CURRENT_MA);
    as7341.enableLED(true);
    Serial.printf("LED AS7341 dinyalakan (%d mA).\n", AS7341_LED_CURRENT_MA);
  } else {
    Serial.println(
      "AS7341 tidak ditemukan di 0x39. Periksa power, GND, SDA, SCL, "
      "atau alamat breakout.");
  }

  // 1. Generate nama unik otomatis dari MAC Address chip ESP32 kamu
  uint64_t chipId = ESP.getEfuseMac();
  char uniqueDeviceName[32];
  snprintf(uniqueDeviceName, sizeof(uniqueDeviceName), "Serona-%04X%04X",
           (uint16_t)(chipId >> 16), (uint16_t)chipId);

  Serial.print("Nama BLE: ");
  Serial.println(uniqueDeviceName);

  // // 2. Set nama perangkat ke nama unik Serona
  // BLEDevice::init(uniqueDeviceName);

  // // 3. Buat BLE Server
  // pServer = BLEDevice::createServer();
  // pServer->setCallbacks(new ServerCallbacks());

  // // 4. Buat Service & Characteristic
  // BLEService *pService = pServer->createService(SERVICE_UUID);
  // pCharacteristic = pService->createCharacteristic(
  //     CHARACTERISTIC_UUID,
  //     BLECharacteristic::PROPERTY_READ |
  //     BLECharacteristic::PROPERTY_WRITE |
  //     BLECharacteristic::PROPERTY_NOTIFY
  // );
  // pCharacteristic->addDescriptor(new BLE2902());
  // pCharacteristic->setValue("{\"visibleAverage\":0,\"clear\":0,\"nir\":0}");
  // pService->start();

  // if (sensorReady) {
  //     updateMeasurement();
  //     lastMeasurementAt = millis();
  // }

  // // 5. Broadcast Service
  // BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  // pAdvertising->addServiceUUID(SERVICE_UUID);
  // pAdvertising->setScanResponse(true);
  // BLEDevice::startAdvertising();

  BLEDevice::init(uniqueDeviceName);               // 1. Inisialisasi device dulu
  BLEServer *pServer = BLEDevice::createServer();  // 2. Buat server
  pServer->setCallbacks(new ServerCallbacks());    // 3. Set callback server

  BLEService *pService = pServer->createService(SERVICE_UUID);  // 4. Buat service
  pCharacteristic = pService->createCharacteristic(             // 5. Buat characteristic
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);

  pCharacteristic->addDescriptor(new BLE2902());  // 6. Tambah descriptor notify
  pService->start();                              // 7. Start service

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  BLEDevice::startAdvertising();  // 8. Start advertising

  Serial.println("Menunggu koneksi dari aplikasi Serona...");
}

void loop() {
<<<<<<< HEAD
    if (Serial.available()) {
        while (Serial.available()) {
            Serial.read();
        }
        baselineRequested = true;
    }

    if (millis() - lastPhPollAt >= PH_POLL_INTERVAL_MS) {
        lastPhPollAt = millis();
        updatePh();
=======
  if (Serial.available()) {
    while (Serial.available()) {
      Serial.read();
>>>>>>> 756a939 (fix: real-time sensor)
    }
    baselineRequested = true;
  }

<<<<<<< HEAD
    if (sensorReady && millis() - lastMeasurementAt >= MEASUREMENT_INTERVAL_MS) {
        updateMeasurement();
        lastMeasurementAt = millis();
    }
=======
  if (millis() - lastPhPollAt >= PH_POLL_INTERVAL_MS) {
    lastPhPollAt = millis();
    updatePh();
  }
>>>>>>> 756a939 (fix: real-time sensor)

  if (sensorReady && millis() - lastMeasurementAt >= MEASUREMENT_INTERVAL_MS) {
    updateMeasurement();
    lastMeasurementAt = millis();
  }

  if (!deviceConnected && oldDeviceConnected) {
    delay(500);
    pServer->startAdvertising();
    oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
    oldDeviceConnected = deviceConnected;
  }
}

void scanI2C() {
  uint8_t deviceCount = 0;

  Serial.println("Memindai perangkat I2C...");
  for (uint8_t address = 1; address < 127; address++) {
    Wire.beginTransmission(address);
    uint8_t error = Wire.endTransmission();
    if (error != 0) {
      continue;
    }

    Serial.printf("Perangkat I2C ditemukan: 0x%02X", address);
    if (address == AS7341_I2C_ADDRESS) {
      Serial.println(" (alamat AS7341)");
    } else {
      Serial.println();
    }
    deviceCount++;
  }

  if (deviceCount == 0) {
    Serial.println("Tidak ada perangkat I2C ditemukan.");
  }
}

void updateMeasurement() {
  uint16_t readings[12];
  if (!as7341.readAllChannels(readings)) {
    Serial.println("Gagal membaca AS7341.");
    return;
  }

  // readAllChannels order: F1, F2, F3, F4, Clear, NIR, F5, F6, F7, F8, Clear, NIR.
  const uint8_t visibleIndexes[] = { 0, 1, 2, 3, 6, 7, 8, 9 };
  uint32_t visibleTotal = 0;
  for (uint8_t index : visibleIndexes) {
    visibleTotal += readings[index];
  }

<<<<<<< HEAD
    float visibleAverage = visibleTotal / 8.0f;

    // F1-F4 dinormalisasi dengan clear siklus pertama (indeks 4), F5-F8 dengan clear siklus kedua (10).
    float ratios[8];
    bool clearValid = readings[4] > 0 && readings[10] > 0;
    for (uint8_t i = 0; i < 8; i++) {
        float clearValue = i < 4 ? readings[4] : readings[10];
        ratios[i] = clearValue > 0 ? readings[visibleIndexes[i]] / clearValue : 0.0f;
    }
    if (baselineRequested && clearValid) {
        for (uint8_t i = 0; i < 8; i++) {
            baselineRatio[i] = ratios[i];
        }
        baselineRatioReady = true;
        baselineRequested = false;
        Serial.println(">> Baseline ditetapkan dari pembacaan ini (100%).");
    }
    // Transmitansi tiap channel = rasio sekarang / rasio blanko; channel terkecil paling terserap.
    float concentration = 0.0f;
    uint8_t dominantChannel = 0;
    float transmittances[8] = {0};
    if (baselineRatioReady && clearValid) {
        float lowest = 1e9f;
        for (uint8_t i = 0; i < 8; i++) {
            if (baselineRatio[i] <= 0) {
                continue;
            }
            float transmittance = ratios[i] / baselineRatio[i];
            transmittances[i] = transmittance;
            if (transmittance < lowest) {
                lowest = transmittance;
                dominantChannel = i;
            }
        }
        concentration = lowest < 1e9f ? lowest * 100.0f : 0.0f;
    }
    // Channel mentah dikirim apa adanya; aplikasi yang menghitung kepekatan (channel / clear terhadap baseline).
    // "clear" = clear siklus F5-F8, "clear1" = clear siklus F1-F4.
    String payload = "{\"visibleAverage\":" + String(visibleAverage, 1)
        + ",\"clear\":" + String(readings[10])
        + ",\"clear1\":" + String(readings[4])
        + ",\"nir\":" + String(readings[11])
        + ",\"channels\":[";
    for (uint8_t i = 0; i < 8; i++) {
        payload += String(readings[visibleIndexes[i]]);
        payload += i < 7 ? "," : "]";
    }
    if (phIsFresh()) {
        payload += ",\"ph\":" + String(lastPh, 2);
    }
    payload += "}";

#if SERIAL_DETAIL
    Serial.println("---------------------------------------------");
    Serial.printf("raw   F1..F8 : %u %u %u %u %u %u %u %u\n",
        readings[0], readings[1], readings[2], readings[3],
        readings[6], readings[7], readings[8], readings[9]);
    Serial.printf("clear (F1-4 / F5-8) : %u / %u | nir : %u / %u\n",
        readings[4], readings[10], readings[5], readings[11]);
    Serial.printf("visibleAverage      : %.1f\n", visibleAverage);
    Serial.printf("rasio F/clear       : %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f\n",
        ratios[0], ratios[1], ratios[2], ratios[3], ratios[4], ratios[5], ratios[6], ratios[7]);
    if (baselineRatioReady) {
        Serial.printf("baseline            : %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f\n",
            baselineRatio[0], baselineRatio[1], baselineRatio[2], baselineRatio[3],
            baselineRatio[4], baselineRatio[5], baselineRatio[6], baselineRatio[7]);
        Serial.printf("transmitansi %%      : %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f\n",
            transmittances[0] * 100.0f, transmittances[1] * 100.0f, transmittances[2] * 100.0f,
            transmittances[3] * 100.0f, transmittances[4] * 100.0f, transmittances[5] * 100.0f,
            transmittances[6] * 100.0f, transmittances[7] * 100.0f);
        Serial.printf("channel terserap    : F%u (terendah)\n", dominantChannel + 1);
    } else {
        Serial.println("baseline            : belum ditetapkan (kirim karakter apa saja lewat serial)");
    }
#endif
    if (phIsFresh()) {
        if (baselineRatioReady) {
            Serial.printf("pH: %.2f | Kepekatan: %.1f%% (F%u)\n", lastPh, concentration, dominantChannel + 1);
        } else {
            Serial.printf("pH: %.2f | Kepekatan: --\n", lastPh);
        }
    } else {
        if (baselineRatioReady) {
            Serial.printf("pH: -- | Kepekatan: %.1f%% (F%u)\n", concentration, dominantChannel + 1);
        } else {
            Serial.println("pH: -- | Kepekatan: --");
        }
    }

#if SERIAL_DEBUG
    Serial.printf(
        "AS7341 raw F1..F8: %u, %u, %u, %u, %u, %u, %u, %u | clear=%u nir=%u | visibleAverage=%.1f\n",
        readings[0], readings[1], readings[2], readings[3],
        readings[6], readings[7], readings[8], readings[9],
        readings[10], readings[11], visibleAverage
    );
    Serial.print("BLE payload: ");
    Serial.println(payload);
#endif

    pCharacteristic->setValue(payload.c_str());
    if (deviceConnected) {
        pCharacteristic->notify();
=======
  float visibleAverage = visibleTotal / 8.0f;

  // F1-F4 dinormalisasi dengan clear siklus pertama (indeks 4), F5-F8 dengan clear siklus kedua (10).
  float ratios[8];
  bool clearValid = readings[4] > 0 && readings[10] > 0;
  for (uint8_t i = 0; i < 8; i++) {
    float clearValue = i < 4 ? readings[4] : readings[10];
    ratios[i] = clearValue > 0 ? readings[visibleIndexes[i]] / clearValue : 0.0f;
  }
  if (baselineRequested && clearValid) {
    for (uint8_t i = 0; i < 8; i++) {
      baselineRatio[i] = ratios[i];
>>>>>>> 756a939 (fix: real-time sensor)
    }
    baselineRatioReady = true;
    baselineRequested = false;
    Serial.println(">> Baseline ditetapkan dari pembacaan ini (100%).");
  }
  // Transmitansi tiap channel = rasio sekarang / rasio blanko; channel terkecil paling terserap.
  float concentration = 0.0f;
  uint8_t dominantChannel = 0;
  float transmittances[8] = { 0 };
  if (baselineRatioReady && clearValid) {
    float lowest = 1e9f;
    for (uint8_t i = 0; i < 8; i++) {
      if (baselineRatio[i] <= 0) {
        continue;
      }
      float transmittance = ratios[i] / baselineRatio[i];
      transmittances[i] = transmittance;
      if (transmittance < lowest) {
        lowest = transmittance;
        dominantChannel = i;
      }
    }
    concentration = lowest < 1e9f ? lowest * 100.0f : 0.0f;
  }
  // Channel mentah dikirim apa adanya; aplikasi yang menghitung kepekatan (channel / clear terhadap baseline).
  // "clear" = clear siklus F5-F8, "clear1" = clear siklus F1-F4.
  String payload = "{\"visibleAverage\":" + String(visibleAverage, 1)
                   + ",\"clear\":" + String(readings[10])
                   + ",\"clear1\":" + String(readings[4])
                   + ",\"nir\":" + String(readings[11])
                   + ",\"channels\":[";
  for (uint8_t i = 0; i < 8; i++) {
    payload += String(readings[visibleIndexes[i]]);
    payload += i < 7 ? "," : "]";
  }
  if (phIsFresh()) {
    payload += ",\"ph\":" + String(lastPh, 2);
  }
  payload += "}";

#if SERIAL_DETAIL
  Serial.println("---------------------------------------------");
  Serial.printf("raw   F1..F8 : %u %u %u %u %u %u %u %u\n",
                readings[0], readings[1], readings[2], readings[3],
                readings[6], readings[7], readings[8], readings[9]);
  Serial.printf("clear (F1-4 / F5-8) : %u / %u | nir : %u / %u\n",
                readings[4], readings[10], readings[5], readings[11]);
  Serial.printf("visibleAverage      : %.1f\n", visibleAverage);
  Serial.printf("rasio F/clear       : %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f\n",
                ratios[0], ratios[1], ratios[2], ratios[3], ratios[4], ratios[5], ratios[6], ratios[7]);
  if (baselineRatioReady) {
    Serial.printf("baseline            : %.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f\n",
                  baselineRatio[0], baselineRatio[1], baselineRatio[2], baselineRatio[3],
                  baselineRatio[4], baselineRatio[5], baselineRatio[6], baselineRatio[7]);
    Serial.printf("transmitansi %%      : %.1f %.1f %.1f %.1f %.1f %.1f %.1f %.1f\n",
                  transmittances[0] * 100.0f, transmittances[1] * 100.0f, transmittances[2] * 100.0f,
                  transmittances[3] * 100.0f, transmittances[4] * 100.0f, transmittances[5] * 100.0f,
                  transmittances[6] * 100.0f, transmittances[7] * 100.0f);
    Serial.printf("channel terserap    : F%u (terendah)\n", dominantChannel + 1);
  } else {
    Serial.println("baseline            : belum ditetapkan (kirim karakter apa saja lewat serial)");
  }
#endif
  if (phIsFresh()) {
    if (baselineRatioReady) {
      Serial.printf("pH: %.2f | Kepekatan: %.1f%% (F%u)\n", lastPh, concentration, dominantChannel + 1);
    } else {
      Serial.printf("pH: %.2f | Kepekatan: --\n", lastPh);
    }
  } else {
    if (baselineRatioReady) {
      Serial.printf("pH: -- | Kepekatan: %.1f%% (F%u)\n", concentration, dominantChannel + 1);
    } else {
      Serial.println("pH: -- | Kepekatan: --");
    }
  }

#if SERIAL_DEBUG
  Serial.printf(
    "AS7341 raw F1..F8: %u, %u, %u, %u, %u, %u, %u, %u | clear=%u nir=%u | visibleAverage=%.1f\n",
    readings[0], readings[1], readings[2], readings[3],
    readings[6], readings[7], readings[8], readings[9],
    readings[10], readings[11], visibleAverage);
  Serial.print("BLE payload: ");
  Serial.println(payload);
#endif

  pCharacteristic->setValue(payload.c_str());
  if (deviceConnected) {
    pCharacteristic->notify();
  }
}