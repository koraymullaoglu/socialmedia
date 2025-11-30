# 🌐 Social Media Project

Flask ve PostgreSQL tabanlı bir sosyal medya uygulaması backend projesi.

---

## 📁 Proje Yapısı

```
SocialMediaProject/
├── backend/                    # Flask Backend Uygulaması
│   ├── api/
│   │   ├── controllers/        # API endpoint'leri (route tanımlamaları)
│   │   │   ├── api.py          # Ana blueprint - tüm controller'ları birleştirir
│   │   │   ├── user_controller.py
│   │   │   ├── post_controller.py
│   │   │   ├── comment_controller.py
│   │   │   ├── community_controller.py
│   │   │   ├── follow_controller.py
│   │   │   └── message_controller.py
│   │   │
│   │   ├── services/           # İş mantığı katmanı
│   │   │   ├── auth_service.py
│   │   │   ├── user_service.py
│   │   │   ├── post_service.py
│   │   │   ├── comment_service.py
│   │   │   ├── community_service.py
│   │   │   ├── follow_service.py
│   │   │   └── message_service.py
│   │   │
│   │   ├── repositories/       # Veritabanı işlemleri (CRUD)
│   │   │   ├── user_repository.py
│   │   │   ├── post_repository.py
│   │   │   ├── comment_repository.py
│   │   │   ├── community_repository.py
│   │   │   ├── follow_repository.py
│   │   │   └── message_repository.py
│   │   │
│   │   ├── entities/           # SQLAlchemy Model tanımlamaları
│   │   │   └── entities.py
│   │   │
│   │   ├── middleware/         # Ara yazılımlar
│   │   │   ├── jwt.py          # JWT token doğrulama
│   │   │   └── authorization.py # Yetkilendirme kontrolü
│   │   │
│   │   ├── permissions/        # Yetki tanımlamaları
│   │   │   └── permissions.py
│   │   │
│   │   ├── __init__.py         # Flask app factory
│   │   ├── config.py           # Uygulama konfigürasyonu
│   │   ├── extensions.py       # Flask extension'ları (SQLAlchemy vb.)
│   │   └── utils.py            # Yardımcı fonksiyonlar
│   │
│   ├── app.py                  # Uygulama giriş noktası
│   ├── requirements.txt        # Python bağımlılıkları
│   ├── .env.example            # Örnek environment dosyası
│   ├── .gitignore
│   └── .python-version         # Pyenv versiyon dosyası
│
├── database/                   # Veritabanı dosyaları
│   ├── 01_Tables/              # Tablo oluşturma SQL'leri
│   │   ├── users.sql
│   │   ├── posts.sql
│   │   ├── comments.sql
│   │   ├── communities.sql
│   │   ├── community_members.sql
│   │   ├── follow.sql
│   │   ├── follow_status.sql
│   │   ├── messages.sql
│   │   ├── privacy_types.sql
│   │   └── roles.sql
│   ├── 02_Views/               # View tanımlamaları
│   ├── 03_Functions/           # Stored procedure ve function'lar
│   └── Queries/                # Örnek sorgular
│
└── frontend/                   # Frontend uygulaması (henüz geliştirilmedi)
```

---

## 🏗️ Mimari Yapı

Proje **Layered Architecture** (Katmanlı Mimari) kullanmaktadır:

```
┌─────────────────────────────────────────────────────────┐
│                    Controllers                          │
│              (HTTP Request/Response)                    │
├─────────────────────────────────────────────────────────┤
│                     Services                            │
│                 (Business Logic)                        │
├─────────────────────────────────────────────────────────┤
│                   Repositories                          │
│               (Data Access Layer)                       │
├─────────────────────────────────────────────────────────┤
│                     Entities                            │
│              (SQLAlchemy Models)                        │
├─────────────────────────────────────────────────────────┤
│                    PostgreSQL                           │
│                    (Database)                           │
└─────────────────────────────────────────────────────────┘
```

---

## 🚀 Kurulum

### Gereksinimler

- Python 3.11+
- PostgreSQL 14+
- pyenv (önerilen)
- Git

### 1. Projeyi Klonlayın

```bash
git clone <repo-url>
cd SocialMediaProject
```

### 2. Python Ortamını Kurun

#### Linux / macOS

```bash
# pyenv kurulumu (eğer yüklü değilse)
# Linux (Ubuntu/Debian)
curl https://pyenv.run | bash

# macOS (Homebrew ile)
brew install pyenv pyenv-virtualenv

# Shell konfigürasyonu (~/.bashrc veya ~/.zshrc dosyasına ekleyin)
echo 'export PYENV_ROOT="$HOME/.pyenv"' >> ~/.zshrc
echo 'command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"' >> ~/.zshrc
echo 'eval "$(pyenv init -)"' >> ~/.zshrc
echo 'eval "$(pyenv virtualenv-init -)"' >> ~/.zshrc

# Shell'i yeniden başlatın
source ~/.zshrc

# Python 3.11 kurulumu
pyenv install 3.11.14

# Virtual environment oluşturma
pyenv virtualenv 3.11.14 socialmedia-env

# Proje dizinine gidin ve ortamı aktifleştirin
cd backend
pyenv local socialmedia-env
```

