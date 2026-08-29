# Google Drive Integration — Postman Testing

This document contains the complete Postman testing procedure for the SAP → Google Drive integration.

The purpose is to validate the Google OAuth and Drive API flow before implementing the same functionality in ABAP.

---

# 1. Objective

The Postman tests validate:

```text
OAuth 2.0
   ↓
Access Token
   ↓
Google Drive API
   ↓
List Files
   ↓
Upload File
   ↓
Read Metadata
   ↓
Read File Content
```

The first test file is:

```text
SAP_GDRIVE_INT.TXT
```

---

# 2. Prerequisites

Complete the Google Cloud setup documented in:

```text
GOOGLE/README.md
```

You need:

* Google Cloud project
* Google Drive API enabled
* OAuth application
* OAuth Client ID
* OAuth Client Secret
* `drive.file` scope
* Postman
* Google account to authorize

---

# 3. Postman OAuth Configuration

Create a new request in Postman.

Go to:

```text
Authorization
```

Select:

```text
Type:
OAuth 2.0
```

Configure:

```text
Grant Type:
Authorization Code
```

Authorization URL:

```text
https://accounts.google.com/o/oauth2/v2/auth
```

Access Token URL:

```text
https://oauth2.googleapis.com/token
```

Client ID:

```text
<YOUR GOOGLE CLIENT ID>
```

Client Secret:

```text
<YOUR GOOGLE CLIENT SECRET>
```

Scope:

```text
https://www.googleapis.com/auth/drive.file
```

Callback URL:

```text
https://oauth.pstmn.io/v1/browser-callback
```

---

# 4. Get New Access Token

In Postman:

```text
Authorization
    ↓
OAuth 2.0
    ↓
Get New Access Token
```

Google will open the authorization page.

Sign in with the Google account whose Drive you want to test.

Example:

```text
abc123@gmail.com
```

Grant the requested permission.

The flow is:

```text
Postman
   │
   ▼
Google OAuth
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
```

After Postman receives the token, click:

```text
Use Token
```

---

# 5. Understanding the Access Token

The access token is what Postman uses when calling Google Drive.

Requests contain:

```http
Authorization: Bearer <ACCESS_TOKEN>
```

The token is different from the Client ID and Client Secret.

```text
Client ID
    ↓
Identifies application

Client Secret
    ↓
Authenticates application

Access Token
    ↓
Authorizes API requests
```

Never commit access tokens to GitHub.

---

# 6. Test 1 — List Drive Files

Create a request:

```http
GET https://www.googleapis.com/drive/v3/files
```

Set Authorization to use the OAuth 2.0 token.

Send the request.

A valid response can look like:

```json
{
  "files": [],
  "kind": "drive#fileList",
  "incompleteSearch": false
}
```

---

# 7. Understanding an Empty `files` Array

This response:

```json
{
  "files": []
}
```

does not automatically mean OAuth failed.

It means no files were returned for that request.

With the initial:

```text
drive.file
```

scope, the application does not have unrestricted visibility into the user's entire Drive.

The next important test is uploading a file.

---

# 8. Test 2 — Upload Test File

Create a local test file:

```text
SAP_GDRIVE_INT.TXT
```

Example content:

```text
Hello from Postman.

This is a test file for the SAP Google Drive integration.

Created by:
SAP Google Drive Integration

Test file:
SAP_GDRIVE_INT.TXT
```

---

# 9. Upload Endpoint

Create:

```http
POST https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart
```

Authorization:

```http
Authorization: Bearer <ACCESS_TOKEN>
```

Content-Type:

```http
Content-Type: multipart/related; boundary=my_boundary
```

---

# 10. Multipart Upload

Google's multipart upload contains two parts:

```text
Part 1
------
File metadata

Part 2
------
File content
```

Conceptually:

```text
HTTP Request
      │
      ├── Metadata
      │     ├── name
      │     └── mimeType
      │
      └── Content
            └── File data
```

---

# 11. Complete Upload Body

In Postman select:

```text
Body
    ↓
raw
```

Use:

```text
--my_boundary
Content-Type: application/json; charset=UTF-8

{
  "name": "SAP_GDRIVE_INT.TXT",
  "mimeType": "text/plain"
}
--my_boundary
Content-Type: text/plain

Hello from Postman.

This is a test file for the SAP Google Drive integration.

Created by:
SAP Google Drive Integration

Test file:
SAP_GDRIVE_INT.TXT

--my_boundary--
```

