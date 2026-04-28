# Custom Claims Admin Setup Guide

## Quick Start: How to Grant Admin Access

### Method 1: Firebase Admin SDK (Recommended for Production)

```javascript
// Using Firebase Admin SDK in Node.js
const admin = require('firebase-admin');

// Initialize if not already done
admin.initializeApp();

async function grantAdminRole(userEmail) {
  try {
    // 1. Get user by email
    const user = await admin.auth().getUserByEmail(userEmail);
    
    // 2. Set custom claims
    await admin.auth().setCustomUserClaims(user.uid, { admin: true });
    
    // 3. Update Firestore role for consistency
    await admin.firestore().collection('users').doc(user.uid).update({
      role: 'admin',
    });
    
    console.log(`✅ Admin role granted to ${userEmail}`);
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Usage:
grantAdminRole('newadmin@example.com');
```

### Method 2: Firebase Console (Web UI)

1. Go to **Firebase Console** > **Authentication** > **Users**
2. Find the user you want to make admin
3. Click on their entry
4. Scroll to **Custom Claims** section
5. Click **Edit** and paste:
```json
{
  "admin": true
}
```
6. Click **Save**

Then in Firestore:
1. Go to **Firestore** > **users** > find the user document
2. Update the `role` field from "provider"/"customer" to "admin"

### Method 3: Cloud Function (Self-Service - After First Admin Set Up)

In your Flutter app (admin panel):

```dart
// Already available in providers_page.dart - can be added to admin settings
Future<void> grantAdminRole(String userEmail) async {
  try {
    final response = await FirebaseFunctions.instance
        .httpsCallable('setAdminRole')
        .call({
          'targetUid': userIdOfTarget,
        });
    
    if (response.data['success']) {
      print('Admin role granted!');
    }
  } catch (e) {
    print('Error: ${e.message}');
  }
}
```

---

## Verify Admin Role Was Set

### Check in Firebase Console

1. **Authentication Tab:**
   - Go to **Firebase Console** > **Authentication** > **Users**
   - Click on the user
   - Scroll to **Custom Claims**
   - Should show: `{"admin": true}`

2. **Firestore Tab:**
   - Go to **Firestore** > **users** > find user document
   - `role` field should be: `"admin"`

### Check via Firebase CLI

```bash
# Connect to Firebase shell
firebase functions:shell

# Get user info
> auth.getUser("user-uid-here")

# Look for in output:
# customClaims: { admin: true }
```

---

## Remove Admin Role

### Option 1: Firebase Console

1. Go to **Authentication** > **Users**
2. Click the admin user
3. Click **Edit** on Custom Claims
4. Remove the entire custom claims object (leave empty or delete)
5. In Firestore, change their role back to "provider" or "customer"

### Option 2: Firebase CLI

```bash
firebase functions:shell

# Remove custom claims
> auth.setCustomUserClaims("user-uid", null)

# Then update Firestore role
> firestore.collection('users').doc('user-uid').update({role: 'provider'})
```

---

## Troubleshooting

### Issue: User still can't create providers after setting custom claims

**Check:**
1. Custom claims showing in Firebase Console Authentication tab?
2. Firestore `users` document has `role: "admin"`?
3. User logged out and back in? (Claims cached locally)

**Solution:**
- Have user log out completely and log back in
- Wait a few minutes (Firebase caches claims)
- Try again

### Issue: "Only administrators can create providers" error

**Check:**
1. Is `request.auth.token.admin == true` in their token?
2. Does their Firestore `users` document have `role: "admin"`?
3. Is their email the hardcoded fallback? (only for dev)

**Solution:**
```bash
# Verify custom claims are set
firebase functions:shell
> auth.getUser("their-uid")

# If no customClaims, set them:
> setAdminRole({targetUid: "their-uid"})
```

### Issue: Can't access Firebase Console to set claims

**Solution:**
Use Firebase Admin SDK in Node.js (see Method 1 above):
```bash
# In your local environment
node
> const admin = require('firebase-admin')
> admin.initializeApp()
> admin.auth().setCustomUserClaims('uid', {admin: true})
```

---

## Best Practices

### ✅ DO:
- Set custom claims for all permanent admins
- Keep Firestore role and custom claims in sync
- Document who has admin access and why
- Review audit logs for admin actions
- Use strong, unique passwords for admin accounts

### ❌ DON'T:
- Use hardcoded email checks in production code
- Grant admin access to temporary users
- Share admin credentials
- Forget to test in staging first
- Leave old admin accounts active (remove when user leaves)

---

## Migration Plan: Remove Hardcoded Email

### Current State (Development)
```javascript
// In firestore.rules and functions/index.js
request.auth.token.email.lower() == 'charleskalvinvalenzuela@gmail.com'
```

### Step 1: Set Custom Claims
```bash
firebase functions:shell
> setAdminRole({targetUid: "charlie's-uid"})
```

### Step 2: Verify Custom Claims Work
- Test provider creation as Charlie
- Should still succeed (custom claims is checked first)
- Check audit logs

### Step 3: Remove Hardcoded Email
Edit `firestore.rules`:
```javascript
function isAdmin() {
  return isSignedIn() && (
    // Custom claims (production)
    request.auth.token.admin == true ||
    // Firestore role (fallback)
    (exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin')
    // REMOVE THIS LINE ↓
    // request.auth.token.email.lower() == 'charleskalvinvalenzuela@gmail.com'
  );
}
```

### Step 4: Deploy & Test
```bash
firebase deploy --only firestore:rules
# Test in staging first
```

### Step 5: Verify in Production
- Test provider creation
- Check audit logs
- Confirm no "permission denied" errors

---

## Reference: Cloud Function `setAdminRole`

**Location:** `functions/index.js`

**Required Parameters:**
- `targetUid` (string): Firebase UID of user to make admin

**Returns:**
```json
{
  "success": true,
  "message": "Admin role set for user@email.com",
  "uid": "target-user-uid"
}
```

**Requires:**
- Caller must be authenticated
- Caller must be an existing admin (custom claims, Firestore role, or hardcoded email)

**Logs:**
- Audit log entry created in `_system/auditLogs`
- Console log with details

