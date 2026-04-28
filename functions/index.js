const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");
const nodemailer = require("nodemailer");
const rateLimit = require("express-rate-limit");
const { getProviderWelcomeTemplate } = require("./emailTemplates");

admin.initializeApp();

// SMTP Transporter Configuration for sending credentials
const transporter = nodemailer.createTransport({
  host: process.env.SMTP_HOST || "smtp.gmail.com",
  port: parseInt(process.env.SMTP_PORT || "587"),
  secure: process.env.SMTP_SECURE === "true",
  auth: {
    user: process.env.SMTP_USER,
    pass: process.env.SMTP_PASS,
  },
});

// SECURITY: API key MUST be provided via environment variable
// NO FALLBACK - this prevents accidental hardcoded keys
const GOOGLE_PLACES_API_KEY = process.env.GOOGLE_PLACES_API_KEY;

if (!GOOGLE_PLACES_API_KEY) {
  throw new Error(
    'CRITICAL: GOOGLE_PLACES_API_KEY environment variable is not set. ' +
    'Please configure it in Firebase Cloud Functions environment.'
  );
}

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Check if user is admin (via custom claims or Firestore role)
 * Priority: Custom claims > Firestore role > Hardcoded email (dev fallback)
 */
async function isUserAdmin(uid, context) {
  try {
    // 1. Check custom claims (recommended for production)
    if (context?.auth?.token?.admin === true) {
      return { isAdmin: true, method: 'customClaims' };
    }

    // 2. Check Firestore role
    const userDoc = await admin.firestore().collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data().role === 'admin') {
      return { isAdmin: true, method: 'firestore' };
    }

    return { isAdmin: false, method: 'none' };
  } catch (error) {
    console.error('Error checking admin status:', error);
    return { isAdmin: false, method: 'error' };
  }
}

/**
 * Check rate limit for a given key (IP address or UID)
 * Allows max 10 requests per 15 minutes
 */
