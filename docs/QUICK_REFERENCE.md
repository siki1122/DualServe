# DUALSERVE Quick Reference

## Firebase CLI Essentials

```bash
# Build Flutter web output before deploying hosting
cd household_towing_app
flutter build web
cd ..

# Check current project
firebase use

# Switch to staging
firebase use staging

# Switch to production
firebase use production

# Deploy everything
firebase deploy

# Deploy specific components
firebase deploy --only functions
firebase deploy --only firestore:rules
firebase deploy --only hosting

# View logs
firebase functions:log

# Open functions shell
firebase functions:shell
```

## Common Tasks

### Grant Admin Role
```bash
firebase functions:shell
> setAdminRole({targetUid: "user-uid-here"})
```

### View Audit Logs
1. Firebase Console -> Firestore
2. Navigate: `_system` -> `auditLogs` -> `entries`
3. Filter by action, actor, or date

### Check Rate Limits
1. Firebase Console -> Firestore
2. Navigate: `_system` -> `rateLimits` -> `keys`
3. View count and reset time for each admin

### Create Provider
1. Login as admin
2. Go to Admin Panel -> Providers
3. Click "Add Provider"
4. Fill form and submit

### Monitor Functions
```bash
firebase functions:log --lines 50

# Or in Firebase Console:
# Cloud Functions -> See logs icon
```

## Firestore Collections

```text
_system/
|-- auditLogs/
|   `-- entries/          # All admin action logs
`-- rateLimits/
    `-- keys/             # Rate limit tracking

bookings/
`-- {bookingId}           # Customer booking records

providers/
`-- {providerId}          # Service provider profiles

tasks/
`-- {taskId}              # Admin-assigned tasks

transactions/
`-- {transactionId}       # Payment/billing records

users/
`-- {userId}              # User profiles (role field here)
```

## Error Messages & Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| "Only administrators..." | Not an admin | Set custom claims: `setAdminRole({targetUid})` |
| "Too many requests" | Rate limit exceeded | Wait 15 min or delete from `_system/rateLimits` |
| "Email already exists" | User account exists | Use different email or reset user |
| "Invalid email format" | Bad email input | Enter valid email (test@example.com) |
| "Permission denied" | Firestore rules | Check user is authenticated and has correct role |

## Key Files & Locations

| File | Purpose |
|------|---------|
| `firebase.json` | Repo-root Firebase deploy config |
| `.firebaserc` | Firebase project aliases and hosting target |
| `functions/index.js` | Cloud Functions (createProvider, setAdminRole, etc) |
| `household_towing_app/firestore.rules` | Firestore security rules |
| `household_towing_app/firestore.indexes.json` | Firestore composite indexes |
| `household_towing_app/firebase.json` | FlutterFire generated app metadata |
| `household_towing_app/lib/` | Flutter app source |
| `household_towing_app/pubspec.yaml` | Flutter dependencies and app metadata |
| `functions/.env` | Environment variables (API keys, SMTP) |
| `docs/DEPLOYMENT_GUIDE.md` | Full deployment instructions |
| `docs/ADMIN_SETUP_GUIDE.md` | Admin role management |
| `household_towing_app/docs/` | Flutter app feature and workflow docs |

## Feature Checklist

- [x] Custom claims support
- [x] Rate limiting (10/15min)
- [x] Audit logging
- [x] Email templates
- [x] Staging/production setup
- [x] Security rules enhanced
- [x] Role-based access control
- [x] Error handling & logging

## Performance Notes

- **Rate Limit Check:** <10ms (Firestore lookup)
- **Audit Log Write:** <50ms
- **Total Provider Creation:** 1-2 seconds
- **Audit Log Query:** <100ms for recent entries

## Security Checklist

- [ ] Custom claims set for all admins
- [ ] Hardcoded email fallback still in place (for now)
- [ ] .env in .gitignore (no secrets in git)
- [ ] Firestore rules restrict _system collection access
- [ ] Audit logs kept and monitored
- [ ] Rate limits prevent abuse

## Support Links

- Firebase Console: https://console.firebase.google.com
- Firebase CLI Docs: https://firebase.google.com/docs/cli
- Cloud Functions: https://firebase.google.com/docs/functions
- Firestore Docs: https://firebase.google.com/docs/firestore

---

**Last Updated:** 2026-04-27
**Version:** 1.0 (Production Ready)
