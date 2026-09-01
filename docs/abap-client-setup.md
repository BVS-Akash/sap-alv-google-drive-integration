# Google Drive ABAP client: implementation and setup guide

## 1. Import the ABAP objects

Create and activate these objects in this order in ADT or SE24:

1. Exception class `ZCX_GDRIVE_ERROR` from `zcx_gdrive_error.abap`.
2. Global class `ZCL_GDRIVE_CLIENT` from `zcl_gdrive_client.abap`.
3. Executable report `Z_GDRIVE_CLIENT_TEST` from `z_gdrive_client_test.abap`.
4. Executable report `Z_GDRIVE_UPLOAD_TEST` from `z_gdrive_upload_test.abap`.

The test report performs only an authenticated `GET` request. It never uploads or creates a Google Drive file.

## 2. Do not create an SM59 destination

This implementation intentionally uses `CL_HTTP_CLIENT=>CREATE_BY_URL` with direct HTTPS URLs. Do **not** create an HTTP destination in SM59 for this client, and do not add one to the ABAP code.

If your landscape requires an outbound proxy, maintain it in the SAP internet communication/network configuration used by the application server. That infrastructure is outside this class. Ask your Basis/network team for the approved proxy and firewall route.

## 3. Confirm outbound network access

The application server must be able to resolve and connect to:

* `www.googleapis.com` on TCP port 443
* `accounts.google.com` on TCP port 443 (used during initial Google authorization)

Your network team should allow the required HTTPS traffic through the corporate firewall/proxy. DNS, firewall, and proxy failures cannot be corrected in ABAP code.

## 4. Maintain and verify Google TLS certificates

1. In the SAP GUI, open transaction `STRUST`.
2. Select the SSL client PSE used for anonymous outbound HTTPS, normally **SSL Client (Anonymous)**. Confirm the PSE name and SSL client used in your landscape with Basis before changing anything.
3. Import the Google server certificate chain, including the issuing intermediate and trusted root certificates, according to your organisation’s certificate policy.
4. Add imported issuers to the PSE certificate list and save the PSE.
5. Distribute the PSE to all application servers if the system has multiple instances.
6. Have Basis reload/restart the relevant ICM service only if required by your operational procedure.

Do not disable certificate verification. The client uses HTTPS and relies on SAP’s TLS/ICM validation. A successful `Z_GDRIVE_CLIENT_TEST` run proves that the HTTPS handshake, certificate trust, OAuth authentication, and Drive API access all succeeded together.

For certificate errors, check `SMICM` traces and the SAP system log with Basis. Typical causes are a missing intermediate certificate, an expired certificate, an incorrect system clock, proxy TLS inspection, or a PSE not distributed to every application server.

## 5. Create Google OAuth credentials

This step is performed in Google Cloud Console by a Google Workspace/Cloud administrator.

1. Create or select the Google Cloud project that owns the integration.
2. Enable **Google Drive API** for that project.
3. Configure the OAuth consent screen, including the intended test/production users.
4. Create an OAuth 2.0 client credential suitable for SAP’s authorization-code flow.
5. Register the callback/redirect URI that SAP OA2C displays or requires. The redirect URI must match exactly in Google and SAP.
6. Record the client ID and client secret securely for configuration in SAP. Do not put them in ABAP source code.
7. Select the smallest required scope. For files created by this integration, use `https://www.googleapis.com/auth/drive.file`; use broader scopes only when the business requirement needs them.

## 6. Configure SAP OAuth in OA2C_CONFIG

The exact screen labels can vary by SAP support package. Use transaction `OA2C_CONFIG` and create a customer configuration/profile, for example `Z_GOOGLE_DRIVE`.

Maintain the Google values supplied by the Google Cloud project:

| Setting | Value |
| --- | --- |
| Authorization endpoint | `https://accounts.google.com/o/oauth2/v2/auth` |
| Token endpoint | `https://oauth2.googleapis.com/token` |
| Client ID | Google OAuth client ID |
| Client secret | Google OAuth client secret |
| Scope | `https://www.googleapis.com/auth/drive.file` |
| Resource access authentication | HTTP header / Bearer token |
| Redirect URI | The exact SAP-generated/maintained callback URI registered in Google |

Use authorization-code flow for delegated Google Drive access. Save and activate the OA2C configuration. Never save the access token or refresh token in a custom Z-table.

## 7. Perform the initial authorization

An administrator or the intended SAP technical/user context must complete Google consent once.

1. In `OA2C_CONFIG`, open the new `Z_GOOGLE_DRIVE` configuration.
2. Use the provided action to request/get an authorization token, following the SAP GUI flow for the installed release.
3. Sign in to the intended Google account in the browser.
4. Approve the requested Drive scope.
5. Return to SAP and verify that the authorization completed without an OA2C error.

SAP’s OAuth framework manages the stored authorization/refresh state. `ZCL_GDRIVE_CLIENT` obtains the configured OA2C client, applies its managed token to each request, and requests a refresh when SAP reports that the access token has expired.

### Why OA2C_GRANT is not called from `ZCL_GDRIVE_CLIENT`

