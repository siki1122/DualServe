$ErrorActionPreference = "Stop"

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   DualServe - Full System Test Script" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# 1. Start Firebase Emulators in the background
Write-Host "`n[1/4] Starting Firebase Emulators..." -ForegroundColor Yellow
$emulatorJob = Start-Job {
    $env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-21.0.12.101-hotspot"
    $env:PATH = "$env:JAVA_HOME\bin;" + $env:PATH
    firebase emulators:start --only auth,firestore
}

# Wait for emulators to boot up
Write-Host "Waiting 15 seconds for Emulators to boot..." -ForegroundColor DarkGray
Start-Sleep -Seconds 15

# 2. Run Unit Tests
Write-Host "`n[2/4] Running System Unit Tests..." -ForegroundColor Yellow
flutter test

# 3. Run Integration Tests
Write-Host "`n[3/4] Running E2E Integration Tests..." -ForegroundColor Yellow

Write-Host "Running Comprehensive Lifecycle Test on Mobile Device..." -ForegroundColor DarkGray
# We explicitly target your TECNO CM7 device ID!
flutter test integration_test/comprehensive_system_test.dart -d 1408925548011972 --dart-define=USE_EMULATOR=true

# 4. Clean up
Write-Host "`n[4/4] Cleaning up..." -ForegroundColor Yellow
Stop-Job $emulatorJob
Remove-Job $emulatorJob

Write-Host "`n=========================================" -ForegroundColor Green
Write-Host "        ALL TESTS COMPLETED!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