The HTTP header is:

```http
Content-Type: multipart/related; boundary=my_boundary
```

---

# 12. What Is `my_boundary`?

`my_boundary` is simply the MIME multipart separator.

It is not:

```text
Google folder ID
Google file ID
API key
OAuth value
```

It is only used to separate the multipart sections.

Header:

```http
boundary=my_boundary
```

Body:

```text
--my_boundary
...
--my_boundary
...
--my_boundary--
```

The value must match.

You can technically use another boundary name, but the same value must be used consistently in the header and body.

---

# 13. Expected Upload Response

A successful response should contain information similar to:

```json
{
  "kind": "drive#file",
  "id": "1AbCdEfGh...",
  "name": "SAP_GDRIVE_INT.TXT",
  "mimeType": "text/plain"
}
```

The most important field is:

```text
id
```

Example:

```text
1AbCdEfGh...
```

This is the Google Drive file ID.

Save it for the following tests.

---

# 14. Verify File in Google Drive

Open the Google Drive belonging to the Google account used during OAuth authorization.

You should see:

```text
My Drive
└── SAP_GDRIVE_INT.TXT
```

This confirms:

```text
Postman
   ↓
OAuth
   ↓
Access Token
   ↓
Google Drive API
   ↓
Upload
   ↓
Google Drive
```

---

# 15. Test 3 — Read File Metadata

Use the file ID returned from the upload response.

Request:

```http
GET https://www.googleapis.com/drive/v3/files/{FILE_ID}
```

Example:

```http
GET https://www.googleapis.com/drive/v3/files/1AbCdEfGh...
```

Use the same OAuth authorization.

Expected response:

```json
{
  "id": "1AbCdEfGh...",
  "name": "SAP_GDRIVE_INT.TXT",
  "mimeType": "text/plain"
}
```

---

# 16. What Is File Metadata?

Metadata describes the file.

Example:

```text
File ID
File name
MIME type
```

Request:

```http
GET /drive/v3/files/{FILE_ID}
```

returns metadata.

It does not mean that the actual file content has been downloaded.

---

# 17. Test 4 — Read File Content

To retrieve the actual file content:

```http
GET https://www.googleapis.com/drive/v3/files/{FILE_ID}?alt=media
```

Example:

```http
GET https://www.googleapis.com/drive/v3/files/1AbCdEfGh...?alt=media
```

Expected response:

```text
Hello from Postman.

This is a test file for the SAP Google Drive integration.

Created by:
SAP Google Drive Integration

Test file:
SAP_GDRIVE_INT.TXT
```

---

# 18. Metadata vs Content

There are two different operations.

### Metadata

```http
GET /drive/v3/files/{FILE_ID}
```

Returns:

```text
ID
Name
MIME type
Other file metadata
```

### Content

```http
GET /drive/v3/files/{FILE_ID}?alt=media
```

Returns:

```text
Actual file content
```

This distinction will also be important when implementing the ABAP client.

---

# 19. Test 5 — Upload to a Folder

Google Drive files can be created inside a folder.

First obtain the Google Drive folder ID.

Example:

```text
SAP-Exports
```

Folder ID:

```text
1FolderAbCdEf...
```

Use that ID as the parent in the upload metadata:

```json
{
  "name": "SAP_GDRIVE_INT.TXT",
  "mimeType": "text/plain",
  "parents": [
    "1FolderAbCdEf..."
  ]
}
```

The result is:

```text
My Drive
└── SAP-Exports
      └── SAP_GDRIVE_INT.TXT
```

---

# 20. Folder Strategy for the SAP Project

The eventual SAP architecture can use:

```text
User's Google Drive
└── SAP-Exports
      ├── Sales Orders
      ├── Invoices
      └── Other Reports
```

However, the initial implementation does not need folder management.

Start with:

```text
SAP_GDRIVE_INT.TXT
        ↓
Google Drive
```

Then introduce folders after the basic upload works.

---

# 21. Multi-User Testing

The OAuth client is application-level.

You do not need:

```text
Client ID A → User A
Client ID B → User B
Client ID C → User C
```

Instead:

```text
One OAuth Client
       │
       ├── User A authorization
       ├── User B authorization
       └── User C authorization
```

Each authorization corresponds to the Google account that authorized the application.

