# DualServe System Data Dictionary

### 1. Users Data Table (users)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Document ID, matches Firebase Auth UID. |
| name | String | Text | 100-255 | Full name of the user. |
| email | String | Email format | 255 | Contact email address. |
| phone | String | Numeric/String | 11-15 | Contact phone number. |
| role | String | Enum | Varies | User role: customer, provider, driver, pending_provider. |
| createdAt | Timestamp | ISO 8601 | — | Date and time the account was created. |
| profileImageUrl | String | URL | 255 | URL to the user's avatar. |

### 2. Providers Data Table (providers)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Matches the users ID. |
| specialty | String | Text | 50-100 | Primary skill or service type offered. |
| rating | Double | Decimal | 3 | Average star rating (1.0 to 5.0). |
| totalReviews | Integer | Numeric | Varies | Total number of customer reviews received. |
| isAvailable | Boolean | True/False | 1 | Toggle for whether the provider is active. |
| companyName | String | Text | 100-255 | Official name of the towing/service company. |
| isApproved | Boolean | True/False | 1 | Administrator verification status. |

### 3. Employees Data Table (Employees)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Matches the users ID. |
| providerId | String (Ref) | Alphanumeric | Varies | The provider agency they work under. |
| vehicleType | String | Text | 50 | Type of vehicle assigned (if applicable). |
| licenseNumber | String | Alphanumeric | 50 | Driver's license or certification number. |
| isAvailable | Boolean | True/False | 1 | Current duty status of the employee. |

### 4. Bookings Data Table (bookings)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Unique identifier for the booking. |
| customerId | String (Ref) | Alphanumeric | Varies | UID of the customer who made the booking. |
| assignedProviderId | String (Ref) | Alphanumeric | Varies | UID of the provider handling the booking. |
| serviceType | String | Enum | 50 | Type of service (e.g., Towing, Household). |
| status | String | Enum | 20 | pending, accepted, rejected, completed, cancelled. |
| estimatedCost | Double | Decimal | Varies | The calculated price shown to the customer. |
| createdAt | Timestamp | ISO 8601 | — | Date and time the booking was initiated. |

### 5. Tasks Data Table (tasks)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Unique identifier for the task. |
| bookingId | String (Ref) | Alphanumeric | Varies | Link to the original booking record. |
| assignedDriverId | String (Ref) | Alphanumeric | Varies | Employee/Driver dispatched to the task. |
| status | String | Enum | 20 | assigned, inProgress, completed, cancelled. |
| location | String | Text | 255 | Physical address of the service. |
| latitude | Double | Coordinate | Varies | GPS latitude for map routing. |
| longitude | Double | Coordinate | Varies | GPS longitude for map routing. |

### 6. Assets Data Table (assets)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Unique identifier for the asset. |
| ownerId | String (Ref) | Alphanumeric | Varies | Provider ID who owns the asset. |
| type | String | Enum | 20 | vehicle, tool, equipment. |
| category | String | Text | 50 | Specific classification (e.g., Tow Truck). |
| status | String | Enum | 20 | active, maintenance, inactive, inUse. |
| assignedTo | String (Ref) | Alphanumeric | Varies | Employee ID currently using the asset. |

### 7. Transactions Data Table (transactions)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Unique identifier for the transaction. |
| bookingId | String (Ref) | Alphanumeric | Varies | Associated booking reference. |
| customerId | String (Ref) | Alphanumeric | Varies | UID of the paying customer. |
| providerId | String (Ref) | Alphanumeric | Varies | UID of the receiving provider. |
| amount | Double | Decimal | Varies | Final price charged to the customer. |
| paymentStatus | String | Enum | 20 | pending, recorded, paid. |

### 8. Reviews Data Table (reviews)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Unique identifier for the review. |
| providerId | String (Ref) | Alphanumeric | Varies | UID of the reviewed provider. |
| customerId | String (Ref) | Alphanumeric | Varies | UID of the reviewer. |
| rating | Double | Decimal | 3 | Given star rating (1.0 to 5.0). |
| comment | String | Text | 1000 | Feedback text from the customer. |

### 9. Messages Data Table (messages)
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String (ID) | Alphanumeric | Varies | Unique identifier for the message. |
| bookingId | String (Ref) | Alphanumeric | Varies | Chat room/booking context ID. |
| senderId | String (Ref) | Alphanumeric | Varies | UID of the user who sent the message. |
| receiverId | String (Ref) | Alphanumeric | Varies | UID of the user receiving the message. |
| text | String | Text | 1000 | The actual chat content. |
| timestamp | Timestamp | ISO 8601 | — | Date and time the message was sent. |
