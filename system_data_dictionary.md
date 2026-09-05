# DualServe Complete Data Dictionary

This document outlines the complete data structures for the DualServe system.

## AssetModel Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| name | String | Text | 100-255 | Full name or title of the AssetModel. |
| category | String | ISO 8601 | — | High-level grouping classification. |
| type | AssetType | Enum/Custom | Varies | Type detail associated with the AssetModel. |
| status | AssetStatus | ISO 8601 | — | Current status lifecycle state of the AssetModel. |
| plateNumber | String | ISO 8601 | — | Plate number detail associated with the AssetModel. |
| assignedTo | String | Text | 100-255 | Assigned to detail associated with the AssetModel. |
| providerName | String | Text | 100-255 | Provider name detail associated with the AssetModel. |
| lastMaintenance | Timestamp | Varies | Varies | Last maintenance detail associated with the AssetModel. |
| nextMaintenance | Timestamp | Varies | Varies | Next maintenance detail associated with the AssetModel. |
| jobsCompleted | int | Numeric | — | Jobs completed detail associated with the AssetModel. |
| quantity | int | Numeric | — | Quantity detail associated with the AssetModel. |
| isConsumable | bool | Boolean | — | Is consumable detail associated with the AssetModel. |
| currentTaskId | String | Alphanumeric | Varies | Current task id detail associated with the AssetModel. |
| currentTaskLabel | String | Text | 100-255 | Current task label detail associated with the AssetModel. |
| ownerId | String | Alphanumeric | Varies | Owner id detail associated with the AssetModel. |

## AssetUsageLog Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| providerId | String | Alphanumeric | Varies | Reference ID to the associated Provider. |
| providerName | String | Text | 100-255 | Provider name detail associated with the AssetUsageLog. |
| taskId | String | Alphanumeric | Varies | Reference ID to the associated Task. |
| taskLabel | String | Text | 100-255 | Task label detail associated with the AssetUsageLog. |
| crewCount | int | Numeric | — | Crew count detail associated with the AssetUsageLog. |
| vehicleAssetId | String | Alphanumeric | Varies | Vehicle asset id detail associated with the AssetUsageLog. |
| vehicleName | String | Text | 100-255 | Vehicle name detail associated with the AssetUsageLog. |
| toolAssetIds | List<String> | JSON/Array | Varies | Tool asset ids detail associated with the AssetUsageLog. |
| toolNames | List<String> | JSON/Array | Varies | Tool names detail associated with the AssetUsageLog. |
| equipmentAssetIds | List<String> | JSON/Array | Varies | Equipment asset ids detail associated with the AssetUsageLog. |
| equipmentNames | List<String> | JSON/Array | Varies | Equipment names detail associated with the AssetUsageLog. |
| driverId | String | Alphanumeric | Varies | Reference ID to the assigned Driver. |
| driverName | String | Text | 100-255 | Driver name detail associated with the AssetUsageLog. |
| crewAssetIds | List<String> | JSON/Array | Varies | Crew asset ids detail associated with the AssetUsageLog. |
| crewNames | List<String> | JSON/Array | Varies | Crew names detail associated with the AssetUsageLog. |
| notes | String | Text | 100-255 | Additional context, instructions, or remarks. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |

## Booking Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| customerId | String | Alphanumeric | Varies | Reference ID to the associated Customer. |
| assignedProviderId | String | Alphanumeric | Varies | Assigned provider id detail associated with the Booking. |
| assignedDriverId | String | Alphanumeric | Varies | Assigned driver id detail associated with the Booking. |
| serviceType | String | Enum | Varies | Category or type of service requested (e.g., Towing, Household). |
| address | String | Text | 100-255 | Physical address text. |
| latitude | double | ISO 8601 | — | Geographic latitude coordinate. |
| longitude | double | Numeric | — | Geographic longitude coordinate. |
| scheduledDate | Timestamp | ISO 8601 | — | Scheduled date detail associated with the Booking. |
| scheduledTime | String | ISO 8601 | — | Scheduled time detail associated with the Booking. |
| notes | String | Text | 100-255 | Additional context, instructions, or remarks. |
| status | BookingStatus | ISO 8601 | — | Current status lifecycle state of the Booking. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |
| acceptedAt | Timestamp | ISO 8601 | — | Accepted at detail associated with the Booking. |
| providerNotes | String | Text | 100-255 | Provider notes detail associated with the Booking. |
| estimatedCost | double | ISO 8601 | — | Estimated cost detail associated with the Booking. |
| estimatedDurationMinutes | int | ISO 8601 | — | Estimated duration minutes detail associated with the Booking. |
| specificService | String | Text | 100-255 | Specific service detail associated with the Booking. |

