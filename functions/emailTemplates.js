/**
 * Email Templates for DUALSERVE
 * Professional HTML templates for transactional emails
 */

/**
 * Provider Welcome Email Template
 * Sent when a new provider account is created
 */
function getProviderWelcomeTemplate(providerName, resetLink, dashboardUrl) {
  return `
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Welcome to DUALSERVE - Provider Account Setup</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      line-height: 1.6;
      color: #333;
      background-color: #f5f5f5;
      margin: 0;
      padding: 0;
    }
    .container {
      max-width: 600px;
      margin: 20px auto;
      background-color: #ffffff;
      border-radius: 8px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.1);
      overflow: hidden;
    }
    .header {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 40px 20px;
      text-align: center;
    }
    .header h1 {
      margin: 0;
      font-size: 28px;
      font-weight: 600;
    }
    .content {
      padding: 40px;
    }
    .greeting {
      font-size: 18px;
      font-weight: 500;
      margin-bottom: 20px;
      color: #333;
    }
    .section {
      margin-bottom: 30px;
    }
    .section h2 {
      color: #667eea;
      font-size: 16px;
      font-weight: 600;
      margin-top: 0;
      margin-bottom: 15px;
      text-transform: uppercase;
      letter-spacing: 0.5px;
    }
    .section p {
      margin: 10px 0;
      color: #666;
      font-size: 14px;
    }
    .cta-button {
      display: inline-block;
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
      padding: 12px 30px;
      border-radius: 4px;
      text-decoration: none;
      font-weight: 600;
      margin: 15px 0;
      transition: opacity 0.3s;
    }
    .cta-button:hover {
      opacity: 0.9;
    }
    .reset-link-box {
      background-color: #f8f9fa;
      padding: 15px;
      border-left: 4px solid #667eea;
      margin: 15px 0;
      border-radius: 4px;
    }
    .reset-link-box p {
      margin: 0 0 10px 0;
      font-size: 13px;
      color: #666;
    }
    .reset-link {
      word-break: break-all;
      font-family: 'Courier New', monospace;
      font-size: 12px;
      color: #667eea;
      background-color: white;
      padding: 8px;
      border-radius: 3px;
      display: block;
    }
    .steps {
      list-style: none;
      padding: 0;
      margin: 15px 0;
    }
    .steps li {
      padding: 10px 0;
      padding-left: 30px;
      position: relative;
      color: #666;
      font-size: 14px;
    }
    .steps li:before {
      content: attr(data-step);
      position: absolute;
      left: 0;
      top: 8px;
      background: #667eea;
      color: white;
      width: 22px;
      height: 22px;
      border-radius: 50%;
      text-align: center;
      line-height: 22px;
      font-weight: 600;
      font-size: 12px;
    }
    .footer {
      background-color: #f8f9fa;
      padding: 20px;
      text-align: center;
      border-top: 1px solid #e9ecef;
    }
    .footer p {
      margin: 5px 0;
      font-size: 12px;
      color: #999;
    }
    .footer a {
      color: #667eea;
      text-decoration: none;
    }
    .security-notice {
      background-color: #fff3cd;
      border: 1px solid #ffeaa7;
      border-radius: 4px;
      padding: 12px;
      margin: 20px 0;
      font-size: 13px;
      color: #856404;
    }
    .security-notice strong {
      color: #721c24;
    }
  </style>
</head>
<body>
  <div class="container">
    <!-- Header -->
    <div class="header">
      <h1>🚀 Welcome to DUALSERVE</h1>
      <p style="margin: 5px 0; opacity: 0.9;">Your Provider Account is Ready</p>
    </div>

    <!-- Content -->
    <div class="content">
      <div class="greeting">Hi ${providerName},</div>

      <p style="color: #666; font-size: 15px;">
        Welcome to <strong>DUALSERVE</strong>! Your service provider account has been created and is ready to use.
        Follow the steps below to set up your password and start accepting jobs.
      </p>

      <!-- Reset Password Section -->
      <div class="section">
        <h2>Step 1: Set Your Password</h2>
        <p>Click the button below to create a secure password for your account:</p>
        <center>
          <a href="${resetLink}" class="cta-button" style="display: inline-block;">Set Password Now</a>
        </center>
        <p style="font-size: 13px; color: #999; text-align: center; margin-top: 10px;">
          Link expires in 24 hours
        </p>
      </div>

      <!-- Getting Started Section -->
      <div class="section">
        <h2>Step 2: Get Started</h2>
        <ol class="steps">
          <li data-step="1"><strong>Complete Your Profile:</strong> Add your business details, service specialties, and pricing</li>
          <li data-step="2"><strong>Set Your Availability:</strong> Define your working hours and days</li>
          <li data-step="3"><strong>Start Accepting Jobs:</strong> Begin accepting booking requests from customers</li>
        </ol>
      </div>

      <!-- Security Notice -->
      <div class="security-notice">
        <strong>🔐 Security Reminder:</strong> Your password reset link is unique and expires in 24 hours.
        Never share your account credentials with anyone. DUALSERVE support staff will never ask for your password.
      </div>

      <!-- Dashboard Link Section -->
      <div class="section">
        <h2>Access Your Dashboard</h2>
        <p>Once you've set your password, visit your provider dashboard to manage your account:</p>
        <center>
          <a href="${dashboardUrl}" class="cta-button">Open Dashboard</a>
        </center>
      </div>

      <!-- Support Section -->
      <div class="section">
        <h2>Need Help?</h2>
        <p>
          If you experience any issues setting up your account or have questions, our support team is here to help:
        </p>
        <ul style="margin: 10px 0; padding-left: 20px; font-size: 14px; color: #666;">
          <li>Email: <a href="mailto:support@dualserv.com" style="color: #667eea;">support@dualserv.com</a></li>
          <li>Phone: <a href="tel:+1234567890" style="color: #667eea;">+1 (234) 567-890</a></li>
          <li>Hours: Monday - Friday, 9 AM - 6 PM (EST)</li>
        </ul>
      </div>

      <!-- Terms Section -->
      <p style="font-size: 13px; color: #999; margin-top: 30px; padding-top: 20px; border-top: 1px solid #eee;">
        By using DUALSERVE, you agree to our Terms of Service and Privacy Policy.
        Please review them <a href="https://dualserv.com/terms" style="color: #667eea;">here</a>.
      </p>
    </div>

    <!-- Footer -->
    <div class="footer">
      <p>© ${new Date().getFullYear()} DUALSERVE. All rights reserved.</p>
      <p>
        <a href="https://dualserv.com">Website</a> •
        <a href="https://dualserv.com/faq">FAQ</a> •
        <a href="https://dualserv.com/contact">Contact Us</a>
      </p>
      <p style="color: #ccc;">Household & Towing Services Platform</p>
    </div>
  </div>
</body>
</html>
  `;
}

/**
 * Generic Email Error Template
 * Fallback for when custom email fails
 */
function getFallbackEmailNotice() {
  return `
<!DOCTYPE html>
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; }
    .container { max-width: 600px; margin: 20px auto; }
    .notice { background-color: #f8f9fa; padding: 20px; border-radius: 4px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="notice">
      <h2>Provider Account Created ✓</h2>
      <p>A new provider account has been created. The user should receive a password reset email from Firebase Authentication.</p>
    </div>
  </div>
</body>
</html>
  `;
}

module.exports = {
  getProviderWelcomeTemplate,
  getFallbackEmailNotice,
};