#### Windows

```powershell
# Python 3.11+ indirin ve kurun: https://www.python.org/downloads/

# Virtual environment oluşturma
cd backend
python -m venv venv

# Ortamı aktifleştirme (PowerShell)
.\venv\Scripts\Activate.ps1

# Veya (CMD)
.\venv\Scripts\activate.bat
```

### 3. Bağımlılıkları Yükleyin

```bash
cd backend
pip install -r requirements.txt
```

### 4. PostgreSQL Veritabanını Kurun

#### Linux (Ubuntu/Debian)

```bash
# PostgreSQL kurulumu
sudo apt update
sudo apt install postgresql postgresql-contrib

# PostgreSQL servisini başlatın
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Veritabanı oluşturma
sudo -u postgres psql -c "CREATE DATABASE social_media_db;"
sudo -u postgres psql -c "CREATE USER your_user WITH PASSWORD 'your_password';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE social_media_db TO your_user;"
```

#### macOS

```bash
# Homebrew ile kurulum
brew install postgresql@14
brew services start postgresql@14

# Veritabanı oluşturma
createdb social_media_db
psql -d social_media_db -c "CREATE USER your_user WITH PASSWORD 'your_password';"
psql -d social_media_db -c "GRANT ALL PRIVILEGES ON DATABASE social_media_db TO your_user;"
```

#### Windows

1. [PostgreSQL](https://www.postgresql.org/download/windows/) indirin ve kurun
2. pgAdmin veya psql ile veritabanı oluşturun:

```sql
CREATE DATABASE social_media_db;
CREATE USER your_user WITH PASSWORD 'your_password';
GRANT ALL PRIVILEGES ON DATABASE social_media_db TO your_user;
```

### 5. Tabloları Oluşturun

```bash
# database klasöründeki SQL dosyalarını sırasıyla çalıştırın
cd database/01_Tables

# Linux/macOS
psql -U your_user -d social_media_db -f roles.sql
psql -U your_user -d social_media_db -f privacy_types.sql
psql -U your_user -d social_media_db -f follow_status.sql
psql -U your_user -d social_media_db -f users.sql
psql -U your_user -d social_media_db -f posts.sql
psql -U your_user -d social_media_db -f comments.sql
psql -U your_user -d social_media_db -f communities.sql
psql -U your_user -d social_media_db -f community_members.sql
psql -U your_user -d social_media_db -f follow.sql
psql -U your_user -d social_media_db -f messages.sql
```

### 6. Environment Değişkenlerini Ayarlayın

```bash
cd backend

# .env.example dosyasını kopyalayın
cp .env.example .env

# .env dosyasını düzenleyin
nano .env  # veya tercih ettiğiniz editör
```

`.env` dosyası içeriği:

```env
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_NAME=social_media_db
DATABASE_USER=your_user
DATABASE_PASSWORD=your_password
SECRET_KEY=your-super-secret-key
JWT_SECRET_KEY=your-jwt-secret-key
```

### 7. Uygulamayı Çalıştırın

```bash
cd backend
python app.py
```

Uygulama varsayılan olarak `http://localhost:5000` adresinde çalışacaktır.

---

## 🔌 API Endpoints

| Endpoint | Açıklama |
|----------|----------|
| `/api/users` | Kullanıcı işlemleri |
| `/api/posts` | Gönderi işlemleri |
| `/api/comments` | Yorum işlemleri |
| `/api/communities` | Topluluk işlemleri |
| `/api/follow` | Takip işlemleri |
| `/api/messages` | Mesaj işlemleri |

---

## 🧪 Test

```bash
# Uygulamanın çalıştığını kontrol edin
python -c "from api import create_app; app = create_app(); print('✅ App loaded successfully!')"
```

---

## 📝 Geliştirme Notları

### Yeni Bir Endpoint Ekleme

1. `entities/entities.py` - Model tanımla
2. `repositories/` - Repository metodları ekle
3. `services/` - İş mantığını yaz
4. `controllers/` - API endpoint'ini tanımla
5. `controllers/api.py` - Blueprint'i kaydet

### Commit Mesajı Formatı

```
feat: Yeni özellik eklendi
fix: Hata düzeltildi
docs: Dokümantasyon güncellendi
refactor: Kod yeniden düzenlendi
```

---

## 👥 Katkıda Bulunanlar

- [İsim 1]
- [İsim 2]
- [İsim 3]

---

## 📄 Lisans

Bu proje MIT lisansı altında lisanslanmıştır.
