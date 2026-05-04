# DUALSERVE Production-Ready Setup Guide

## Overview
This guide covers the new security features, deployment procedures, and testing for the DUALSERVE system.

## 📋 New Features

### 1. Custom Claims for Admin Role Management
**What it does:** Replaces hardcoded email check with secure, scalable admin role assignment  
**How to use:** Use the `setAdminRole` Cloud Function to grant admin access

```bash
# Grant admin role to a user (requires existing admin privileges)
firebase functions:shell
> setAdminRole({targetUid: "user-id-here"})
```

**Benefits:**
- Scalable: manage multiple admins easily
- Secure: no hardcoded emails in code
- Flexible: can revoke access anytime

### 2. Rate Limiting
**What it does:** Prevents abuse by limiting provider creation to 10 requests per 15 minutes per admin  
**How it works:** Uses Firestore to track request counts  
**Error Response:** Returns HTTP 429 when limit exceeded

```
Too many requests. Please try again in X minutes.
```

### 3. Audit Logging
**What it does:** Tracks all admin actions in `_system/auditLogs` Firestore collection  
**Logged Information:**
- Who performed the action (admin UID, email)
- What action was performed (createProvider, setAdminRole)
- When it happened (timestamp)
- What data was involved (sanitized)
- Success or failure result

**View Audit Logs:**
```bash
# Query audit logs from Firebase Console
Firestore > _system > auditLogs > entries
```

### 4. Email Templates
**What it does:** Professional HTML email templates for provider onboarding  
**Current Implementation:** Uses Firebase Auth's built-in emails as primary  
**Future:** Can be extended with Nodemailer for custom SMTP

### 5. Staging/Production Environments
**What it does:** Allows testing in staging before deploying to production

---

## 🚀 Deployment Guide

Run Firebase deploy commands from the repository root unless a command explicitly changes directories.

### Prerequisites
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Install dependencies in functions
cd functions
npm install
cd ..

# Build Flutter web output for Firebase Hosting
cd household_towing_app
flutter build web
cd ..
```

### Deploy to Production

```bash
# 1. Set your Firebase project (if not already set)
firebase use production

# 2. Build web hosting output
cd household_towing_app
flutter build web
cd ..

# 3. Deploy everything
firebase deploy

# Or deploy specific components:
firebase deploy --only functions        # Cloud Functions only
firebase deploy --only firestore:rules  # Firestore Rules only
firebase deploy --only hosting          # Hosting only

# 4. Verify deployment
firebase functions:list
```

### Deploy to Staging

```bash
# 1. Switch to staging project
firebase use staging

# 2. Build web hosting output
cd household_towing_app
flutter build web
cd ..

# 3. Deploy to staging
firebase deploy

# 4. Test the changes (see Testing section below)

# 5. If satisfied, promote to production
firebase use production
firebase deploy
```

### Switch Between Projects

```bash
# List available projects
firebase projects:list

# Switch to production
firebase use production

# Switch to staging
firebase use staging

# Check current project
firebase use
```

---

## ✅ Testing Guide

### Test 1: Set Admin Role via Custom Claims

```bash
# 1. Connect to Firebase Functions shell
firebase functions:shell

# 2. Grant admin role to a test user
> setAdminRole({targetUid: "test-user-uid-here"})

# Expected output:
# {
#   success: true,
#   message: 'Admin role set for test@example.com',
#   uid: 'test-user-uid-here'
# }

# 3. Verify in Firebase Console
# - Go to Authentication > Users
# - Find the test user
# - Check Custom Claims tab - should show {"admin": true}
```

### Test 2: Verify Custom Claims Work

```bash
# 1. Login as the user with custom claims
# 2. Try creating a provider in the admin panel
# 3. Should succeed (custom claims takes priority)
# 4. Check audit logs in Firestore
```

### Test 3: Rate Limiting

```bash
# 1. In Firebase Functions shell
firebase functions:shell

# 2. Call createProvider 10 times rapidly
for i in {1..15}; do
  createProvider({email: "test$i@example.com", name: "Test $i", phone: "09123456789", serviceType: "Towing"})
done

# Expected:
# - First 10 calls: success
# - Calls 11-15: Error - "Too many requests. Please try again in X minutes."
# - Audit logs show all attempts
```

### Test 4: Audit Logging

```bash
# 1. Create a provider via admin panel
# 2. Go to Firebase Console > Firestore
# 3. Navigate to: _system > auditLogs > entries
# 4. Verify audit entry exists with:
#    - timestamp: current time
#    - action: "createProvider"
#    - actor: { uid, email }
#    - result: "success"
#    - statusCode: 201
```

### Test 5: Custom Claims in Firestore Rules

```bash
# 1. Set custom admin claim on test user
firebase functions:shell
> setAdminRole({targetUid: "test-user-uid"})