## Driver Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| providerId | String | Alphanumeric | Varies | Reference ID to the associated Provider. |
| name | String | Text | 100-255 | Full name or title of the Driver. |
| phone | String | Numeric/String | 11-15 | Primary contact phone number. |
| email | String | Email format | 255 | Primary email address used for contact/authentication. |
| status | DriverStatus | ISO 8601 | — | Current status lifecycle state of the Driver. |
| latitude | double | ISO 8601 | — | Geographic latitude coordinate. |
| longitude | double | Numeric | — | Geographic longitude coordinate. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |

## IncidentModel Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| title | String | Text | 100-255 | Title detail associated with the IncidentModel. |
| description | String | Text | 100-255 | Description detail associated with the IncidentModel. |
| type | IncidentType | Enum/Custom | Varies | Type detail associated with the IncidentModel. |
| latitude | double | ISO 8601 | — | Geographic latitude coordinate. |
| longitude | double | Numeric | — | Geographic longitude coordinate. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |
| reportedBy | String | Text | 100-255 | Reported by detail associated with the IncidentModel. |

## Message Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| bookingId | String | Alphanumeric | Varies | Reference ID to the associated Booking. |
| senderId | String | Alphanumeric | Varies | Sender id detail associated with the Message. |
| receiverId | String | Alphanumeric | Varies | Receiver id detail associated with the Message. |
| text | String | Text | 100-255 | Text detail associated with the Message. |
| timestamp | Timestamp | ISO 8601 | — | Timestamp detail associated with the Message. |
| isRead | bool | Boolean | — | Boolean flag indicating if a message/notification has been viewed. |
| imageUrl | String | URL | 255 | Image url detail associated with the Message. |
| senderRole | String | Enum | Varies | Sender role detail associated with the Message. |

## Provider Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| name | String | Text | 100-255 | Full name or title of the Provider. |
| email | String | Email format | 255 | Primary email address used for contact/authentication. |
| phone | String | Numeric/String | 11-15 | Primary contact phone number. |
| specialty | String | Text | 100-255 | Specialty detail associated with the Provider. |
| status | ProviderStatus | ISO 8601 | — | Current status lifecycle state of the Provider. |
| rating | double | ISO 8601 | — | Average or given score (e.g., out of 5). |
| totalReviews | int | Numeric | — | Total reviews detail associated with the Provider. |
| jobsCompleted | int | Numeric | — | Jobs completed detail associated with the Provider. |
| serviceType | String | Enum | Varies | Category or type of service requested (e.g., Towing, Household). |
| serviceTypes | List<String> | JSON/Array | Varies | Service types detail associated with the Provider. |
| blockOutDates | List<String> | ISO 8601 | — | Block out dates detail associated with the Provider. |
| maxTasksPerDay | int | Numeric | — | Max tasks per day detail associated with the Provider. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |
| updatedAt | Timestamp | ISO 8601 | — | Timestamp of when the record was last modified. |
| latitude | double | ISO 8601 | — | Geographic latitude coordinate. |
| longitude | double | Numeric | — | Geographic longitude coordinate. |
| bio | String | Text | 100-255 | Bio detail associated with the Provider. |
| licenseNumber | String | Text | 100-255 | License number detail associated with the Provider. |
| yearsOfExperience | int | Numeric | — | Years of experience detail associated with the Provider. |
| totalEarnings | double | Numeric | — | Total earnings detail associated with the Provider. |
| totalRides | int | Numeric | — | Total rides detail associated with the Provider. |
| lastLocation | String | ISO 8601 | — | Last location detail associated with the Provider. |
| profileImageUrl | String | URL | 255 | Profile image url detail associated with the Provider. |
| documentsVerified | bool | Boolean | — | Documents verified detail associated with the Provider. |
| backgroundCheckPassed | bool | Boolean | — | Background check passed detail associated with the Provider. |
| businessPermitUrl | String | URL | 255 | Business permit url detail associated with the Provider. |
| governmentIdUrl | String | URL | 255 | Government id url detail associated with the Provider. |
| verificationStatus | String | ISO 8601 | — | Verification status detail associated with the Provider. |
| rejectionReason | String | Text | 100-255 | Rejection reason detail associated with the Provider. |
| inviteCode | String | Text | 100-255 | Invite code detail associated with the Provider. |
| serviceArea | String | Text | 100-255 | Service area detail associated with the Provider. |

