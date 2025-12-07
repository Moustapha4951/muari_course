# Implementation Plan: App Rebranding

- [x] 1. Update Flutter package configuration





  - Update pubspec.yaml for admin_app: change package name from `muari_course_admin` to `rimapp_admin` and update description
  - Update pubspec.yaml for wassalni_driver: change package name from `muari_course_driver` to `rimapp_driver` and update description
  - _Requirements: 1.3, 1.4, 2.1, 2.2_

- [x] 2. Update Android build configuration for admin_app



  - Modify admin_app/android/app/build.gradle: update namespace from `com.muaricourse.admin` to `com.rimapp.admin`
  - Modify admin_app/android/app/build.gradle: update applicationId from `com.muaricourse.admin` to `com.rimapp.admin`
  - Update comments referencing "Muari Course" to "RimApp"
  - _Requirements: 1.1, 2.3, 4.1, 4.4_

- [x] 3. Update Android build configuration for wassalni_driver



  - Modify wassalni_driver/android/app/build.gradle: update namespace from `com.muaricourse.driver` to `com.rimapp.driver`
  - Modify wassalni_driver/android/app/build.gradle: update applicationId from `com.muaricourse.driver` to `com.rimapp.driver`
  - If build.gradle.kts exists, update applicationId there as well
  - Update comments referencing "Muari Course" to "RimApp"
  - _Requirements: 1.2, 2.3, 4.1, 4.4_

- [x] 4. Update admin_app Kotlin code and package structure



  - Update package declaration in admin_app/android/app/src/main/kotlin/com/muaricourse/admin/MainActivity.kt from `package com.muaricourse.admin` to `package com.rimapp.admin`
  - Move MainActivity.kt from com/muaricourse/admin/ to com/rimapp/admin/ directory structure
  - _Requirements: 2.4, 5.1_

- [x] 5. Update wassalni_driver Kotlin code and package structure



  - Update package declaration in MainActivity.kt from `package com.muaricourse.driver` to `package com.rimapp.driver`
  - Update package declaration in NotificationService.kt from `package com.muaricourse.driver` to `package com.rimapp.driver`
  - Update package declaration in ForegroundRideService.kt from `package com.muaricourse.driver` to `package com.rimapp.driver`
  - Update package declaration in RideNotificationHelper.kt from `package com.muaricourse.driver` to `package com.rimapp.driver`
  - Update package declaration in NotificationReceiver.kt from `package com.muaricourse.driver` to `package com.rimapp.driver`
  - Update all fully qualified class name references (e.g., `com.muaricourse.driver.MainActivity` to `com.rimapp.driver.MainActivity`)
  - Move all Kotlin files from com/muaricourse/driver/ to com/rimapp/driver/ directory structure
  - _Requirements: 2.4, 5.1, 5.2, 5.3, 5.5_

- [x] 6. Update admin_app AndroidManifest.xml



  - Update android:label from "موري كورس" to "RimApp Admin"
  - Update activity android:name reference if needed to match new package structure
  - _Requirements: 2.1, 2.5, 5.4_

- [x] 7. Update wassalni_driver AndroidManifest.xml



  - Update android:label to "RimApp Driver"
  - Update activity android:name from `com.muaricourse.driver.MainActivity` to `com.rimapp.driver.MainActivity`
  - Update receiver android:name from `com.muaricourse.driver.NotificationReceiver` to `com.rimapp.driver.NotificationReceiver`
  - Update service android:name from `com.muaricourse.driver.NotificationService` to `com.rimapp.driver.NotificationService`
  - Update service android:name from `com.muaricourse.driver.ForegroundRideService` to `com.rimapp.driver.ForegroundRideService`
  - Update intent-filter action from `com.muaricourse.driver.OPEN_APP` to `com.rimapp.driver.OPEN_APP`
  - _Requirements: 2.2, 2.5, 5.4_

- [x] 8. Update wassalni_driver Dart MethodChannel references



  - Update MethodChannel identifier in lib/services/notification_service.dart from `com.muaricourse.driver/app_launcher` to `com.rimapp.driver/app_launcher` (3 occurrences)
  - Update MethodChannel identifier in lib/main.dart from `com.muaricourse.driver/app_launcher` to `com.rimapp.driver/app_launcher`
  - _Requirements: 2.3, 5.1_

- [x] 9. Update wassalni_driver Kotlin intent action references



  - Update Intent action in RideNotificationHelper.kt from `com.muaricourse.driver.OPEN_APP` to `com.rimapp.driver.OPEN_APP`
  - Update Intent action in MainActivity.kt from `com.muaricourse.driver.OPEN_APP` to `com.rimapp.driver.OPEN_APP`
  - Update Intent action check in NotificationReceiver.kt from `com.muaricourse.driver.OPEN_APP` to `com.rimapp.driver.OPEN_APP`
  - _Requirements: 2.3, 5.1_

- [x] 10. Configure Firebase for new project




  - Run `flutterfire configure --project=rimappmuaritania` command
  - Select admin_app for configuration
  - Select both Android and iOS platforms
  - Verify google-services.json is generated with package_name "com.rimapp.admin"
  - Verify GoogleService-Info.plist is generated for iOS
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [x] 11. Configure Firebase for wassalni_driver





  - Run `flutterfire configure --project=rimappmuaritania` command
  - Select wassalni_driver for configuration
  - Select both Android and iOS platforms
  - Verify google-services.json is generated with package_name "com.rimapp.driver"
  - Verify GoogleService-Info.plist is generated for iOS
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

- [ ] 12. Verify and test admin_app build
  - Run `flutter clean` in admin_app directory
  - Run `flutter pub get` in admin_app directory
  - Run `flutter build apk` to verify Android build succeeds
  - Check for any warnings or errors related to package names
  - _Requirements: 4.3, 6.1, 6.3_

- [ ] 13. Verify and test wassalni_driver build
  - Run `flutter clean` in wassalni_driver directory
  - Run `flutter pub get` in wassalni_driver directory
  - Run `flutter build apk` to verify Android build succeeds
  - Check for any warnings or errors related to package names
  - _Requirements: 4.3, 6.2, 6.3_

- [ ] 14. Final verification and cleanup
  - Search entire codebase for "muaricourse" to ensure no remaining references in configuration files
  - Search entire codebase for "muari course" to ensure no remaining references in user-facing strings
  - Verify both apps have consistent rimapp branding
  - Document any manual steps needed for iOS bundle identifier updates
  - _Requirements: 6.3, 6.4, 6.5_