# 2. Remove the Firestore role entry (to test custom claims priority)
# Go to Firestore > users > test-user-uid > Edit
# Change role field from "admin" to "provider"

# 3. Try creating provider as this user
# Should still succeed (custom claims check passes first)

# 4. Check household_towing_app/firestore.rules - custom claims is first check:
# request.auth.token.admin == true || ...
```

### Test 6: Staging vs Production

```bash
# 1. Deploy to staging
firebase use staging
firebase deploy

# 2. Test in staging Firebase project
# - Use staging Firestore database
# - Separate audit logs

# 3. Verify staging and production have separate data
firebase use production
firebase functions:call createProvider --data '{"email":"test@prod.com"...}'

firebase use staging
# Check Firestore - should be empty (separate database)

# 4. Switch back to production when satisfied
firebase use production
```

---

## 🔐 Security Best Practices

### 1. Hardcoded Email Fallback
- **Current:** charleskalvinvalenzuela@gmail.com is hardcoded for emergency access
- **Action:** Remove this after custom claims are fully deployed
- **How to remove:** Delete the email check from `household_towing_app/firestore.rules` and `functions/index.js`

```javascript
// REMOVE THIS in production:
request.auth.token.email.lower() == 'charleskalvinvalenzuela@gmail.com'
```

### 2. API Key Security
- **Current:** GOOGLE_PLACES_API_KEY in `.env` file
- **Not committed:** .env is in .gitignore
- **Deploy:** Set in Firebase Console or as environment variable

### 3. Rate Limiting Cleanup
- **TTL:** Rate limit entries auto-expire after 15 minutes
- **Firestore Cost:** Minimal impact (used for tracking only)

### 4. Audit Log Retention
- **Keep:** Store indefinitely for compliance
- **Query:** Can be archived to Cloud Storage periodically
- **Cost:** Minimal read/write operations

---

## 📊 Monitoring

### Check Function Performance
```bash
firebase functions:log
```

### Monitor Rate Limits
```bash
# Query Firestore
firestore query "_system/rateLimits/keys" where count > 5
```

### View Audit Logs
```bash
# In Firebase Console
Firestore > _system > auditLogs > entries
# Filter by action, actor, or timestamp
```

---

## 🐛 Troubleshooting

### Issue: "Only administrators can create providers"

**Cause:** User doesn't have admin role

**Solution:**
```bash
# Check if custom claims are set
firebase functions:shell
> auth.getUser("user-id-here")
# Look for customClaims: { admin: true }

# If not set, grant admin role
> setAdminRole({targetUid: "user-id-here"})

# Verify Firestore role field
# Firestore > users > user-id > role should be "admin"
```

### Issue: "Too many requests. Please try again in..."

**Cause:** Rate limit exceeded (10+ requests in 15 minutes)

**Solution:**
```bash
# Wait 15 minutes for the rate limit window to reset
# Or clear the rate limit entry from Firestore:
firestore delete "_system/rateLimits/keys/{admin-uid}"
```

### Issue: Audit logs not showing up

**Cause:** Audit logging error (shouldn't block main function)

**Solution:**
```bash
# Check Cloud Functions logs
firebase functions:log

# Verify Firestore permissions:
# _system collection should allow Cloud Functions to write
# Check household_towing_app/firestore.rules for _system collection rules
```

---

## 📝 Next Steps

1. **Test all features in staging first**
2. **Document any custom changes**
3. **Set up monitoring alerts**
4. **Plan migration from hardcoded email to custom claims** (see timeline below)
5. **Regular audit log reviews**

### Timeline: Hardcoded Email Removal
```
Week 1: Assess current admin count
Week 2: Set custom claims for all admins
Week 3: Update household_towing_app/firestore.rules to remove email check
Week 4: Verify in staging
Week 5: Deploy to production
Week 6: Monitor and verify
```

---

## 📞 Support

For issues or questions:
- Check Firebase docs: https://firebase.google.com/docs
- Review Cloud Functions logs: `firebase functions:log`
- Check Firestore for audit events
- Review household_towing_app/firestore.rules for permission issues

---

## Checklist Before Production

- [ ] All dependencies installed: `npm install` in functions/
- [ ] .env file configured with correct values
- [ ] Staging tested: provider creation, rate limiting, audit logs
- [ ] Custom claims set for admin users
- [ ] household_towing_app/firestore.rules deployed
- [ ] Audit logs visible in Firestore
- [ ] Rate limiting prevents abuse
- [ ] Email templates tested (if using custom SMTP)
- [ ] Backup of current setup
- [ ] Monitoring/alerting configured (optional but recommended)