async function checkRateLimit(key) {
  const db = admin.firestore();
  const rateLimitDoc = db.collection('_system').doc('rateLimits').collection('keys').doc(key);

  try {
    const now = Date.now();
    const fifteenMinutesAgo = now - (15 * 60 * 1000);

    const doc = await rateLimitDoc.get();

    if (!doc.exists) {
      // First request, create entry
      await rateLimitDoc.set({
        count: 1,
        firstRequestAt: admin.firestore.FieldValue.serverTimestamp(),
        lastRequestAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { allowed: true, remaining: 9, resetIn: 15 };
    }

    const data = doc.data();
    const firstRequestTime = data.firstRequestAt.toMillis();

    // Reset if window expired
    if (firstRequestTime < fifteenMinutesAgo) {
      await rateLimitDoc.set({
        count: 1,
        firstRequestAt: admin.firestore.FieldValue.serverTimestamp(),
        lastRequestAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { allowed: true, remaining: 9, resetIn: 15 };
    }

    // Check if limit exceeded
    if (data.count >= 10) {
      const minutesUntilReset = Math.ceil((firstRequestTime + 15 * 60 * 1000 - now) / 60000);
      return {
        allowed: false,
        remaining: 0,
        resetIn: minutesUntilReset,
        retryAfter: minutesUntilReset * 60
      };
    }

    // Increment counter
    await rateLimitDoc.update({
      count: admin.firestore.FieldValue.increment(1),
      lastRequestAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      allowed: true,
      remaining: 10 - (data.count + 1),
      resetIn: Math.ceil((firstRequestTime + 15 * 60 * 1000 - now) / 60000)
    };
  } catch (error) {
    console.error('Error checking rate limit:', error);
    // On error, allow request but log it
    return { allowed: true, remaining: 10, resetIn: 15, error: true };
  }
}

/**
 * Log audit event to Firestore
 * Tracks admin actions for compliance and debugging
 */
async function logAuditEvent(event) {
  try {
    const db = admin.firestore();
    const auditLog = {
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      action: event.action,
      actor: event.actor || null,
      resourceType: event.resourceType || null,
      resourceId: event.resourceId || null,
      details: sanitizeAuditDetails(event.details || {}),
      result: event.result || 'unknown',
      statusCode: event.statusCode || null,
      errorMessage: event.errorMessage || null,
      ipAddress: event.ipAddress || null,
    };

    await db.collection('_system').doc('auditLogs').collection('entries').add(auditLog);
    console.log(`Audit log recorded: ${event.action} by ${event.actor?.uid || 'unknown'}`);
  } catch (error) {
    console.error('Error logging audit event:', error);
    // Don't throw - audit logging shouldn't block main operation
  }
}

/**
 * Sanitize sensitive data from audit logs
 */
function sanitizeAuditDetails(details) {
  const sanitized = { ...details };
  // Remove or mask sensitive fields
  if (sanitized.password) delete sanitized.password;
  if (sanitized.tempPassword) delete sanitized.tempPassword;
  if (sanitized.apiKey) delete sanitized.apiKey;
  return sanitized;
}

/**
 * Send Welcome Email with credentials setup link
 */
async function sendWelcomeEmail(email, name, resetLink) {
  // Skip if SMTP not configured
  if (!process.env.SMTP_USER || process.env.SMTP_PASS === 'your_app_password_here') {
    console.warn('SMTP not configured correctly. Skipping email send.');
    return { success: false, error: 'SMTP_NOT_CONFIGURED' };
  }

  try {
    const mailOptions = {
      from: `"${process.env.EMAIL_FROM_NAME || 'DUALSERVE'}" <${process.env.EMAIL_FROM_ADDRESS || process.env.SMTP_USER}>`,
      to: email,
      subject: "Welcome to DUALSERVE - Provider Account Setup",
      html: getProviderWelcomeTemplate(name, resetLink, process.env.DASHBOARD_URL),
    };

    const info = await transporter.sendMail(mailOptions);
    console.log("Welcome email sent: %s", info.messageId);
    return { success: true, messageId: info.messageId };
  } catch (error) {
    console.error("Error sending welcome email:", error);
    return { success: false, error: error.message };
  }
}

/**
 * Set admin role via custom claims (admin-only operation)
 * This allows migration from hardcoded email to custom claims
 */
exports.setAdminRole = functions.https.onCall(async (data, context) => {
  try {
    // Verify caller is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
    }

    const callerId = context.auth.uid;

    // Verify caller is admin
    const adminCheck = await isUserAdmin(callerId, context);
    if (!adminCheck.isAdmin) {
      console.warn(`Unauthorized setAdminRole attempt by ${callerId}`);
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only administrators can set admin roles'
      );
    }

    // Validate input
    const { targetUid } = data;
    if (!targetUid || typeof targetUid !== 'string') {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'targetUid is required and must be a string'
      );
    }

    // Verify target user exists
    const targetUser = await admin.auth().getUser(targetUid);
    if (!targetUser) {
      throw new functions.https.HttpsError(
        'not-found',
        'Target user not found'
      );
    }

    // Set custom claims
    await admin.auth().setCustomUserClaims(targetUid, { admin: true });

    // Update Firestore role for consistency
    await admin.firestore().collection('users').doc(targetUid).update({
      role: 'admin',
    });

    // Log audit event
    await logAuditEvent({
      action: 'setAdminRole',
      actor: { uid: callerId, email: context.auth.token.email },
      resourceType: 'user',
      resourceId: targetUid,
      details: { targetEmail: targetUser.email },
      result: 'success',
      statusCode: 200,
    });

    console.log(`Admin role granted to ${targetUid} by ${callerId}`);

    return {
      success: true,
      message: `Admin role set for ${targetUser.email}`,
      uid: targetUid,
    };
  } catch (error) {
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    console.error('Error in setAdminRole:', error);
    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while setting admin role'
    );
  }
});


// Cloud Function to get address predictions
exports.getAddressPredictions = functions.https.onCall(async (data, context) => {
  try {
    const input = data.input;

    if (!input || input.trim().length === 0) {
      return { predictions: [] };
    }

    // Call Google Places Autocomplete API
    const response = await axios.get(
      "https://maps.googleapis.com/maps/api/place/autocomplete/json",
      {
        params: {
          input: input,
          components: "country:ph",
          key: GOOGLE_PLACES_API_KEY,
        },
      }
    );

    if (response.data.status === "OK") {
      const predictions = response.data.predictions.map((p) => ({
        description: p.description,
        placeId: p.place_id,
      }));

      return { predictions, success: true };
    } else if (response.data.status === "ZERO_RESULTS") {
      return { predictions: [], success: true };
    } else {
      console.error("Google Places API error:", response.data.status);
      return { predictions: [], success: false, error: response.data.status };
    }
  } catch (error) {
    console.error("Error in getAddressPredictions:", error);
    return {
      predictions: [],
      success: false,
      error: error.message,
    };
  }
});

// Cloud Function: Secure Provider Creation (Admin Only)
// Validates input, creates auth user, stores in Firestore, sends password reset email
exports.createProvider = functions.https.onCall(async (data, context) => {
  let auditLog = {
    action: 'createProvider',
    actor: context.auth ? { uid: context.auth.uid, email: context.auth.token?.email } : null,
    resourceType: 'provider',
    details: { email: data.email },
    statusCode: 500,
    result: 'unknown',
  };

  try {
    // 1. AUTHENTICATION CHECK: Verify caller is authenticated
    if (!context.auth) {
      auditLog.result = 'failure';
      auditLog.statusCode = 401;
      auditLog.errorMessage = 'Unauthenticated request';
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'unauthenticated',
        'Must be logged in to create providers'
      );
    }

    const callerUid = context.auth.uid;
    const callerEmail = context.auth.token?.email;

    // 2. RATE LIMITING: Check if caller is rate limited
    const rateLimitCheck = await checkRateLimit(callerUid);
    if (!rateLimitCheck.allowed) {
      auditLog.result = 'rateLimited';
      auditLog.statusCode = 429;
      auditLog.errorMessage = `Rate limit exceeded. Reset in ${rateLimitCheck.resetIn} minutes`;
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'resource-exhausted',
        `Too many requests. Please try again in ${rateLimitCheck.resetIn} minutes.`
      );
    }

    const db = admin.firestore();

    // 3. AUTHORIZATION CHECK: Verify caller is an admin (with custom claims support)
    const adminCheck = await isUserAdmin(callerUid, context);
    if (!adminCheck.isAdmin) {
      auditLog.result = 'failure';
      auditLog.statusCode = 403;
      auditLog.errorMessage = 'User is not an admin';
      await logAuditEvent(auditLog);

      console.warn(`Unauthorized provider creation attempt by user: ${callerUid}`);
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only administrators can create providers'
      );
    }

    console.log(`Admin ${callerUid} (${adminCheck.method}) creating provider: ${data.email}`);

    // 4. INPUT VALIDATION
    const { email, name, phone, serviceType } = data;

    // Validate required fields
    if (!email || !name || !phone || !serviceType) {
      auditLog.result = 'failure';
      auditLog.statusCode = 400;
      auditLog.errorMessage = 'Missing required fields';
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'invalid-argument',
        'Email, name, phone, and serviceType are required'
      );
    }

    // Validate email format
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      auditLog.result = 'failure';
      auditLog.statusCode = 400;
      auditLog.errorMessage = 'Invalid email format';
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email format'
      );
    }

    // Validate service type
    const validServiceTypes = ['Household', 'Towing'];
    if (!validServiceTypes.includes(serviceType)) {
      auditLog.result = 'failure';
      auditLog.statusCode = 400;
      auditLog.errorMessage = 'Invalid service type';
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'invalid-argument',
        `Service type must be one of: ${validServiceTypes.join(', ')}`
      );
    }

    // Validate phone (basic check)
    if (phone.trim().length < 10) {
      auditLog.result = 'failure';
      auditLog.statusCode = 400;
      auditLog.errorMessage = 'Phone number too short';
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'invalid-argument',
        'Phone number must be at least 10 digits'
      );
    }

    console.log(`Admin ${callerUid} creating provider: ${email}`);

    // 5. CHECK IF USER ALREADY EXISTS
    let existingUser;
    try {
      existingUser = await admin.auth().getUserByEmail(email);
    } catch (error) {
      // User doesn't exist, which is what we want
      if (error.code !== 'auth/user-not-found') {
        throw error;
      }
    }

    if (existingUser) {
      auditLog.result = 'failure';
      auditLog.statusCode = 409;
      auditLog.errorMessage = 'Email already exists';
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'already-exists',
        'A user with this email already exists'
      );
    }

    // 6. CREATE FIREBASE AUTH USER
    const tempPassword = `TempPassword${Date.now()}!@#`;

    const userRecord = await admin.auth().createUser({
      email: email,
      password: tempPassword,
      displayName: name,
      emailVerified: false,
    });

    const newUserId = userRecord.uid;
    console.log(`Created auth user: ${newUserId} for email: ${email}`);

    // 7. CREATE USER DOCUMENT IN FIRESTORE
    const userData = {
      uid: newUserId,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      role: 'provider',
      isEmailVerified: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      createdBy: callerUid, // Track which admin created this provider
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('users').doc(newUserId).set(userData);
    console.log(`Created user document for: ${newUserId}`);

    // 8. CREATE PROVIDER DOCUMENT IN FIRESTORE
    const providerData = {
      uid: newUserId,
      name: name.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      serviceType: serviceType,
      specialty: '', // Provider can set this later
      status: 'available',
      rating: 5.0,
      jobsCompleted: 0,
      location: '',
      weeklySchedule: {},
      blockOutDates: [],
      maxTasksPerDay: 5,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('providers').doc(newUserId).set(providerData);
    console.log(`Created provider document for: ${newUserId}`);

    // 9. GENERATE PASSWORD RESET LINK
    const passwordResetLink = await admin.auth().generatePasswordResetLink(email);
    console.log(`Generated password reset link for: ${email}`);

    // Note: Admin SDK does not support sending emails directly.
    // We use Nodemailer with custom SMTP (configured in .env) to send the welcome email.
    const emailResult = await sendWelcomeEmail(email, name, passwordResetLink);
    
    if (emailResult.success) {
      console.log(`Welcome email successfully sent to ${email}`);
    } else {
      console.warn(`Failed to send welcome email to ${email}: ${emailResult.error}`);
      // We don't throw error here because the account WAS created successfully
    }

    // 10. LOG SUCCESSFUL AUDIT EVENT
    auditLog.result = 'success';
    auditLog.statusCode = 201;
    auditLog.resourceId = newUserId;
    auditLog.details = { ...auditLog.details, serviceType };
    await logAuditEvent(auditLog);

    return {
      success: true,
      message: emailResult.success 
        ? 'Provider created and welcome email sent.' 
        : 'Provider created, but welcome email failed to send.',
      uid: newUserId,
      email: email,
      emailSent: emailResult.success,
      passwordResetLink: passwordResetLink, // Backup link for admin
    };

  } catch (error) {
    // Handle different error types and log them
    if (error instanceof functions.https.HttpsError) {
      console.error(`HttpsError in createProvider: ${error.message}`);
      if (!auditLog.result || auditLog.result === 'unknown') {
        auditLog.result = 'failure';
        auditLog.statusCode = 500;
        auditLog.errorMessage = error.message;
        await logAuditEvent(auditLog);
      }
      throw error;
    }

    if (error.code === 'auth/email-already-exists') {
      console.error(`Email already exists: ${data.email}`);
      auditLog.result = 'failure';
      auditLog.statusCode = 409;
      auditLog.errorMessage = 'Email already registered';
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'already-exists',
        'A user with this email already exists'
      );
    }

    if (error.code === 'auth/invalid-email') {
      console.error(`Invalid email: ${data.email}`);
      auditLog.result = 'failure';
      auditLog.statusCode = 400;
      auditLog.errorMessage = 'Invalid email format';
      await logAuditEvent(auditLog);

      throw new functions.https.HttpsError(
        'invalid-argument',
        'Invalid email address'
      );
    }

    // Generic error handling
    console.error('Error in createProvider:', error);
    auditLog.result = 'failure';
    auditLog.statusCode = 500;
    auditLog.errorMessage = error.message;
    await logAuditEvent(auditLog);

    throw new functions.https.HttpsError(
      'internal',
      'An error occurred while creating the provider. Please try again.'
    );
  }
});

