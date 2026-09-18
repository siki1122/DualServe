# Table 25
**White-Box Testing of the Alpha Testing of Household Towing App (Comprehensive)**

| Test Case ID | Tested Code Segment | Test Description | Input Values | Expected Behavior | Actual Behavior | Result |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| TC-001 | `Component` | FormValidators - validateRequired should reject null value | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-002 | `Component` | FormValidators - validateRequired should reject empty value | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-003 | `Component` | FormValidators - validateRequired should accept valid value | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-004 | `Component` | FormValidators - validateEmail should reject empty email | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-005 | `Component` | FormValidators - validateEmail should reject invalid email | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-006 | `Component` | FormValidators - validateEmail should accept valid email | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-007 | `Component` | FormValidators - validatePhone should reject empty phone number | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-008 | `Component` | FormValidators - validatePhone should reject invalid phone number | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-009 | `Component` | FormValidators - validatePhone should accept valid phone number | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-010 | `Component` | FormValidators - validateAddress should reject empty address | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-011 | `Component` | FormValidators - validateAddress should reject address shorter than 5 characters | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-012 | `Component` | FormValidators - validateAddress should accept valid address | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-013 | `Component` | FormValidators - validatePassword should reject empty password | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-014 | `Component` | FormValidators - validatePassword should reject password shorter than 8 characters | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-015 | `Component` | FormValidators - validatePassword should reject password without letters | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-016 | `Component` | FormValidators - validatePassword should reject password without numbers | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-017 | `Component` | FormValidators - validatePassword should accept valid password | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-018 | `Component` | FormValidators - validateName should reject empty name | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-019 | `Component` | FormValidators - validateName should reject name containing invalid characters | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-020 | `Component` | FormValidators - validateName should accept valid name | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-021 | `Component` | FormValidators - validateNumber should reject empty number | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-022 | `Component` | FormValidators - validateNumber should reject invalid number | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-023 | `Component` | FormValidators - validateNumber should accept valid number | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-024 | `Component` | FormValidators - validateMinValue should return required error for empty value | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-025 | `Component` | FormValidators - validateMinValue should return number error for invalid value | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-026 | `Component` | FormValidators - validateMinValue should reject value below minimum | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-027 | `Component` | FormValidators - validateMinValue should accept value equal to minimum | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-028 | `Component` | FormValidators - validateMinValue should accept value above minimum | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-029 | `Component` | FormValidators - validatePasswordMatch should reject empty confirmation | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-030 | `Component` | FormValidators - validatePasswordMatch should reject different passwords | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-031 | `Component` | FormValidators - validatePasswordMatch should accept matching passwords | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-032 | `Model` | AssetModel Tests should parse from Firestore correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-033 | `Model` | AssetModel Tests toFirestore should convert to Map correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-034 | `Component` | AssetUsageLog Tests should parse from Firestore correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-035 | `Model` | BookingModel Tests should parse from Firestore correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-036 | `Model` | BookingModel Tests toFirestore should convert to Map correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-037 | `Model` | BookingModel Tests copyWith should update fields correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-038 | `Model` | DriverModel Tests should parse from Firestore correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-039 | `Model` | DriverModel Tests toFirestore should convert to Map correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-040 | `Model` | DriverModel Tests copyWith should update fields correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-041 | `Model` | ProviderModel Tests should parse from Firestore correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-042 | `Model` | ProviderModel Tests toFirestore should convert to Map correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-043 | `Model` | ProviderModel Tests isBlockedOnDate logic works | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-044 | `Model` | TaskModel Tests should parse from Firestore correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-045 | `Model` | TaskModel Tests toFirestore should convert to Map correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-046 | `Model` | TaskModel Tests _calculateProgress and defaultMilestones logic | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-047 | `Model` | TransactionModel Tests should parse from Firestore correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-048 | `Model` | TransactionModel Tests toFirestore should convert to Map correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-049 | `Provider` | UserProvider White-Box Tests (Mockito) - loadCurrentUserData clears data if user is null | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-050 | `Provider` | UserProvider White-Box Tests (Mockito) - loadCurrentUserData fetches provider profile when role is provider | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-051 | `Provider` | UserProvider White-Box Tests (Mockito) - loadCurrentUserData fetches driver profile when role is driver | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-052 | `Provider` | UserProvider White-Box Tests (Mockito) - toggleAvailability updates optimistic UI and calls backend | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-053 | `Provider` | UserProvider White-Box Tests (Mockito) - toggleTheme switches between dark and light mode | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-054 | `Provider` | UserProvider White-Box Tests (Mockito) - clear resets all state variables | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-055 | `Model` | ProviderPricing Model Tests (White Box Testing) should create ProviderPricing with default values | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-056 | `Model` | ProviderPricing Model Tests (White Box Testing) getMultiplier should return cleaning multiplier for Household | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-057 | `Model` | ProviderPricing Model Tests (White Box Testing) getMultiplier should return cleaning multiplier for Cleaning | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-058 | `Model` | ProviderPricing Model Tests (White Box Testing) getMultiplier should return towing multiplier for Towing | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-059 | `Model` | ProviderPricing Model Tests (White Box Testing) getMultiplier should return 1.0 for unknown service type | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-060 | `Model` | ProviderPricing Model Tests (White Box Testing) isNightTime should return false when night differential is disabled | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-061 | `Model` | ProviderPricing Model Tests (White Box Testing) isNightTime should return true after start hour for overnight span | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-062 | `Model` | ProviderPricing Model Tests (White Box Testing) isNightTime should return true before end hour for overnight span | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-063 | `Model` | ProviderPricing Model Tests (White Box Testing) isNightTime should return false during daytime for overnight span | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-064 | `Model` | ProviderPricing Model Tests (White Box Testing) isNightTime should handle daytime span correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-065 | `Model` | ProviderPricing Model Tests (White Box Testing) isNightTime should return false outside daytime span | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-066 | `Model` | ProviderPricing Model Tests (White Box Testing) calculateNightDifferential should apply custom surcharge percent | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-067 | `Model` | ProviderPricing Model Tests (White Box Testing) calculateNightDifferential should return zero during daytime | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-068 | `Model` | ProviderPricing Model Tests (White Box Testing) copyWith should update specified fields | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-069 | `Model` | ProviderPricing Model Tests (White Box Testing) copyWith should preserve original fields when no changes are supplied | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-070 | `Model` | ProviderPricing Model Tests (White Box Testing) toFirestore should convert pricing to Firestore data | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-071 | `Model` | ProviderPricing Model Tests (White Box Testing) toFirestore should store null when updatedAt is null | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-072 | `Model` | ProviderPricing Model Tests (White Box Testing) toString should return formatted string representation | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-073 | `Widget` | LoginScreen Widget Tests Should display login form fields | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-074 | `Widget` | LoginScreen Widget Tests Should display login form fields [E] | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-075 | `Widget` | RegisterScreen Widget Tests (White Box) Should display registration form fields | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-076 | `Service` | BillingService Tests recordTransaction creates new transaction | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-077 | `Service` | BookingService Tests createBooking adds new booking to collection | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-078 | `Service` | BookingService Tests rescheduleBooking updates date and time | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-079 | `Service` | GoogleAuthService Tests signOut calls both FirebaseAuth and GoogleSignIn signOut | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-080 | `Service` | GoogleAuthService Tests signInWithGoogle handles null user | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-081 | `Service` | LocationService Tests calculateDistance returns distance in km | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-082 | `Service` | LocationService Tests isWithinRadius returns true if within radius | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-083 | `Service` | LocationService Tests isWithinRadius returns false if outside radius | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-084 | `Service` | LocationService Tests calculateETA returns reasonable minutes | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-085 | `Service` | RoutingService Tests decodePolyline decodes correctly | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-086 | `Service` | RoutingService Tests getRoute handles successful OSRM response | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-087 | `Service` | RoutingService Tests getRoute handles failed response | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-088 | `Service` | TaskService Tests getTask returns data if exists | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-089 | `Service` | TaskService Tests createTask adds new task | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-090 | `Service` | TaskService Tests updateTaskStatus updates status | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-091 | `Service` | TaskService Tests deleteTask removes unassigned task | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-092 | `Service` | TaskService Tests deleteTask throws if assigned | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-093 | `Service` | UserService Tests getUserProfile returns data if exists | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-094 | `Service` | UserService Tests getUserProfile returns null if not exists | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-095 | `Service` | UserService Tests getProviderProfile returns data if exists | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-096 | `Service` | UserService Tests updateProviderAvailability updates data | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-097 | `Service` | UserService Tests updateProviderRating updates rating | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-098 | `Service` | UserService Tests updateProviderRating throws on invalid rating | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-099 | `Component` | pricing supports canonical and legacy household service names | Mock Input | Should execute properly | Matches expected output | Pass |
| TC-100 | `Component` | price formatting is stable ASCII text | Mock Input | Should execute properly | Matches expected output | Pass |
