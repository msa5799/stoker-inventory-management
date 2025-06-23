# 🏢 Stoker - Professional Stock Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.4.3+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS-lightgrey.svg)](https://flutter.dev/multi-platform)

**Stoker** is a modern, comprehensive inventory management system designed for small to medium businesses. Built with Flutter and powered by Firebase, it offers real-time inventory tracking, sales management, and business analytics.

## ✨ Features

### 🏢 Organization Management
- **Multi-Organization Support**: Manage multiple business entities
- **Email Verification**: Secure organization registration process
- **User Role Management**: Admin and employee access levels
- **Account Security**: Password-protected account deletion

### 📦 Inventory Management
- **Real-time Stock Tracking**: Live inventory updates
- **Product Management**: Add, edit, and categorize products
- **Barcode Support**: Quick product identification and management
- **Low Stock Alerts**: Automated notifications for reorder points
- **Batch/Lot Tracking**: FIFO inventory management

### 💰 Sales & Purchase Management
- **Point of Sale**: Quick and efficient sales processing
- **Purchase Orders**: Track incoming inventory
- **Returns Processing**: Handle customer returns seamlessly
- **Loss Management**: Track and manage inventory losses

### 📊 Analytics & Reporting
- **Financial Dashboard**: Real-time profit/loss tracking
- **Sales Analytics**: Detailed sales performance metrics
- **Inventory Reports**: Stock levels and movement analysis
- **Export Capabilities**: Data export for external analysis

### 🔄 Data Management
- **Real-time Sync**: Cloud-based data synchronization
- **Offline Support**: Continue working without internet
- **Backup & Restore**: Secure data backup solutions
- **Data Import/Export**: CSV and Excel compatibility

### 📧 Communication
- **Email Integration**: SMTP-based email notifications
- **Automated Alerts**: Stock alerts and system notifications
- **Custom Templates**: Professional email templates

## 🛠️ Tech Stack

- **Frontend**: Flutter 3.4.3+ (Cross-platform)
- **Backend**: Firebase (Firestore, Authentication)
- **Database**: Cloud Firestore with offline persistence
- **Email Service**: Gmail SMTP integration
- **Charts**: FL Chart for analytics visualization
- **Barcode**: Mobile Scanner for product identification
- **Notifications**: Local and push notifications

## 📱 Platform Support

- ✅ Android (API 21+)
- ✅ iOS (13.0+)
- ✅ macOS (10.14+)
- 🔄 Web (Future release)

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.4.3 or higher
- Dart SDK 3.0.0 or higher
- Firebase project setup
- Android Studio / Xcode (for mobile development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/msa5799/stoker-inventory-management.git
   cd stoker-inventory-management
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project
   - Enable Authentication and Firestore
   - Download configuration files:
     - `android/app/google-services.json`
     - `ios/Runner/GoogleService-Info.plist`
     - `macos/Runner/GoogleService-Info.plist`
   - Generate `lib/firebase_options.dart` using FlutterFire CLI

4. **Email Configuration**
   - Follow instructions in `EMAIL_SETUP.md`
   - Configure Gmail SMTP settings

5. **Run the application**
   ```bash
   flutter run
   ```

### Building for Production

#### Android
```bash
flutter build apk --release
# or for App Bundle
flutter build appbundle --release
```

#### iOS
```bash
flutter build ios --release
```

#### macOS
```bash
flutter build macos --release
```

## 📁 Project Structure

```
lib/
├── main.dart                    # Application entry point
├── models/                      # Data models
│   ├── product.dart
│   ├── sale.dart
│   ├── inventory_transaction.dart
│   └── ...
├── screens/                     # UI screens
│   ├── auth/                   # Authentication screens
│   ├── dashboard_screen.dart
│   ├── products_screen.dart
│   └── ...
├── services/                    # Business logic services
│   ├── firebase_service.dart
│   ├── inventory_service.dart
│   ├── email_service.dart
│   └── ...
└── widgets/                     # Reusable UI components
```

## 🔐 Security Features

- **Authentication**: Firebase Auth with email verification
- **Data Validation**: Input sanitization and validation
- **Access Control**: Role-based permissions
- **Secure Communication**: HTTPS and Firebase security rules
- **Data Privacy**: GDPR compliant data handling

## 📈 Performance Optimizations

- **Lazy Loading**: Progressive data loading
- **Offline Persistence**: Firebase offline support
- **Memory Management**: Efficient widget lifecycle
- **Background Sync**: Non-blocking data synchronization
- **Optimized Queries**: Efficient Firestore queries

## 🔧 Configuration

### Email Setup
Configure Gmail SMTP in your environment:
```dart
// Example configuration in email_service.dart
final smtpServer = gmail('your-email@gmail.com', 'app-password');
```

### Firebase Rules
Deploy security rules:
```bash
firebase deploy --only firestore:rules
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: Check the [Wiki](https://github.com/msa5799/stoker-inventory-management/wiki)
- **Issues**: Report bugs via [GitHub Issues](https://github.com/msa5799/stoker-inventory-management/issues)
- **Email**: msakkaya.01@gmail.com

## 🗺️ Roadmap

- [ ] Web platform support
- [ ] Advanced reporting dashboard
- [ ] Multi-language support
- [ ] API for third-party integrations
- [ ] Mobile app for customers
- [ ] Advanced analytics with AI insights

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for robust backend services
- Community contributors and testers

---

**Made with ❤️ by [Mehmet Sahin](https://github.com/msa5799)**

*Stoker - Empowering businesses with intelligent inventory management*