// Scheduled function to convert accepted bookings to tasks at midnight
exports.convertAcceptedBookingsToTasks = functions.pubsub
  .schedule('0 0 * * *') // Daily at midnight UTC
  .timeZone('Asia/Manila') // Use Asia/Manila timezone (Philippines)
  .onRun(async (context) => {
    try {
      console.log('Starting booking-to-task conversion...');

      const db = admin.firestore();
      const today = new Date();
      today.setHours(0, 0, 0, 0); // Start of today

      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1); // Start of tomorrow

      // Find all accepted bookings scheduled for today
      const bookingsSnapshot = await db
        .collection('bookings')
        .where('status', '==', 'accepted')
        .where('scheduledDate', '>=', admin.firestore.Timestamp.fromDate(today))
        .where('scheduledDate', '<', admin.firestore.Timestamp.fromDate(tomorrow))
        .get();

      console.log(`Found ${bookingsSnapshot.size} accepted bookings for today`);

      let convertedCount = 0;

      for (const bookingDoc of bookingsSnapshot.docs) {
        const booking = bookingDoc.data();

        try {
          // Create task from booking
          const taskData = {
            customerId: booking.customerId,
            assignedProviderId: booking.assignedProviderId,
            serviceType: booking.serviceType,
            location: booking.address,
            latitude: booking.latitude || 0,
            longitude: booking.longitude || 0,
            scheduledDate: booking.scheduledDate,
            description: booking.notes || '',
            status: 'assigned', // Already assigned (booking was accepted)
            priority: 'medium',
            createdAt: admin.firestore.Timestamp.now(),
            updatedAt: admin.firestore.Timestamp.now(),
            estimatedCost: booking.estimatedCost || 0,
            estimatedDurationMinutes: booking.estimatedDurationMinutes || 0,
            bookingId: bookingDoc.id, // Link to original booking
          };

          // Add task to tasks collection
          const taskRef = await db.collection('tasks').add(taskData);

          // Update booking status to converted_to_task
          await bookingDoc.ref.update({
            status: 'converted_to_task',
          });

          console.log(`Converted booking ${bookingDoc.id} to task ${taskRef.id}`);
          convertedCount++;
        } catch (error) {
          console.error(`Error converting booking ${bookingDoc.id}:`, error);
        }
      }

      console.log(`Successfully converted ${convertedCount} bookings to tasks`);
      return { convertedCount };
    } catch (error) {
      console.error('Error in convertAcceptedBookingsToTasks:', error);
      throw error;
    }
  });