## ProviderPricing Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| providerId | String | Alphanumeric | Varies | Reference ID to the associated Provider. |
| cleaningMultiplier | double | Numeric | — | Cleaning multiplier detail associated with the ProviderPricing. |
| towingMultiplier | double | Numeric | — | Towing multiplier detail associated with the ProviderPricing. |
| useNightDifferential | bool | Boolean | — | Use night differential detail associated with the ProviderPricing. |
| notes | String | Text | 100-255 | Additional context, instructions, or remarks. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |
| updatedAt | Timestamp | ISO 8601 | — | Timestamp of when the record was last modified. |
| nightSurchargeStartHour | int | Numeric | — | Night surcharge start hour detail associated with the ProviderPricing. |
| nightSurchargeEndHour | int | Numeric | — | Night surcharge end hour detail associated with the ProviderPricing. |
| nightSurchargePercent | double | Numeric | — | Night surcharge percent detail associated with the ProviderPricing. |

## Review Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| bookingId | String | Alphanumeric | Varies | Reference ID to the associated Booking. |
| customerId | String | Alphanumeric | Varies | Reference ID to the associated Customer. |
| providerId | String | Alphanumeric | Varies | Reference ID to the associated Provider. |
| rating | double | ISO 8601 | — | Average or given score (e.g., out of 5). |
| comment | String | Text | 100-255 | Comment detail associated with the Review. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |

## ServiceDefinition Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| type | ServicePricingType | Enum/Custom | Varies | Type detail associated with the ServiceDefinition. |
| flatRatePrice | double | ISO 8601 | — | Flat rate price detail associated with the ServiceDefinition. |
| minPrice | double | Numeric | — | Min price detail associated with the ServiceDefinition. |
| pricePerSqm | double | Numeric | — | Price per sqm detail associated with the ServiceDefinition. |
| minSqm | int | Numeric | — | Min sqm detail associated with the ServiceDefinition. |
| addons | List<ServiceAddon> | JSON/Array | Varies | Addons detail associated with the ServiceDefinition. |
| subtypes | List<ServiceSubtype> | JSON/Array | Varies | Subtypes detail associated with the ServiceDefinition. |
| category | String | ISO 8601 | — | High-level grouping classification. |

## ServiceAddon Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| name | String | Text | 100-255 | Full name or title of the ServiceAddon. |
| price | double | Numeric | — | Price detail associated with the ServiceAddon. |
| pricingType | String | Enum | Varies | Pricing type detail associated with the ServiceAddon. |

## ServiceSubtype Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| name | String | Text | 100-255 | Full name or title of the ServiceSubtype. |
| price | double | Numeric | — | Price detail associated with the ServiceSubtype. |

## TaskMilestone Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| title | String | Text | 100-255 | Title detail associated with the TaskMilestone. |
| isCompleted | bool | Boolean | — | Boolean flag indicating successful completion. |
| completedAt | Timestamp | ISO 8601 | — | Completed at detail associated with the TaskMilestone. |

