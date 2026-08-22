# DualServe: System Description

## 1. System Overview
**DualServe** is an integrated mobile application designed to bridge the gap between customers in need of immediate assistance and verified service providers. The platform focuses on two primary service categories: **Household Services** (e.g., expert cleaning, home maintenance) and **Emergency Towing**. By combining these distinct but essential services into a single platform, DualServe provides a centralized hub for users to quickly request, track, and manage service bookings.

## 2. Target Users
The system is built to cater to three specific user roles, each with a tailored interface and access level:

*   **Customers:** Users who need household or towing services. They can browse services, request assistance, track providers in real-time, and communicate seamlessly through the app.
*   **Service Providers:** Independent contractors or agency workers who fulfill service requests. They can toggle their availability, accept or decline nearby tasks, manage their assigned assets (e.g., towing vehicles, cleaning equipment), and update their service progress.
*   **Administrators:** Platform managers who oversee operations. They verify provider credentials (e.g., government IDs, business permits), manage overall system assets, monitor active transactions, and handle dispute resolution or support requests.

## 3. Key Features & Functionality

### For Customers:
*   **Categorized Booking System:** Intuitive interface to book either Household or Towing services, providing specific details (location, issue type) for accurate estimates.
*   **Real-Time Tracking & Updates:** A live map tracking system that allows customers to see the exact location of their assigned towing provider or the progress status of a household service.
*   **In-App Chat:** Real-time messaging with the assigned provider to clarify details or provide instructions.
*   **Live Notifications:** Instant push notifications and in-app alerts for booking status changes (e.g., "Provider Accepted", "En Route", "Completed").

### For Service Providers:
*   **Availability Toggle:** A simple online/offline switch allowing providers to control when they receive new task assignments.
*   **Task Management:** A dashboard to view available tasks nearby, accept jobs, and update the status of ongoing tasks.
*   **Asset Management Integration:** Providers can log equipment or vehicles they are currently using for a task, ensuring proper tracking of company resources.
*   **Earning & Performance Dashboard:** A dedicated view showing daily earnings, completed jobs, and pending tasks.

### For Administrators:
*   **Provider Verification:** A robust approval workflow for reviewing uploaded documents (permits, IDs) to ensure only legitimate providers can accept jobs.
*   **Task & Asset Assignment:** Manual overriding or assignment of specific tasks to specific providers, as well as tracking which assets (tools, vehicles) are currently in use.

## 4. Technical Architecture

The DualServe platform utilizes a modern, serverless architecture to ensure high responsiveness, scalability, and cross-platform compatibility:

*   **Frontend Framework:** Built using **Flutter** (Dart), allowing for a seamless, native-feeling application across both Android and iOS devices from a single codebase.
*   **Backend & Database:** Powered by **Firebase**:
    *   **Cloud Firestore:** A NoSQL real-time database managing collections such as `users`, `providers`, `bookings`, `tasks`, `assets`, and `notifications`.
    *   **Firebase Authentication:** Secure user login supporting both standard Email/Password authentication and Single Sign-On (Google Auth).
    *   **Firebase Storage:** Handles the secure storage and retrieval of provider verification documents and profile images.
*   **State Management:** Utilizes `Provider` for efficient, reactive state management across the application.
*   **Maps & Routing:** Integration with mapping services to provide real-time location tracking and routing capabilities for the towing module.

## 5. Security & Access Control
The system enforces strict data privacy through **Firestore Security Rules**, ensuring that:
*   Customers can only view their own bookings, personal data, and notifications.
*   Providers can only access tasks assigned to them or available in their pool, and update their own profiles.
*   Administrators hold elevated privileges to read, write, and delete records system-wide for moderation purposes.

---
*Document prepared for the DualServe Pre-Oral Defense.*
