# Hardcoded Email to Custom Claims Migration Checklist

This document guides you through removing the hardcoded admin email (`charleskalvinvalenzuela@gmail.com`) from the code and switching to custom claims-based admin management.

## Pre-Migration (Week 1)

### Step 1: Audit Current Admins
- [ ] Identify all current admin users
- [ ] Document their email addresses
- [ ] Verify they have active accounts
- [ ] Test their admin access

**Command:**
```bash
firebase functions:shell
> auth.listUsers()
# Look for users with email "charleskalvinvalenzuela@gmail.com"
```

### Step 2: Plan Migration Timeline
- [ ] Decide migration date
- [ ] Schedule team communication
- [ ] Prepare rollback plan
- [ ] Set up monitoring

### Step 3: Test in Staging First
- [ ] Deploy all code changes to staging
- [ ] Set custom claims on test user in staging
- [ ] Verify provider creation still works
- [ ] Test audit logs

---

## Migration Week (Week 2-3)

### Step 4: Set Custom Claims for All Admins
For each admin user, set their custom claims:

```bash
firebase functions:shell

# For each admin (example)
> setAdminRole({targetUid: "uid-of-admin-1"})
> setAdminRole({targetUid: "uid-of-admin-2"})
```

**Verification:**
```bash
# Verify each admin
> auth.getUser("uid-of-admin-1")

# Look for: customClaims: { admin: true }
```

### Step 5: Verify Firestore Consistency
For each admin, ensure Firestore role is also set:

```bash
# Firebase Console → Firestore → users → {userId}
# Verify: role = "admin"
```

**Checklist:**
- [ ] Admin 1: Custom claims ✅, Firestore role ✅
- [ ] Admin 2: Custom claims ✅, Firestore role ✅
- [ ] Admin N: Custom claims ✅, Firestore role ✅

### Step 6: Test Admin Access
For each admin:
- [ ] Login to app
- [ ] Navigate to admin panel
- [ ] Try creating a provider
- [ ] Verify success (should not see "permission denied")
- [ ] Check audit logs

---

## Code Removal (Week 4)

### Step 7: Remove Email Check from Firestore Rules

**Current Code (household_towing_app/firestore.rules):**
```javascript
function isAdmin() {
  return isSignedIn() && (
    request.auth.token.admin == true ||
    (exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin') ||
    request.auth.token.email.lower() == 'charleskalvinvalenzuela@gmail.com'  // ← DELETE THIS
  );
}
```

**After Removal:**
```javascript
function isAdmin() {
  return isSignedIn() && (
    request.auth.token.admin == true ||
    (exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin')
  );
}
```

**Steps:**
1. [ ] Edit `household_towing_app/firestore.rules`
2. [ ] Remove email check line
3. [ ] Save file
4. [ ] Test in staging
5. [ ] Deploy to production: `firebase deploy --only firestore:rules`

### Step 8: Remove Email Check from Cloud Functions

**Current Code (functions/index.js - isUserAdmin function):**
```javascript
// Remove this block:
if (context?.auth?.token?.email?.toLowerCase() === 'charleskalvinvalenzuela@gmail.com') {
  return { isAdmin: true, method: 'email' };
}
```

**Steps:**
1. [ ] Edit `functions/index.js`
2. [ ] Find the `isUserAdmin` function
3. [ ] Remove the email check block (entire if statement)
4. [ ] Save file
5. [ ] Test in staging
6. [ ] Deploy to production: `firebase deploy --only functions`

---

## Verification (Week 5)

### Step 9: Verify Production Removal
- [ ] Code has been deployed to production
- [ ] Email check is no longer in code
- [ ] All admins still have custom claims set
- [ ] All admins can still access admin functions

**Test:**
```bash
firebase functions:log
# Monitor for any "permission denied" errors
```

### Step 10: Monitor for Issues
- [ ] Watch cloud functions logs for 24 hours
- [ ] Check for any "Only administrators can create providers" errors
- [ ] Verify audit logs are being recorded
- [ ] Confirm no production incidents

**Monitoring:**
```bash
firebase functions:log --lines 100 | grep -i "permission\|error"
```