Therefore:

```text
User A
  ↓
OAuth authorization
  ↓
Drive A

User B
  ↓
OAuth authorization
  ↓
Drive B
```

The SAP implementation must preserve these authorization boundaries.

---

# 22. Complete Postman Test Sequence

Follow this sequence:

```text
1. Configure OAuth
       ↓
2. Get New Access Token
       ↓
3. Authorize Google account
       ↓
4. Use Token
       ↓
5. GET /drive/v3/files
       ↓
6. Create SAP_GDRIVE_INT.TXT
       ↓
7. POST multipart upload
       ↓
8. Copy returned File ID
       ↓
9. Verify file in Google Drive
       ↓
10. GET /drive/v3/files/{FILE_ID}
       ↓
11. GET /drive/v3/files/{FILE_ID}?alt=media
```

Optional:

```text
12. Create/select folder
       ↓
13. Upload using parents = [FOLDER_ID]
```

---

# 23. Expected Final Result

After successful testing:

```text
Google Drive
│
└── SAP_GDRIVE_INT.TXT
```

and Postman should successfully perform:

```text
OAuth                         ✅
Access Token                  ✅
List Files                    ✅
Upload File                   ✅
File visible in Drive         ✅
Read File Metadata            ✅
Read File Content             ✅
Folder Upload                 Optional
```

---

# 24. Troubleshooting

## 401 Unauthorized

Check:

```text
Access Token
Authorization header
Token validity
```

Expected:

```http
Authorization: Bearer <ACCESS_TOKEN>
```

---

## 403 Forbidden

Check:

```text
OAuth scope
Google Drive API
User authorization
Application configuration
```

Make sure the required Drive scope was granted.

---

## OAuth Redirect Error

Check that:

```text
https://oauth.pstmn.io/v1/browser-callback
```

is configured as an authorized redirect URI for the Postman OAuth client.

The URI must match exactly.

---

## Empty File List

If:

```json
{
  "files": []
}
```

is returned, do not immediately assume authentication failed.

With:

```text
drive.file
```

the application does not have unrestricted visibility into the user's entire Drive.

Test file creation/upload next.

---

## Upload Fails

Check:

```text
HTTP method
Upload URL
Access Token
Content-Type
Boundary
Metadata JSON
File content
```

Make sure:

```text
Content-Type:
multipart/related; boundary=my_boundary
```

matches:

```text
--my_boundary
...
--my_boundary--
```

---

# 25. Security Rules

Never save the following in this repository:

```text
Client Secret
Access Token
Refresh Token
```

Do not commit them to GitHub.

Use Postman variables or secure local configuration where appropriate.

For example:

```text
GOOGLE_CLIENT_ID
GOOGLE_CLIENT_SECRET
GOOGLE_ACCESS_TOKEN
```

should be kept out of committed files.

---

# 26. Postman Collection

The project can maintain a Postman collection:

```text
POSTMAN/
├── README.md
└── Google-Drive-Integration.postman_collection.json
```

Recommended collection structure:

```text
Google Drive Integration
│
├── OAuth
│
├── 01 - List Files
│
├── 02 - Upload File
│
├── 03 - Get File Metadata
│
├── 04 - Read File Content
│
└── 05 - Upload to Folder
```

---

# 27. Validation Boundary

Successful Postman testing proves that:

```text
Google Cloud Configuration
        +
OAuth Configuration
        +
Google Drive API
        +
User Authorization
        +
File Upload
        +
File Read
```

are working.

It does not yet prove the SAP OAuth configuration.

That is the next phase.

---

# 28. Transition to ABAP

After the Postman tests are successful, reproduce the same flow in ABAP.

Postman:

```text
OAuth
 ↓
Access Token
 ↓
Google Drive API
 ↓
Upload
 ↓
Read
```

SAP:

```text
ABAP
 ↓
SAP OAuth Configuration
 ↓
Google Drive HTTP Client
 ↓
Upload
 ↓
Read
```

The first SAP milestone is:

```text
ABAP
  ↓
Create SAP_GDRIVE_INT.TXT
  ↓
Authenticate
  ↓
Upload to Google Drive
```

After that:

```text
ALV
  ↓
CSV/XLSX
  ↓
Google Drive
```

Finally:

```text
RAP Action
  ↓
ExportToGoogleDrive
  ↓
ALV Export
  ↓
Google Drive
```
