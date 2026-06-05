# LeafLog: Intelligent Digital Garden Manager

LeafLog is a full-stack garden management and e-commerce platform designed to help plant enthusiasts monitor plant health, track watering schedules, and purchase new additions to their collection.

## Features
- **User Authentication:** Secure JWT-based login and signup system.
- **My Garden:** Real-time dashboard to track plant health, status, and "days alive" metrics.
- **E-commerce Store:** Browse plants with detailed care guides, images, and pricing in PKR.
- **Checkout Flow:** Add to cart functionality with dynamic price calculations.
- **Profile Management:** Track lifetime spending and personalize your account with profile pictures.

## Technologies Used
- **Frontend:** Flutter (State management, API integration, Modern UI)
- **Backend:** Node.js, Express.js
- **Database:** MySQL
- **Auth:** JWT (JSON Web Tokens), bcryptjs

## Setup Instructions
1. **Database:** Execute the SQL scripts in `database/schema.sql`.
2. **Backend:** - `cd backend`
   - `npm install`
   - Configure your MySQL credentials in `server.js`

## Getting Started
### Backend
1. Navigate to `/backend`
2. Run `npm install`
3. Run `node server.js`

### Frontend
1. Navigate to `/frontend`
2. Run `flutter pub get`
3. Run `flutter run`
   - `node server.js`
3. **Frontend:** - `flutter pub get`
   - Ensure you are using a local Node.js server (Update `baseUrl` to `10.0.2.2` for Android Emulator).
