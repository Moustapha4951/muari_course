# Requirements Document

## Introduction

This document outlines the requirements for rebranding two Flutter applications (admin_app and wassalni_driver) from "Muari Course" to "RimApp" and reconfiguring them to use a new Firebase project. The rebranding involves updating application identifiers, package names, display names, and Firebase configuration across both Android and iOS platforms.

## Glossary

- **Admin App**: The administrative Flutter application located in the admin_app directory
- **Driver App**: The driver-facing Flutter application located in the wassalni_driver directory
- **Application ID**: The unique identifier for an Android application (e.g., com.muaricourse.admin)
- **Bundle Identifier**: The unique identifier for an iOS application
- **Firebase Project**: The backend service configuration for the applications
- **FlutterFire**: The Flutter plugin suite for Firebase integration
- **Package Name**: The Dart package name defined in pubspec.yaml

## Requirements

### Requirement 1

**User Story:** As a developer, I want to update all application identifiers from "muaricourse" to "rimapp", so that the applications reflect the new brand identity

#### Acceptance Criteria

1. WHEN the Admin App is built, THE Application ID SHALL be "com.rimapp.admin"
2. WHEN the Driver App is built, THE Application ID SHALL be "com.rimapp.driver"
3. THE Admin App pubspec.yaml SHALL contain the package name "rimapp_admin"
4. THE Driver App pubspec.yaml SHALL contain the package name "rimapp_driver"
5. WHERE Android manifests exist, THE Application ID SHALL be updated to use the rimapp namespace

### Requirement 2

**User Story:** As a developer, I want to update all display names and references from "Muari Course" to "RimApp", so that users see the correct branding throughout the applications

#### Acceptance Criteria

1. THE Admin App display name SHALL be "RimApp Admin"
2. THE Driver App display name SHALL be "RimApp Driver"
3. WHEN source code contains "muari course" or "muaricourse" references, THE code SHALL use "rimapp" instead
4. WHEN Kotlin/Java package declarations contain "muaricourse", THE declarations SHALL use "rimapp"
5. THE AndroidManifest.xml files SHALL reference the correct rimapp package names for services

### Requirement 3

**User Story:** As a developer, I want to reconfigure both applications with the new Firebase project "rimappmuaritania", so that the apps connect to the correct backend services

#### Acceptance Criteria

1. WHEN FlutterFire configuration is executed, THE command SHALL target the project "rimappmuaritania"
2. THE Firebase configuration files SHALL be generated for both Android and iOS platforms
3. THE google-services.json files SHALL be placed in the correct Android directories
4. THE GoogleService-Info.plist files SHALL be placed in the correct iOS directories
5. WHERE Firebase configuration exists in build files, THE configuration SHALL remain valid after rebranding

### Requirement 4

**User Story:** As a developer, I want to update all Gradle configuration files to reflect the new package structure, so that the Android builds succeed with the new identifiers

#### Acceptance Criteria

1. THE build.gradle files SHALL reference the correct rimapp application IDs
2. THE settings.gradle files SHALL maintain proper plugin configurations
3. WHEN Gradle builds are executed, THE builds SHALL complete without package name conflicts
4. THE namespace declarations in build.gradle SHALL use the rimapp package structure

### Requirement 5

**User Story:** As a developer, I want to update all native Android code (Kotlin/Java) to use the new package names, so that the applications compile and run correctly

#### Acceptance Criteria

1. WHEN Kotlin service classes exist, THE package declarations SHALL use com.rimapp namespace
2. THE NotificationService class SHALL be in the com.rimapp.driver package
3. THE ForegroundRideService class SHALL be in the com.rimapp.driver package
4. WHERE AndroidManifest.xml references services, THE service names SHALL use the rimapp package
5. THE directory structure for Kotlin/Java files SHALL match the new package hierarchy

### Requirement 6

**User Story:** As a developer, I want to verify that all configuration changes are consistent across both applications, so that both apps work correctly after rebranding

#### Acceptance Criteria

1. THE Admin App SHALL have consistent rimapp branding across all configuration files
2. THE Driver App SHALL have consistent rimapp branding across all configuration files
3. WHEN searching for "muaricourse" in the codebase, THE search SHALL return no results in configuration files
4. WHEN searching for "muari course" in the codebase, THE search SHALL return no results in user-facing strings
5. THE Firebase configuration SHALL be valid for both applications