// Cloud Function: Send Notification on Booking Created
exports.onBookingCreated = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snapshot, context) => {
    const booking = snapshot.data();
    const providerId = booking.assignedProviderId;

    if (!providerId) return;

    try {
      // 1. Get provider document to get FCM token
      const providerDoc = await admin.firestore().collection('users').doc(providerId).get();
      const fcmToken = providerDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for provider ${providerId}`);
        return;
      }

      // 2. Send notification
      const message = {
        notification: {
          title: 'New Service Request!',
          body: `You have a new ${booking.serviceType} request for ${booking.scheduledTime}.`,
        },
        token: fcmToken,
        data: {
          bookingId: context.params.bookingId,
          type: 'booking_request',
        },
      };

      await admin.messaging().send(message);
      console.log(`Notification sent to provider ${providerId}`);
    } catch (error) {
      console.error('Error sending notification:', error);
    }
  });

// Cloud Function: Send Notification on Booking Status Changed
exports.onBookingStatusChanged = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();

    if (newData.status === oldData.status) return;

    const customerId = newData.customerId;

    try {
      // 1. Get customer document to get FCM token
      const customerDoc = await admin.firestore().collection('users').doc(customerId).get();
      const fcmToken = customerDoc.data()?.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token for customer ${customerId}`);
        return;
      }

      let title = '';
      let body = '';

      if (newData.status === 'accepted') {
        title = 'Booking Accepted!';
        body = `Your ${newData.serviceType} request has been accepted.`;
      } else if (newData.status === 'rejected') {
        title = 'Booking Rejected';
        body = `Your ${newData.serviceType} request was unfortunately rejected.`;
      } else if (newData.status === 'converted_to_task') {
        title = 'Service Scheduled';
        body = `Your ${newData.serviceType} is scheduled and moving to tasks.`;
      } else {
        return;
      }

      // 2. Send notification
      const message = {
        notification: { title, body },
        token: fcmToken,
        data: {
          bookingId: context.params.bookingId,
          type: 'status_update',
        },
      };

      await admin.messaging().send(message);
      console.log(`Status notification sent to customer ${customerId}`);
    } catch (error) {
      console.error('Error sending status notification:', error);
    }
  });

