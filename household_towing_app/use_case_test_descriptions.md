### White-Box Testing Results by Use Case

**1. Authentication & Security**
The Authentication & Security use case underwent rigorous testing to validate secure access controls and user session management. The test suite verified the successful integration of Google Sign-In and standard email/password authentication via Firebase Auth. The system demonstrated a 100% success rate in handling both valid login attempts and securely rejecting unauthorized or malformed credentials. Additionally, session termination protocols (logout) were verified to correctly wipe local cache and sever active Firebase connections, ensuring high data security.

**2. User Registration & Profiles**
Testing for this use case focused on the reliable creation and retrieval of user profiles across different system roles (Customer, Driver, and Service Provider). The tests successfully validated that profile data maps seamlessly from frontend input forms to the backend Firestore database. All role-based data models were instantiated correctly, confirming that the application can successfully differentiate privileges and interface layouts based on user registration types.

**3. Booking & Task Management**
The core operational loop of the application—Booking and Task Management—was extensively tested for reliability and state accuracy. The test cases simulated the complete lifecycle of a booking request, from initial creation to status updates (e.g., 'pending' to 'accepted' to 'completed'). The system correctly applied Firestore database writes and successfully managed state transitions without data loss, proving the backend's capability to handle concurrent towing service requests robustly.

**4. Asset & Provider Management**
This use case evaluated the system's ability to manage dynamic operational data, specifically towing vehicles (assets) and personnel. Tests successfully validated that the system correctly maps nested JSON asset data from the database into strict Dart object models. Boundary constraints were also rigorously tested; for example, the system correctly triggered expected exceptions when invalid provider ratings (e.g., below 0 or above 5) were submitted, ensuring strict database integrity.

**5. Billing & Pricing Engine**
The financial and billing components were tested for mathematical accuracy and conditional logic processing. The tests verified the successful execution of dynamic pricing algorithms, such as calculating precise cost variations based on distance and automatically applying custom percentage surcharges for overnight or emergency towing scenarios. All transaction records were generated accurately, proving the reliability of the application's revenue calculation engine.

**6. Geolocation & Routing**
Geolocation logic is critical for a towing application. The test suite verified the underlying algorithms responsible for calculating accurate point-to-point distances between drivers and customers. Boundary tests confirmed the system accurately triggers alerts when a target coordinate falls outside a provider's predefined operational service radius. Furthermore, OSRM routing data was successfully parsed and decoded, validating the foundation for live map navigation.

**7. Form Data Validation**
To ensure high data quality at the presentation layer, the application's form validators were subjected to extensive positive and negative boundary testing. The system achieved a 100% pass rate in correctly identifying and rejecting malformed emails, short passwords, invalid phone numbers, and empty required fields. Conversely, valid inputs were processed seamlessly, confirming the application provides robust defensive UX against user input errors.

**8. Core System Components**
General system architecture and underlying utility models were evaluated for structural integrity. Tests confirmed that data formatting (such as converting timestamps to readable text and formatting price strings) executed flawlessly across the board. The system successfully managed backward compatibility for legacy naming conventions, confirming that the application's foundational infrastructure is stable and scalable.