## Task Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| customerId | String | Alphanumeric | Varies | Reference ID to the associated Customer. |
| assignedProviderId | String | Alphanumeric | Varies | Assigned provider id detail associated with the Task. |
| assignedDriverId | String | Alphanumeric | Varies | Assigned driver id detail associated with the Task. |
| assignedDriverName | String | Text | 100-255 | Assigned driver name detail associated with the Task. |
| serviceType | String | Enum | Varies | Category or type of service requested (e.g., Towing, Household). |
| location | String | ISO 8601 | — | Location detail associated with the Task. |
| latitude | double | ISO 8601 | — | Geographic latitude coordinate. |
| longitude | double | Numeric | — | Geographic longitude coordinate. |
| scheduledDate | Timestamp | ISO 8601 | — | Scheduled date detail associated with the Task. |
| description | String | Text | 100-255 | Description detail associated with the Task. |
| status | TaskStatus | ISO 8601 | — | Current status lifecycle state of the Task. |
| priority | TaskPriority | Enum/Custom | Varies | Priority detail associated with the Task. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |
| updatedAt | Timestamp | ISO 8601 | — | Timestamp of when the record was last modified. |
| estimatedCost | double | ISO 8601 | — | Estimated cost detail associated with the Task. |
| finalCost | double | Numeric | — | Total computed final cost charged to the customer. |
| estimatedDurationMinutes | int | ISO 8601 | — | Estimated duration minutes detail associated with the Task. |
| bookingId | String | Alphanumeric | Varies | Reference ID to the associated Booking. |
| completedImageUrl | String | URL | 255 | Completed image url detail associated with the Task. |
| completedAt | Timestamp | ISO 8601 | — | Completed at detail associated with the Task. |
| barangay | String | Text | 100-255 | Barangay detail associated with the Task. |
| zone | String | Text | 100-255 | Zone detail associated with the Task. |
| landmarkDescription | String | Text | 100-255 | Landmark description detail associated with the Task. |
| problemCategory | String | ISO 8601 | — | Problem category detail associated with the Task. |
| issueCategory | String | ISO 8601 | — | Issue category detail associated with the Task. |
| adminFee | double | Numeric | — | Admin fee detail associated with the Task. |
| assignedTruckId | String | Alphanumeric | Varies | Assigned truck id detail associated with the Task. |
| assignedTruckName | String | Text | 100-255 | Assigned truck name detail associated with the Task. |
| assignedPersonnelIds | List<String> | JSON/Array | Varies | Assigned personnel ids detail associated with the Task. |
| assignedPersonnelNames | List<String> | JSON/Array | Varies | Assigned personnel names detail associated with the Task. |
| preTowPhotoUrls | List<String> | URL | 255 | Pre tow photo urls detail associated with the Task. |
| customerSignatureUrl | String | URL | 255 | Customer signature url detail associated with the Task. |
| milestones | List<TaskMilestone> | JSON/Array | Varies | Milestones detail associated with the Task. |
| progress | double | Numeric | — | Completion percentage or fractional progress (0.0 to 1.0). |

## Transaction Data Table
| FIELD NAME | DATA TYPE | FORMAT | LENGTH | DESCRIPTION |
| :--- | :--- | :--- | :--- | :--- |
| id | String | Alphanumeric | Varies | Unique identifier for this document. |
| taskId | String | Alphanumeric | Varies | Reference ID to the associated Task. |
| bookingId | String | Alphanumeric | Varies | Reference ID to the associated Booking. |
| customerId | String | Alphanumeric | Varies | Reference ID to the associated Customer. |
| providerId | String | Alphanumeric | Varies | Reference ID to the associated Provider. |
| serviceType | String | Enum | Varies | Category or type of service requested (e.g., Towing, Household). |
| specificService | String | Text | 100-255 | Specific service detail associated with the Transaction. |
| basePrice | double | Numeric | — | Starting base cost before additions or multipliers. |
| distanceTraveled | double | Numeric | — | Distance traveled detail associated with the Transaction. |
| costPerKm | double | Numeric | — | Cost per km detail associated with the Transaction. |
| distanceSurcharge | double | Numeric | — | Distance surcharge detail associated with the Transaction. |
| finalCost | double | Numeric | — | Total computed final cost charged to the customer. |
| adminFee | double | Numeric | — | Admin fee detail associated with the Transaction. |
| additionalCost | double | Numeric | — | Additional cost detail associated with the Transaction. |
| status | TransactionStatus | ISO 8601 | — | Current status lifecycle state of the Transaction. |
| paymentStatus | PaymentStatus | ISO 8601 | — | Payment status detail associated with the Transaction. |
| providerNotes | String | Text | 100-255 | Provider notes detail associated with the Transaction. |
| completedAt | Timestamp | ISO 8601 | — | Completed at detail associated with the Transaction. |
| recordedAt | Timestamp | ISO 8601 | — | Recorded at detail associated with the Transaction. |
| createdAt | Timestamp | ISO 8601 | — | Timestamp of when the record was initially created. |