// ============================================================================
// SCHEDULED FUNCTION: Auto-reject expired pending bookings
// Runs every 5 minutes to clean up old pending bookings
// ============================================================================
exports.autoRejectExpiredBookings = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('Starting autoRejectExpiredBookings scheduled function');

    const BOOKING_TIMEOUT_MINUTES = 30; // Auto-reject if pending for >30 minutes
    const now = Date.now();
    const timeoutMs = BOOKING_TIMEOUT_MINUTES * 60 * 1000;
    const cutoffTime = new Date(now - timeoutMs);

    try {
      // 1. Query all pending bookings created before cutoff time
      const snapshot = await admin
        .firestore()
        .collection('bookings')
        .where('status', '==', 'pending')
        .where('createdAt', '<', admin.firestore.Timestamp.fromDate(cutoffTime))
        .get();

      if (snapshot.empty) {
        console.log('No expired bookings to reject');
        return;
      }

      console.log(`Found ${snapshot.size} expired bookings to reject`);

      let rejectedCount = 0;
      const batch = admin.firestore().batch();

      // 2. Batch update all expired bookings
      snapshot.docs.forEach((doc) => {
        const bookingRef = admin.firestore().collection('bookings').doc(doc.id);
        batch.update(bookingRef, {
          status: 'expired',
          expiredAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        rejectedCount++;
      });

      // 3. Commit batch
      await batch.commit();
      console.log(`Successfully auto-rejected ${rejectedCount} expired bookings`);

      // 4. Log audit event
      await admin.firestore().collection('auditLog').add({
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        action: 'AUTO_REJECT_EXPIRED_BOOKINGS',
        count: rejectedCount,
        timeoutMinutes: BOOKING_TIMEOUT_MINUTES,
        status: 'success',
      });
    } catch (error) {
      console.error('Error in autoRejectExpiredBookings:', error);

      // Log error to audit trail
      await admin.firestore().collection('auditLog').add({
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        action: 'AUTO_REJECT_EXPIRED_BOOKINGS',
        status: 'error',
        errorMessage: error.message,
      });
    }
  });
