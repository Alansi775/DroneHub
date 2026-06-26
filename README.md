# DroneHub — Drone Parts E-commerce Platform

Modern, full-stack e-commerce platform for professional drone parts.

## Tech Stack
- **Frontend**: Flutter (iOS, Android, Web)
- **Backend**: Node.js + Express
- **Database**: PostgreSQL + Sequelize ORM
- **Auth**: JWT + Google OAuth
- **Email**: Nodemailer (Gmail SMTP)
- **Payment**: Mock (iyzico ready)

---

## Quick Start

### 1. Database Setup
```bash
# Install PostgreSQL first (if not installed):
brew install postgresql@16
brew services start postgresql@16

# Create the database:
psql -U postgres
CREATE DATABASE dronehub;
\q
```

### 2. Backend Setup
```bash
cd backend
cp .env.example .env
# Edit .env with your MySQL password and other config
npm install
npm run dev
```
Backend runs on: `http://localhost:5000`

### 3. Frontend Setup
```bash
cd Frontend
flutter pub get
flutter run
```

---

## Project Structure

```
DroneEcommerce/
├── backend/
│   ├── src/
│   │   ├── config/        # DB config
│   │   ├── controllers/   # Business logic
│   │   ├── middleware/    # Auth, upload, errors
│   │   ├── models/        # Sequelize models
│   │   ├── routes/        # API routes
│   │   └── services/      # Email, payment
│   ├── uploads/           # Product images
│   ├── server.js
│   └── package.json
│
└── Frontend/
    └── lib/
        ├── core/          # Theme, router, constants
        ├── data/          # Models, services, repositories
        └── presentation/  # Screens, widgets, providers
```

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/auth/register | Register |
| POST | /api/auth/login | Login |
| POST | /api/auth/google | Google OAuth |
| GET | /api/products | List products |
| GET | /api/products/:id | Product detail |
| GET | /api/cart | Get cart |
| POST | /api/cart/items | Add to cart |
| POST | /api/orders | Place order |
| GET | /api/orders | My orders |
| GET | /api/admin/dashboard | Admin stats |
| POST | /api/admin/products | Create product |
| GET | /api/admin/orders | All orders |

## Create Admin User
```sql
-- في psql أو أي PostgreSQL client:
UPDATE users SET role = 'admin' WHERE email = 'your@email.com';
```

## Add iyzico Payment
1. Install: `npm install iyzipay`
2. Add keys to `.env`: `IYZICO_API_KEY`, `IYZICO_SECRET_KEY`
3. Update `src/services/payment.service.js`