---

## Rollback Plan

If anything goes wrong, you can quickly rollback:

### Quick Rollback (Option 1: Re-add email check)
```bash
# Edit household_towing_app/firestore.rules - add back:
request.auth.token.email.lower() == 'charleskalvinvalenzuela@gmail.com' ||

# Deploy immediately:
firebase deploy --only firestore:rules
```

### Safe Rollback (Option 2: Set custom claims again)
```bash
firebase functions:shell
> setAdminRole({targetUid: "admin-uid"})
```

### Test Rollback
- [ ] User can create providers
- [ ] Admin access restored
- [ ] Audit logs show success

---

## Post-Migration (Week 6+)

### Step 11: Clean Up Documentation
- [ ] Update internal documentation
- [ ] Remove references to hardcoded email
- [ ] Document custom claims process
- [ ] Add to onboarding guide

**Files to Update:**
- [ ] README.md (project root)
- [ ] Team wiki/documentation
- [ ] Deployment guide
- [ ] Security documentation

### Step 12: Training & Communication
- [ ] Brief team on changes
- [ ] Explain custom claims system
- [ ] Document how to add new admins
- [ ] Share ADMIN_SETUP_GUIDE.md

### Step 13: Archive & Monitor
- [ ] Archive migration notes
- [ ] Set up ongoing monitoring
- [ ] Document lessons learned
- [ ] Plan next improvements

---

## Success Criteria Checklist

### Pre-Migration
- [ ] All current admins identified
- [ ] Migration date set
- [ ] Rollback plan documented
- [ ] Team trained

### During Migration
- [ ] Custom claims set for all admins
- [ ] Firestore roles updated
- [ ] All admins tested and verified
- [ ] Staging environment working

### Post-Migration
- [ ] Email checks removed from code
- [ ] Production deployment successful
- [ ] No admin access issues observed
- [ ] Audit logs show successful operations
- [ ] Documentation updated
- [ ] Team trained

---

## Timeline Summary

```
Week 1: Planning & Preparation
  ├─ Audit current admins
  ├─ Plan migration date
  └─ Test in staging

Week 2-3: Set Custom Claims
  ├─ Set claims for all admins (firebase functions:shell)
  ├─ Verify in Firebase Console
  ├─ Test admin access
  └─ Monitor audit logs

Week 4: Code Removal
  ├─ Remove email check from household_towing_app/firestore.rules
  ├─ Remove email check from functions/index.js
  ├─ Deploy changes
  └─ Test thoroughly

Week 5-6: Verification & Cleanup
  ├─ Monitor for issues
  ├─ Update documentation
  ├─ Train team
  └─ Archive migration notes
```

---

## Troubleshooting During Migration

### Issue: Admin gets "permission denied" after custom claims set

**Cause:** Custom claims not yet activated (Firebase caches for ~1 hour)

**Solution:**
1. Have admin log out completely
2. Wait 5-10 minutes
3. Have admin log back in
4. Try again

### Issue: Custom claims show in custom claims tab but admin still can't access

**Cause:** Firestore role field still not set to "admin"

**Solution:**
1. Firebase Console → Firestore
2. Go to `users/{userId}`
3. Ensure `role` field = "admin"
4. Save changes
5. Have user log out and back in

### Issue: Email removal broke something

**Cause:** Custom claims not set correctly before removal

**Solution:**
1. Re-add email check to household_towing_app/firestore.rules
2. Deploy immediately: `firebase deploy --only firestore:rules`
3. Verify access restored
4. Set custom claims again
5. Test thoroughly
6. Remove email check again

---

## Support

If you get stuck:
1. Check ADMIN_SETUP_GUIDE.md
2. Review Firebase Auth docs: https://firebase.google.com/docs/auth/admin/custom-claims
3. Check household_towing_app/firestore.rules syntax
4. Review cloud functions logs: `firebase functions:log`
5. Ask team for help

---

## Sign-Off

After completing this migration, sign off:

**Name:** _________________
**Date:** _________________
**Status:** [ ] Complete [ ] Partial [ ] Rolled Back

**Notes:**
_________________________________________________
_________________________________________________
