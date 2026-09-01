# Google Drive Integration — Google Cloud Setup

This document contains the complete Google-side configuration required for the **SAP ALV → Google Drive Integration**.

The purpose is to configure Google Cloud, Google Drive API, OAuth 2.0, and the OAuth client that will later be consumed by SAP ABAP.

---

# 1. Integration Overview

The target integration is:

```text
SAP
 │
 │ OAuth 2.0
 ▼
Google Authorization
 │
 ▼
Google Drive API
 │
 ▼
User's Google Drive
```

The final business scenario is:

```text
SAP ALV
   │
   ▼
Export to Google Drive
   │
   ▼
Google Drive
```

The Google-side setup is completed independently before implementing the SAP ABAP integration.

---

# 2. Prerequisites

You need:

* Google account
* Access to Google Cloud Console
* Permission to create/configure a Google Cloud project
* Google Drive
* Access to Google Auth Platform
* Postman for testing

---

# 3. Create Google Cloud Project

Open:

```text
https://console.cloud.google.com/
```

Create a new Google Cloud project.

Recommended project name:

```text
SAP-Google-Drive-Integration
```

For production, separate environments should be used.

Recommended:

```text
SAP-Google-Drive-Integration-DEV
SAP-Google-Drive-Integration-PROD
```

Do not use production credentials in the development project.

---

# 4. Enable Google Drive API

Open the newly created Google Cloud project.

Navigate to:

```text
APIs & Services
    ↓
Library
```

Search for:

```text
Google Drive API
```

Open:

```text
Google Drive API
```

Click:

```text
Enable
```

The architecture is now:

```text
Google Cloud Project
       │
       ▼
Google Drive API
```

---

# 5. Configure Google Auth Platform

Navigate to:

```text
Google Cloud Console
    ↓
Google Auth Platform
```

Configure the OAuth application.

Create/configure the application.

Example:

```text
Application name:
SAP Google Drive Integration
```

Provide the required support and developer contact information.

---

# 6. Configure Audience

The application audience determines who can authorize the application.

There are two primary options:

```text
Internal
External
```

---

## 6.1 Internal Application

Choose **Internal** when the application is intended for users belonging to the same Google Workspace organization.

Example:

```text
user1@company.com
user2@company.com
user3@company.com
```

Architecture:

```text
Company Google Workspace
        │
        ▼
SAP Google Drive OAuth Application
        │
        ├── User A → User A Drive
        ├── User B → User B Drive
        └── User C → User C Drive
```

This is generally appropriate when SAP is used inside an organization that manages its users through Google Workspace.

---

## 6.2 External Application

Choose **External** when the application needs to support users outside the organization's Google Workspace organization.

Examples:

```text
user@gmail.com
customer@othercompany.com
```

For an External application in testing status, Google may require users to be configured as test users.

For production, follow Google's applicable OAuth publishing and verification requirements.

---

# 7. Configure Data Access

Navigate to:

```text
Google Auth Platform
    ↓
Data Access
    ↓
Add or Remove Scopes
```

Add the following scope:

```text
https://www.googleapis.com/auth/drive.file
```

The initial project intentionally uses:

```text
drive.file
```

rather than unrestricted Drive access.

---

# 8. Understanding `drive.file`

The scope:

```text
https://www.googleapis.com/auth/drive.file
```

provides restricted access to Drive files that the application creates or files that the user explicitly makes available to the application through supported Google Drive flows.

It should **not** be interpreted as:

```text
Application can freely access every file
in the user's Google Drive.
```

The initial requirement is:

```text
SAP
 ↓
Create/upload application file
 ↓
Google Drive
```

Therefore `drive.file` follows the least-privilege principle.

---

# 9. Why Not Use Full Drive Scope?

A broader scope such as:

```text
https://www.googleapis.com/auth/drive
```

provides much broader access to Drive.

The initial requirement does not require unrestricted access to the user's entire Drive.

The project only needs to establish:

```text
OAuth
 ↓
Upload
 ↓
Read
```

Therefore the initial scope is:

```text
https://www.googleapis.com/auth/drive.file
```

If the business requirement later becomes:

> Search and modify arbitrary existing files anywhere in the user's Drive

then the OAuth scope and architecture must be reconsidered.

---

# 10. Create OAuth Client

Navigate to:

```text
Google Auth Platform
    ↓
Clients
    ↓
Create Client
```

Select:

```text
Application type:
Web application
```

Recommended name:

```text
SAP Google Drive Integration
```

Google will generate:

```text
Client ID
Client Secret
```

---

# 11. Why Web Application?

The SAP integration requires a server-side OAuth configuration and authorization redirect/callback flow.

The Web Application OAuth client provides the credentials required by that OAuth flow.

Conceptually:

```text
SAP
 │
 ▼
OAuth Client
 │
 ├── Client ID
 └── Client Secret
```

These credentials identify the integration application.

