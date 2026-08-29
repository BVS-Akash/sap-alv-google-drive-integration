# SAP ALV → Google Drive Integration

Integration for exporting SAP ALV data to a user's Google Drive using OAuth 2.0 and the Google Drive API.

---

## 1. Overview

This project implements an SAP integration where a SAP user can export an ALV result to Google Drive.

Target business scenario:

```text
SAP User
   │
   ▼
Run ALV Report
   │
   ▼
Export to Google Drive
   │
   ▼
SAP Google Drive Integration
   │
   │ OAuth 2.0
   ▼
Google Drive API
   │
   ▼
User's Google Drive
```

The initial implementation intentionally starts with a simple test file before introducing ALV/XLSX generation.

Initial milestone:

```text
ABAP
  ↓
Create SAP_GDRIVE_INT.TXT
  ↓
Authenticate with Google
  ↓
Upload to Google Drive
  ↓
Read the uploaded file
```

Final direction:

```text
SAP ALV
   ↓
Export to Google Drive
   ↓
Generate CSV/XLSX
   ↓
Google Drive API
   ↓
User's Google Drive
```

---

# 2. Business Scenario

A user runs an SAP report and receives an ALV output.

Instead of downloading the ALV manually:

```text
SAP ALV
   ↓
Download
   ↓
Save locally
   ↓
Open Google Drive
   ↓
Upload manually
```

the user should be able to:

```text
SAP ALV
   ↓
Export to Google Drive
   ↓
Google Drive
```

The objective is to remove the manual download/upload step.

---

# 3. User-Specific Drive Model

The selected design is **user-specific Google Drive authorization**.

Each SAP user can authorize the same Google OAuth application to access their Google Drive.

Example:

```text
                    One Google OAuth Application
                       Client ID + Client Secret
                                  │
                 ┌────────────────┼────────────────┐
                 │                │                │
                 ▼                ▼                ▼
              SAP User A      SAP User B       SAP User C
                 │                │                │
              OAuth A          OAuth B          OAuth C
                 │                │                │
                 ▼                ▼                ▼
              Drive A          Drive B          Drive C
```

The Google Client ID and Client Secret identify the application.

They are **not created separately for every user**.

The user's OAuth authorization determines which Google account/Drive the application is acting on behalf of.

---

# 4. Authentication Architecture

Authentication uses:

```text
OAuth 2.0
```

The conceptual flow is:

```text
SAP User
   │
   ▼
SAP Application
   │
   ▼
Google OAuth Authorization
   │
   ▼
Google Login
   │
   ▼
User Consent
   │
   ▼
Authorization Code
   │
   ▼
Access Token
   │
   ▼
Google Drive API
```

The application should not ask the user to provide their Google password.

---

# 5. OAuth Application Model

One Google OAuth application is used for the SAP integration.

```text
Google Cloud Project
        │
        ▼
Google OAuth Client
        │
        ├── Client ID
        └── Client Secret
```

The same OAuth client can support multiple authorized users, subject to the Google OAuth application configuration and organization's policies.

Example:

```text
SAP User        Google Account       Authorization
----------------------------------------------------
AKASH           userA@gmail.com      OAuth Token A
JOHN            userB@gmail.com      OAuth Token B
PRIYA           userC@gmail.com      OAuth Token C
```

---

# 6. Internal vs External Application

The OAuth application's audience depends on the organization.

## Internal

Use Internal when SAP users belong to the same Google Workspace organization.

Example:

```text
user1@company.com
user2@company.com
user3@company.com
```

This is the preferred model for an enterprise Google Workspace environment when appropriate.

## External

Use External when users can be outside the organization's Google Workspace organization, including independent Gmail accounts.

For an External application in testing status, Google can require test users.

For production, the application should be configured/published according to Google's OAuth requirements.

---

# 7. Google Drive Scope

The initial implementation uses:

```text
https://www.googleapis.com/auth/drive.file
```

The reason for selecting `drive.file` is least privilege.

The application does not initially need unrestricted access to the user's entire Google Drive.

## Important

`drive.file` does **not** mean:

> SAP can freely read, edit, or delete every file in the user's Google Drive.

It provides scoped access to files that the application creates or files that the user explicitly makes available to the application through supported Google Drive flows.

For the initial integration:

```text
SAP
  ↓
Create/upload application file
  ↓
drive.file
  ↓
Google Drive
```

If future requirements require unrestricted access to arbitrary existing Drive files, the OAuth scope and security design must be reconsidered.

---

# 8. Google Drive Folder Strategy

The integration can also upload files into a Google Drive folder.

Example:

```text
My Drive
└── SAP-Exports
      ├── ALV_001.xlsx
      ├── ALV_002.xlsx
      └── ALV_003.xlsx
```

A Google Drive folder has a folder ID.

When creating the file, the folder ID can be supplied as the file's parent.

Conceptually:

```json
{
  "name": "SAP_GDRIVE_INT.TXT",
  "mimeType": "text/plain",
  "parents": [
    "GOOGLE_FOLDER_ID"
  ]
}
```

For the initial version, folder management is deliberately kept simple.

Initial test:

```text
My Drive
└── SAP_GDRIVE_INT.TXT
```

Later:

```text
My Drive
└── SAP-Exports
      ├── Sales Orders
      ├── Invoices
      └── Other Reports
```

---

# 9. Why Start With TXT?

The first ABAP implementation should not combine Google integration problems with ALV/XLSX generation problems.

Initial flow:

```text
ABAP
 ↓
Create simple text content
 ↓
SAP_GDRIVE_INT.TXT
 ↓
Google Drive
```

After the integration is proven:

```text
ALV
 ↓
CSV/XLSX
 ↓
Google Drive
```

This provides a clean incremental implementation.

---

# 10. Target Architecture

The intended SAP architecture is:

```text
                         SAP
                          │
                          ▼
                    ALV Report
                          │
                          │ Export
                          ▼
                ALV Export/Application Layer
                          │
                          ▼
               Google Drive Integration
                          │
              ┌───────────┴───────────┐
              │                       │
              ▼                       ▼
         OAuth 2.0              Drive API
              │                       │
              └───────────┬───────────┘
                          ▼
                    Google Drive
                          │
                          ▼
                  User's Drive
```

The Google-specific HTTP/API logic should be separated from ALV generation logic.

---

# 11. RAP Direction

The project is intended to evolve toward a RAP-based implementation.

Conceptually:

```text
Fiori/UI
   │
   ▼
RAP Business Object
   │
   ▼
Export Action
   │
   ▼
Application/Integration Service
   │
   ▼
Google Drive API
```

The RAP action should represent the business operation:

```text
ExportToGoogleDrive
```

The Google Drive API implementation should remain separated from the RAP behavior implementation.

This prevents the RAP behavior implementation from becoming tightly coupled to HTTP and Google-specific details.

---

# 12. Initial ABAP Development

Before implementing the complete RAP ALV action, the first ABAP milestone is a small executable/class-based test.

Example flow:

```text
Executable ABAP Class
       │
       ▼
Create test content
       │
       ▼
SAP_GDRIVE_INT.TXT
       │
       ▼
OAuth
       │
       ▼
Google Drive API
       │
       ▼
Upload
```

This validates the SAP-side Google integration independently.

---

# 13. SAP OAuth Configuration

The SAP implementation will use SAP's OAuth configuration/framework rather than hard-coding Google credentials.

The Google OAuth client provides:

```text
Client ID
Client Secret
```

These should be configured securely.

The SAP side will use the appropriate OAuth configuration, including:

```text
OA2C_CONFIG
```

The exact configuration depends on the SAP deployment/runtime and OAuth framework available in that system.

The Client Secret must never be hard-coded in an ABAP class.

---

# 14. OAuth Responsibilities

There are two different concepts:

## Application credentials

```text
Client ID
Client Secret
```

These identify the SAP integration application.

## User authorization

```text
Google Account
     ↓
OAuth Authorization
     ↓
Access/Refresh Token handling
```

This identifies the user's authorization.

Therefore:

```text
One Client ID + Secret
        +
Multiple user authorizations
        =
Multiple SAP users can use the same application
```

---

# 15. Token Architecture

For the final multi-user design:

```text
SAP User
    │
    ▼
User-specific OAuth authorization
    │
    ▼
Token handling
    │
    ▼
Google Drive API
```

The implementation must ensure that one user's authorization is never accidentally used for another user's Google Drive.

This is a key security requirement.

---

# 16. ALV Export Flow

The final user experience should be:

```text
SAP
 │
 ├── Run Report
 │
 ▼
ALV Output
 │
 ▼
[Export to Google Drive]
 │
 ▼
Check user's Google authorization
 │
 ├── Not authorized
 │       ↓
 │   OAuth authorization
 │
 └── Already authorized
         ↓
       Continue
 │
 ▼
Generate CSV/XLSX
 │
 ▼
Google Drive API
 │
 ▼
User's Google Drive
```

The user should not need to manually download and upload the file.

---

# 17. Initial API Operations

The Google Drive API operations validated during development are:

### List files

```http
GET /drive/v3/files
```

### Upload file

```http
POST /upload/drive/v3/files?uploadType=multipart
```

### Read metadata

```http
GET /drive/v3/files/{FILE_ID}
```

### Read/download content

```http
GET /drive/v3/files/{FILE_ID}?alt=media
```

---

# 18. Multipart Upload

Google Drive multipart upload contains:

```text
Part 1
------
File metadata

+

Part 2
------
File content
```

Example:

```text
--my_boundary
Content-Type: application/json; charset=UTF-8

{
  "name": "SAP_GDRIVE_INT.TXT",
  "mimeType": "text/plain"
}

--my_boundary
Content-Type: text/plain

Hello from SAP Google Drive Integration

--my_boundary--
```

The HTTP header contains:

```http
Content-Type: multipart/related; boundary=my_boundary
```

`my_boundary` is only a MIME multipart separator. It is not a Google-specific value.

The boundary in the header and body must match.

---

# 19. Security Decisions

The following security principles apply:

* Do not hard-code the Client Secret.
* Do not commit OAuth credentials to GitHub.
* Do not expose access or refresh tokens in logs.
* Use the minimum required OAuth scope.
* Use HTTPS for communication.
* Maintain user-specific authorization boundaries.
* Never use one user's token for another SAP user.
* Separate development and production Google Cloud configurations.
* Keep Google credentials outside application source code.

---

# 20. Development Strategy

The project follows an incremental approach.

## Phase 1 — Google validation

```text
Google Cloud
   ↓
OAuth
   ↓
Postman
   ↓
Upload
   ↓
Read
```

Completed before SAP implementation.

## Phase 2 — ABAP integration

```text
ABAP
   ↓
OAuth configuration
   ↓
Google Drive API
   ↓
Upload TXT
```

## Phase 3 — Read/download

```text
ABAP
   ↓
Get file metadata
   ↓
Read/download file
```

## Phase 4 — ALV export

```text
ALV
   ↓
CSV/XLSX
   ↓
Google Drive
```

## Phase 5 — RAP action

```text
RAP
   ↓
ExportToGoogleDrive
   ↓
Integration service
   ↓
Google Drive
```

## Phase 6 — Multi-user production architecture

```text
Multiple SAP Users
        │
        ▼
User-specific OAuth
        │
        ▼
Individual Google Drives
```

---

# 21. Design Decisions

| Area                 | Decision                                |
| -------------------- | --------------------------------------- |
| Cloud storage        | Google Drive                            |
| API                  | Google Drive API                        |
| Authentication       | OAuth 2.0                               |
| OAuth application    | One application                         |
| Client ID            | One application-level Client ID         |
| Client Secret        | One application-level Client Secret     |
| User authorization   | User-specific                           |
| Destination          | Authorized user's Google Drive          |
| Initial scope        | `drive.file`                            |
| OAuth client type    | Web application                         |
| Initial test tool    | Postman                                 |
| Initial ABAP test    | Executable/class-based test             |
| Initial file         | `SAP_GDRIVE_INT.TXT`                    |
| Initial format       | TXT                                     |
| Final format         | CSV/XLSX                                |
| Final user operation | ALV → Google Drive                      |
| RAP operation        | Export action                           |
| Initial folder       | No folder dependency                    |
| Future folder        | SAP-Exports / business-specific folders |
| Development approach | Google → Postman → ABAP → RAP → ALV     |
| Credentials          | Secure configuration, never source code |

---

# 22. Alternative Architecture Considered

A separate external application could also handle Google Drive uploads:

```text
SAP/RAP
   │
   ▼
Event
   │
   ▼
External Application
   │
   ▼
Google Drive
```

This can be useful when:

* Google integration becomes complex.
* Large files require specialized processing.
* Asynchronous processing is required.
* Many external cloud providers need to be supported.
* SAP should remain isolated from external API-specific logic.

However, for the current requirement and learning/development scope, the selected direction is to implement the integration in the SAP/ABAP layer.

Selected architecture:

```text
RAP/ABAP
   │
   ▼
Google Drive API
```

This keeps the initial solution simple and avoids introducing an additional middleware/application layer.

---

# 23. Architecture Trade-offs

## Direct ABAP → Google Drive

### Advantages

* Simple architecture.
* No additional application to maintain.
* Fewer components.
* Easier to understand and deploy for a small integration.
* Business action can directly trigger the upload.
* Good fit for the initial ALV export requirement.

### Disadvantages

* SAP becomes responsible for Google API integration.
* OAuth/token handling must be designed correctly.
* External API failures affect the SAP operation.
* Large/long-running uploads may require asynchronous processing.
* Google-specific logic becomes part of the SAP landscape.

## SAP → External Application → Google Drive

### Advantages

* External integration logic is separated from SAP.
* Easier to scale independently.
* Can support multiple cloud storage providers.
* Better fit for complex asynchronous processing.

### Disadvantages

* Additional infrastructure.
* Additional authentication between SAP and the external application.
* More operational complexity.
* More components to monitor.

For the initial implementation, direct ABAP integration is selected.

---

# 24. Future Improvements

Potential future functionality:

```text
ALV
 ↓
Export
 ↓
Select file format
 ├── CSV
 └── XLSX
 ↓
Select/resolve Drive folder
 ↓
Upload
 ↓
Display Drive file information
```

Potential future folder structure:

```text
SAP-Exports
│
├── Sales Orders
│
├── Invoices
│
├── Purchase Orders
│
└── Other Reports
```

Potential future background processing:

```text
RAP Action
   ↓
Create Export Request
   ↓
Background Processing
   ↓
Generate File
   ↓
Upload to Google Drive
   ↓
Update Export Status
```

---

# 25. Current Project Goal

The immediate goal is intentionally small:

```text
ABAP
  ↓
Create SAP_GDRIVE_INT.TXT
  ↓
Authenticate using Google OAuth
  ↓
Upload to Google Drive
  ↓
Read the file
```

Once this is stable:

```text
ALV
  ↓
Generate CSV/XLSX
  ↓
Export to Google Drive
```

The final user-facing capability is:

> **SAP user clicks Export to Google Drive and the ALV file is stored in that user's authorized Google Drive.**
