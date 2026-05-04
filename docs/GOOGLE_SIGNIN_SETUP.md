# Google Sign-In Setup Guide

This guide explains how to configure Google Sign-In for your Flutter app.

## Overview

Google Sign-In has been integrated into your login screen. Users can now authenticate using their Google account, which provides clean, verified user data directly from Google.

## Setup Steps

### 1. Firebase Console Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Authentication** → **Sign-in method**
4. Enable **Google** as a sign-in provider
5. Make sure you have a support email configured

### 2. Web Setup (For localhost/web builds)

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Navigate to **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client ID** → **Web application**
5. Add `http://localhost:60921` to Authorized JavaScript origins (adjust port if different)
6. Add `http://localhost:60921/` to Authorized redirect URIs
7. Copy the **Client ID** (looks like: `123456789-abc123.apps.googleusercontent.com`)
8. Open `web/index.html` and replace `YOUR_GOOGLE_WEB_CLIENT_ID` with your actual Client ID:
   ```html
   <meta name="google-signin-client_id" content="YOUR_CLIENT_ID.apps.googleusercontent.com">
   ```

### 3. Android Setup

1. Open `android/app/build.gradle` and ensure your app's SHA-1 fingerprint is added to Firebase (it should already be in `google-services.json`)

2. **For Debug Builds:**
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```

3. **For Release Builds:**
   Generate your signing key and add its SHA-1 fingerprint to Firebase Console under Project Settings → Your apps → Android app

4. The `google-services.json` file should already be configured in your project.

### 4. iOS Setup

1. Open `ios/Runner.xcworkspace` (not Runner.xcodeproj) in Xcode
2. Go to **Project Settings** → **Build Phases** → **Copy Bundle Resources**
3. Add your `GoogleService-Info.plist` file (download from Firebase Console)
4. In **Info.plist**, verify the URL schemes are added:
   ```xml
   <key>CFBundleURLTypes</key>
   <array>
     <dict>
       <key>CFBundleURLSchemes</key>
       <array>
         <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
       </array>
     </dict>
   </array>
   ```

### 5. Dependencies

The following package has been added to `pubspec.yaml`:
- `google_sign_in: ^6.1.0`

Run `flutter pub get` to install dependencies.

## Usage

The Google Sign-In button is now available on the login screen. When users tap "Continue with Google":

1. Google sign-in dialog appears
2. User authenticates with their Google account
3. Clean user data is fetched from Google
4. User is authenticated in Firebase
5. App automatically navigates to the appropriate home screen

## Files Modified/Created

- **Created:** `lib/services/google_auth_service.dart` - Handles Google authentication logic
- **Modified:** `lib/screens/auth/login_screen.dart` - Added Google Sign-In button and handler
- **Modified:** `pubspec.yaml` - Added google_sign_in dependency
- **Modified:** `web/index.html` - Added Google Sign-In meta tag (web only)

## Troubleshooting

### "User cancelled the sign-in process"
This is normal - the user simply closed the Google sign-in dialog without authenticating.

### Web: "clientId not set"
- Ensure you've added the Client ID meta tag to `web/index.html`
- Replace `YOUR_GOOGLE_WEB_CLIENT_ID` with your actual Web OAuth 2.0 Client ID
- For development, add `http://localhost:PORT` to authorized origins in Google Cloud Console

### Web: "Invalid origin"
- Add your exact domain/localhost URL to **Authorized JavaScript origins** in Google Cloud Console
- For production, add your actual domain (e.g., `https://yourapp.com`)

### "Invalid client" or authentication errors
- Verify your Client ID is correct
- Check that Google sign-in is enabled in Firebase Authentication settings
- Ensure the package name matches exactly in Firebase Console (for mobile)

### iOS: "Info.plist not found"
- Download `GoogleService-Info.plist` from Firebase Console
- Add it to Xcode under Runner project

### Logo not displaying
- The button now uses a built-in icon, no external image needed