---

# 12. Client ID

Google generates a Client ID similar to:

```text
123456789012-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.apps.googleusercontent.com
```

The actual value must be kept as provided by Google.

The Client ID is not a password.

It identifies the OAuth application.

---

# 13. Client Secret

Google generates a Client Secret similar to:

```text
GOCSPX-xxxxxxxxxxxxxxxx
```

The Client Secret is sensitive.

Never:

```text
- Commit it to GitHub
- Put it in README files
- Hard-code it in ABAP
- Share it publicly
- Put it into screenshots
```

It should be maintained through secure configuration.

---

# 14. OAuth Endpoints

Authorization endpoint:

```text
https://accounts.google.com/o/oauth2/v2/auth
```

Token endpoint:

```text
https://oauth2.googleapis.com/token
```

Drive API base URL:

```text
https://www.googleapis.com/drive/v3
```

Upload API base URL:

```text
https://www.googleapis.com/upload/drive/v3
```

---

# 15. Redirect URI

OAuth requires an authorized redirect URI.

For Postman testing, use:

```text
https://oauth.pstmn.io/v1/browser-callback
```

Add this URI to the OAuth client's authorized redirect URIs when using Postman.

Important:

```text
Postman callback
```

is for Postman testing.

It is **not** the final SAP callback.

The SAP implementation will use the appropriate SAP OAuth callback/redirect configuration.

---

# 16. OAuth Architecture

The complete OAuth flow is:

```text
                 Google Cloud
                      │
                      ▼
                OAuth Client
                 │          │
             Client ID   Secret
                 │          │
                 └────┬─────┘
                      ▼
                OAuth 2.0
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
                 Token Endpoint
                      │
                      ▼
                 Access Token
                      │
                      ▼
                Google Drive API
```

---

# 17. Multi-User Architecture

One OAuth application can support multiple users.

You do **not** create a separate Client ID and Client Secret for every user.

Correct model:

```text
              One OAuth Application
                Client ID + Secret
                       │
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
      User A         User B         User C
        │              │              │
    OAuth A         OAuth B         OAuth C
        │              │              │
        ▼              ▼              ▼
     Drive A         Drive B         Drive C
```

The Client ID/Secret identify the application.

The user's OAuth authorization determines which Google account has authorized the application.

---

# 18. SAP User vs Google User

The SAP user and Google account are conceptually different identities.

Example:

```text
SAP User:
AKASH

Google Account:
akash@company.com
```

The integration must establish the appropriate OAuth authorization relationship.

For multiple SAP users:

```text
SAP User A → Google Account A
SAP User B → Google Account B
SAP User C → Google Account C
```

The application must never accidentally use User A's authorization for User B.

---

# 19. Folder Strategy

Google Drive files can be stored inside folders.

Example:

```text
My Drive
└── SAP-Exports
      ├── Sales_Order_001.xlsx
      ├── Sales_Order_002.xlsx
      └── Sales_Order_003.xlsx
```

A Drive folder has a unique folder ID.

When creating a file, the folder ID can be specified as the parent:

```json
{
  "name": "SAP_GDRIVE_INT.TXT",
  "mimeType": "text/plain",
  "parents": [
    "GOOGLE_FOLDER_ID"
  ]
}
```

For the initial implementation, folder management is not mandatory.

The first objective is simply:

```text
SAP_GDRIVE_INT.TXT
        ↓
Google Drive
```

---

# 20. Security Design

The following rules apply:

### Never hard-code

Do not hard-code:

```text
Client Secret
Access Token
Refresh Token
```

into ABAP source code.

### Never commit credentials

Do not commit:

```text
credentials
tokens
secrets
```

to GitHub.

### Use least privilege

Start with:

```text
drive.file
```

instead of broader Drive access.

### Separate environments

Use separate Google Cloud projects/configurations for:

```text
DEV
TEST
PROD
```

where required by the organization's deployment model.

---

# 21. Google-Side Completion Checklist

Before moving to SAP:

```text
[ ] Google Cloud project created
[ ] Google Drive API enabled
[ ] Google Auth Platform configured
[ ] Application audience selected
[ ] Data Access configured
[ ] drive.file scope added
[ ] OAuth client created
[ ] Web Application selected
[ ] Client ID generated
[ ] Client Secret generated
[ ] Postman redirect URI configured
[ ] OAuth authorization tested
```

After these are completed, continue with:

```text
POSTMAN/README.md
```

The Postman documentation validates the actual Google Drive API operations.

---

# 22. Final Google Configuration

The expected configuration is:

```text
Google Cloud Project
        │
        ├── Google Drive API
        │
        └── Google Auth Platform
                │
                ├── Audience
                │
                ├── Data Access
                │      └── drive.file
                │
                └── OAuth Client
                       │
                       ├── Client ID
                       └── Client Secret
```

The Google-side setup is now ready for Postman testing and later SAP integration.
