# 🚖 RimApp Customer App

A modern, feature-rich taxi booking application for customers built with Flutter and Firebase.

## ✨ Features

### 🔐 Authentication
- **Phone-based Login**: Simple phone number authentication
- **Auto Registration**: New users automatically directed to registration
- **Persistent Sessions**: Stay logged in with SharedPreferences

### 🗺️ Ride Booking
- **Interactive Map**: Google Maps integration with custom markers
- **Location Selection**: Search and select pickup/dropoff from predefined places
- **Real-time Fare Calculation**: Automatic fare calculation based on distance
- **Smart Distance Calculation**: Haversine formula for accurate distances

### 📍 Ride Tracking
- **Real-time Updates**: Live ride status monitoring via Firestore
- **Driver Location**: See driver's location on map (when available)
- **Status Indicators**: Visual status updates (pending, accepted, started, completed)
- **Call Driver**: Direct phone call to driver
- **Cancel Ride**: Cancel pending or accepted rides

### 🔔 Notifications
- **Local Notifications**: Flutter Local Notifications (no FCM needed)
- **Ride Status Updates**: Instant notifications for:
  - Ride accepted by driver
  - Ride started
  - Ride completed
  - Ride cancelled
- **Background Monitoring**: Firestore snapshots for real-time updates

### ⭐ Rating System
- **Driver Rating**: Rate drivers after completed rides (1-5 stars)
- **Comments**: Add optional feedback
- **Average Calculation**: Updates driver's overall rating

### 📜 Ride History
- **Complete History**: View all past rides
- **Status Filtering**: See completed, cancelled rides
- **Ride Details**: Pickup, dropoff, fare, driver info
- **Date Formatting**: Arabic date/time formatting

### 👤 Profile Management
- **View Profile**: See user stats (total rides, rating)
- **Edit Name**: Update display name
- **Logout**: Secure logout with data clearing

### 🎨 UI/UX
- **Modern Design**: Material 3 with custom theme
- **RTL Support**: Full Arabic language support
- **Smooth Animations**: Fade, scale, and transition animations
- **Beautiful Gradients**: Purple/turquoise color scheme
- **Responsive**: Adapts to different screen sizes

## 🏗️ Architecture

```
lib/
├── main.dart                    # App entry point
├── firebase_options.dart        # Firebase configuration
├── models/
│   ├── customer.dart           # Customer data model
│   └── place.dart              # Location model
├── screens/
│   ├── splash_screen.dart      # Animated splash
│   ├── login_screen.dart       # Phone login
│   ├── register_screen.dart    # New user registration
│   ├── home_screen.dart        # Main map & booking
│   ├── select_location_screen.dart  # Location picker
│   ├── ride_request_screen.dart     # Fare confirmation
│   ├── ride_tracking_screen.dart    # Live ride tracking
│   ├── ride_history_screen.dart     # Past rides
│   ├── profile_screen.dart          # User profile
│   └── rate_driver_screen.dart      # Driver rating
├── services/
│   └── notification_service.dart    # Local notifications
├── utils/
│   ├── app_theme.dart              # Design system
│   └── shared_preferences_helper.dart  # Local storage
└── widgets/                        # Reusable widgets
```

## 🔥 Firebase Collections

### `customers`
```dart
{
  'name': String,
  'phone': String,
  'createdAt': Timestamp,
  'completedRides': int,
  'rating': double,
  'isBanned': bool
}
```

### `rides`
```dart
{
  'customerId': String,
  'customerName': String,
  'customerPhone': String,
  'pickupLocation': GeoPoint,
  'pickupAddress': String,
  'dropoffLocation': GeoPoint,
  'dropoffAddress': String,
  'distance': double,
  'fare': double,
  'status': String, // pending, accepted, started, completed, cancelled
  'cityId': String,
  'driverId': String?,
  'driverName': String?,
  'driverPhone': String?,
  'driverLocation': GeoPoint?,
  'createdAt': Timestamp,
  'startTime': Timestamp?,
  'endTime': Timestamp?,
  'customerRating': double?,
  'customerComment': String?
}
```

### `places`
```dart
{
  'name': String,
  'description': String,
  'location': GeoPoint,
  'cityId': String,
  'isActive': bool
}
```

### `prices`
```dart
{
  'minimumFare': double,
  'pricePerKm': double,
  'maximumKm': double,
  'isActive': bool
}
```

## 📦 Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^2.24.2
  cloud_firestore: ^4.14.0
  google_fonts: ^6.1.0
  shared_preferences: ^2.2.2
  google_maps_flutter: ^2.4.0
  geolocator: ^10.1.0
  flutter_local_notifications: ^19.0.0
  permission_handler: ^12.0.0+1
  intl: ^0.20.2
  url_launcher: ^6.1.14
  fluttertoast: ^8.2.12
```

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (>=3.2.3)
- Firebase project configured
- Google Maps API key

### Installation

1. **Clone the repository**
```bash
git clone <repository-url>
cd wassalni_customer
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Configure Firebase**
```bash
flutterfire configure --project=rimappmuaritania
```

4. **Add Google Maps API Key**

**Android**: `android/app/src/main/AndroidManifest.xml`
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

**iOS**: `ios/Runner/AppDelegate.swift`
```swift
GMSServices.provideAPIKey("YOUR_API_KEY")
```

5. **Run the app**
```bash
flutter run
```

## 🎯 User Flow

1. **Launch** → Splash Screen (3s animation)
2. **Login** → Enter phone number
3. **Register** (if new) → Enter name
4. **Home** → View map, select locations
5. **Request Ride** → Confirm fare
6. **Track Ride** → Monitor driver location & status
7. **Complete** → Rate driver
8. **History** → View past rides

## 🔔 Notification Flow

```
Ride Created → Start Listening
     ↓
Driver Accepts → Notification: "السائق [name] في الطريق إليك"
     ↓
Ride Starts → Notification: "الرحلة جارية الآن"
     ↓
Ride Completes → Notification: "شكراً لاستخدامك RimApp"
     ↓
Show Rating Screen → Stop Listening
```

## 🎨 Design System

### Colors
- **Primary**: `#6C63FF` (Purple)
- **Secondary**: `#00D9B5` (Turquoise)
- **Success**: `#00C853` (Green)
- **Warning**: `#FFB300` (Gold)
- **Error**: `#FF5252` (Red)
- **Info**: `#40C4FF` (Blue)

### Typography
- **Arabic**: Cairo (Google Fonts)
- **English**: Poppins (Google Fonts)

### Components
- Rounded corners (16-24px)
- Soft shadows
- Gradient backgrounds
- Material 3 design

## 🔒 Security

- No passwords stored
- Phone-based authentication
- Firestore security rules required
- User data encrypted in SharedPreferences

## 📱 Supported Platforms

- ✅ Android
- ✅ iOS
- ✅ Web (limited)
- ✅ Windows (limited)
- ✅ macOS (limited)

## 🐛 Known Issues

- Google Maps requires API key configuration
- Notifications require permission on Android 13+
- Background location tracking not implemented

## 🔮 Future Enhancements

- [ ] Payment integration
- [ ] Multiple payment methods
- [ ] Ride scheduling
- [ ] Favorite locations
- [ ] Promo codes
- [ ] Ride sharing
- [ ] In-app chat with driver
- [ ] Trip receipts
- [ ] Emergency SOS button

## 📄 License

This project is proprietary software for RimApp.

## 👥 Team

Developed by RimApp Team

## 📞 Support

For support, contact: support@rimapp.com