`OA2C_GRANT` is the one-time, interactive authorization-code setup. It opens a browser, requires a Google user sign-in and consent, and redirects back to SAP. It is therefore an administrator/user operation, not a background-safe class method. Do not hardcode a Google password, authorization code, refresh token, or grant URL in `ZCL_GDRIVE_CLIENT`.

After `OA2C_GRANT` shows a green **Access Status**, the class can use SAP-managed OAuth state at runtime. If it is not green, fix the OAuth configuration or repeat the grant rather than changing the upload code.

## 8. Activate the ABAP objects

The class uses SAP's OA2C client framework to apply the managed Bearer token to each HTTP request and to refresh an expired token. No OAuth secret or token is hardcoded or written to a custom table.

1. Activate `ZCX_GDRIVE_ERROR`.
2. Activate `ZCL_GDRIVE_CLIENT`.
3. Activate `Z_GDRIVE_CLIENT_TEST`.
4. Do not log the access token, refresh token, client secret, or authorization header in any consuming report.

## 9. Run the connection test

1. Execute `Z_GDRIVE_CLIENT_TEST` in `SA38` or ADT.
2. Enter the OA2C profile/configuration name, for example `Z_GOOGLE_DRIVE`.
3. Execute the report.

Expected outcome: `Authenticated Google Drive connection succeeded.`

The request is:

```text
GET https://www.googleapis.com/drive/v3/about?fields=user,storageQuota
Authorization: Bearer <managed access token>
```

It requires HTTP `200`; it does not upload a file.

The test validates the entire runtime chain: direct URL creation, DNS/proxy/firewall reachability, TLS certificate trust, SAP OAuth state, Bearer authentication, and Google Drive API authorization. It is not merely a ping or DNS test.

## 10. Upload behavior

### Foreground CSV/XLSX test upload

Run `Z_GDRIVE_UPLOAD_TEST` in SAP GUI to verify a real upload. Enter the OA2C
profile, use F4 on the file field to choose a local CSV, XLSX, or XLS file, and
execute. The report reads the selected file as raw bytes, determines the MIME
type from its extension, and calls `ZCL_GDRIVE_CLIENT`. It prints the Drive file
ID and link after a successful upload. This is a foreground SAP GUI report;
use a server-side dataset API in a background job instead of `GUI_UPLOAD`.

External callers pass the file name, MIME type, and file content as an `XSTRING`. `XSTRING` is required because it keeps CSV, XLSX, XLS, PDF, and other binary files unchanged.

```abap
DATA(lo_gdrive) = NEW zcl_gdrive_client( iv_oauth_profile = 'Z_GOOGLE_DRIVE' ).

DATA(ls_result) = lo_gdrive->upload_file(
  iv_file_name    = 'report.pdf'
  iv_mime_type    = 'application/pdf'
  iv_file_content = lv_file_xstring ).
```

For CSV content already prepared as an `XSTRING`, use the CSV convenience method:

```abap
DATA(ls_result) = lo_gdrive->upload_csv(
  iv_file_name   = 'report.csv'
  iv_csv_content = lv_csv_xstring ).
```

For Excel, use the XLSX default or pass the MIME type explicitly for another Excel format:

```abap
DATA(ls_result) = lo_gdrive->upload_excel(
  iv_file_name     = 'report.xlsx'
  iv_excel_content = lv_excel_xstring ).

"Legacy XLS example
DATA(ls_xls_result) = lo_gdrive->upload_excel(
  iv_file_name     = 'report.xls'
  iv_excel_content = lv_xls_xstring
  iv_mime_type     = 'application/vnd.ms-excel' ).
```

Common MIME types:

| File type | MIME type |
| --- | --- |
| CSV | `text/csv` |
| XLSX | `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet` |
| XLS | `application/vnd.ms-excel` |

* Files up to 5 MiB use one `multipart/related` request.
* Files above 5 MiB automatically start a Drive resumable-upload session and send 5 MiB `PUT` chunks with `Content-Range`.
* Retries and restart/resume after a failed chunk are not implemented yet.

## Troubleshooting

| Symptom | First place to check |
| --- | --- |
| HTTPS/TLS handshake fails | STRUST PSE, certificate chain, `SMICM`, proxy and server clock |
| Cannot reach Google | DNS, firewall/proxy rules, TCP 443 from the application server |
| OA2C authorization fails | OAuth client ID/secret, redirect URI, Google consent screen, scope |
| HTTP 401 | Initial consent or token refresh state in OA2C_CONFIG |
| HTTP 403 | Granted scope, Google account permissions, Drive API enabled in the Cloud project |
| HTTP 429/5xx | Google service/quota condition; this version reports it but does not retry |

## Security checklist

* Keep OAuth client secrets only in OA2C configuration.
* Never write OAuth values to the ABAP list, application log, dump, or custom table.
* Restrict who can maintain `OA2C_CONFIG`, `STRUST`, and the Google Cloud OAuth client.
* Use the narrowest Google Drive scope that satisfies the integration.
* Keep certificate-chain maintenance and expiry monitoring with Basis/security operations.
