# SAP OAuth2 Client Setup for Google Drive
### OA2C_CONFIG + Certificate (STRUST) Configuration

This README covers only the SAP-side configuration steps: setting up the SSL/certificate trust and configuring the OAuth 2.0 client in OA2C_CONFIG (or the newer SOAUTH2_CLIENT UI).

---

## Prerequisites

- Google Cloud project with Drive API enabled, and an OAuth 2.0 Client ID + Secret already created (Google Cloud Console side — not covered here).
- SAP authorizations:
  - **S_OA2C_ADM** and **S_SEC_COMM** — required for the user creating the OAuth client configuration.
  - **S_OA2C_USE** — required for the user/program that consumes the token at runtime.
- An **OAuth 2.0 Client Profile** created and activated in SE80 (this defines the service provider type, authorization endpoint, token endpoint, and scope). If you don't have one yet, start with Part 0 below.

---

## Part 0: Create the OAuth 2.0 Client Profile (SE80)

This is a one-time custom object you build yourself — SAP doesn't ship it. It acts as a template that OA2C_CONFIG later references. Example name used throughout this README: `ZGDRIVE_CLIENT_PROFILE` (pick any Z-name per your naming convention).

### Step 1 — Start SE80

1. Run transaction **SE80**.
2. In the object type dropdown, choose **Development Object** (or, in some versions, navigate via **Other Objects**).
3. Right-click the relevant package/object list and choose **Create → OAuth 2.0 Client Profile** from the context menu.

### Step 2 — Name and describe the profile

1. Enter the object name in the **Client Profile** field, e.g. `ZGDRIVE_CLIENT_PROFILE`.
2. Give it a short description, e.g. "OAuth2 Client Profile — Google Drive".
3. Assign it to a package and transport request (or a local `$TMP` package if this is a one-off dev test).

### Step 3 — Configure the profile fields

| Field | Value |
|---|---|
| Service Provider Type | Google (or Generic/OAuth2, depending on your SAP release's available types) |
| Authorization Endpoint | `https://accounts.google.com/o/oauth2/auth` |
| Token Endpoint | `https://oauth2.googleapis.com/token` |
| Scope | `https://www.googleapis.com/auth/drive` (or a narrower scope such as `.../auth/drive.file`) |

### Step 4 — Activate

1. Save the object.
2. Choose **Activate** (Ctrl+F3). Once active, this profile becomes selectable from the dropdown in OA2C_CONFIG / SOAUTH2_CLIENT.

> **Note:** The client profile only defines the *shape* of the connection (endpoints, scope, provider type). The actual Client ID, Client Secret, grant type, and redirect URI are entered later, in Part 2 (OA2C_CONFIG) — not here.

---

## Part 1: Certificate Setup (STRUST)

SAP needs to trust Google's SSL certificate chain before it can make outbound HTTPS calls to `accounts.google.com` and `oauth2.googleapis.com` / `www.googleapis.com`.

### Step 1 — Identify the correct PSE

1. Run transaction **STRUST**.
2. Expand **SSL client SSL Client (Standard)** — or a dedicated client PSE if your Basis team uses a separate one for outbound OAuth calls.
3. Double-click to open the PSE. If it doesn't exist yet, create it (Create PSE), with a key length of at least 2048 bit.

### Step 2 — Download Google's certificate chain

1. From a browser (or via `openssl s_client -connect oauth2.googleapis.com:443 -showcerts`), export the full certificate chain for `oauth2.googleapis.com` (and `accounts.google.com` if the authorization endpoint uses a different chain):
   - **Leaf certificate** (googleapis.com)
   - **Intermediate CA** (e.g. GTS CA / Google Trust Services)
   - **Root CA** (e.g. GTS Root R1, or the applicable root)
2. Save each as a `.crt` / Base64 (`.pem`) file.

### Step 3 — Import into STRUST

1. In STRUST, with the correct PSE selected, go to **Certificate → Import**.
2. Browse to the root CA file first, import it, then choose **Add to Certificate List**.
3. Repeat for the intermediate CA certificate.
4. You generally do **not** need to import the leaf certificate itself — trusting the root + intermediate is sufficient, since it validates the chain.
5. Save (Ctrl+S).

### Step 4 — Verify

1. Use transaction **SM59** to create (or reuse) an HTTP RFC destination pointing to `https://oauth2.googleapis.com`, with SSL active, and run **Connection Test**.
2. A successful test (HTTP response, not an SSL handshake error) confirms the certificate chain is trusted.

> **Common error:** `SSL handshake failed` or `Peer certificate rejected` in STRUST/SM59 usually means the root or intermediate CA is missing from the certificate list, or you imported it into the wrong PSE (client vs. server).

---

## Part 2: OA2C_CONFIG Setup

> SAP recommends transaction **SOAUTH2_CLIENT** over the legacy **OA2C_CONFIG** where available — same underlying configuration, but with a built-in test UI for validating tokens. Steps below apply to either.

### Step 1 — Start the transaction

Run **OA2C_CONFIG** (or **SOAUTH2_CLIENT**).

### Step 2 — Create a new client configuration

1. Choose **Create**.
2. Select the **OAuth 2.0 Client Profile** created earlier (e.g. `ZGDRIVE_CLIENT_PROFILE`). This pulls in the service provider type, authorization endpoint, and token endpoint automatically.
3. Enter the **OAuth 2.0 Client ID** (from Google Cloud Console).
4. Enter the **Client Secret**.

### Step 3 — Set authentication and grant type

| Field | Value |
|---|---|
| Client Authentication | Basic |
| Resource Access Authentication | Header Field |
| Grant Type | Authorization Code (typical for Drive; Client Credentials only if using a compatible service-account flow) |
| Redirect URI | Must exactly match the URI registered in Google Cloud Console |
| Scope | `https://www.googleapis.com/auth/drive` (or narrower, e.g. `.../auth/drive.file`) |

### Step 4 — Save and activate

1. Save the configuration.
2. Note the configuration name (this is what your ABAP code will reference via `cl_oauth2_client=>create( i_profile = ... )`).
3. The configuration is transportable to downstream systems (QA/PRD) like any other config object.

---

## Part 3: OA2C_GRANT — First-Time Authorization

`OA2C_CONFIG` only defines *how* to connect. It does not itself obtain a token. For the **Authorization Code** grant type, a separate transaction — **OA2C_GRANT** — is used to actually request and store the first access/refresh token pair. This step must be run at least once before any ABAP program can successfully call `SET_TOKEN`.

### Step 1 — Start OA2C_GRANT

Run transaction **OA2C_GRANT** (as the end user or service/technical user the program will run as).

### Step 2 — Select the client configuration

Choose the OAuth 2.0 client configuration created in Part 2 (e.g. the one built on `ZGDRIVE_CLIENT_PROFILE`).

### Step 3 — Request the token

1. Click **Request Token**.
2. This redirects the browser to Google's authorization endpoint.
3. Log in with the relevant Google account and grant consent for the requested scope (e.g. `drive`).
4. Google redirects back to AS ABAP via the registered redirect URI.

### Step 4 — Confirm success

The grant application screen should display **"Access possible"** along with the token's expiration time. This confirms SAP has stored an access token and refresh token in table **OA2C_TOKEN_ADM**.

### Step 5 — No repeat needed (usually)

After this one-time step, AS ABAP uses the refresh token to silently obtain new access tokens as they expire — end users don't need to run OA2C_GRANT again unless the refresh token is revoked (e.g. by the Google account owner, or by Google's own policies for unused/long-lived tokens) or the client configuration changes (new scope, new client secret, etc.), in which case you'll need to re-run OA2C_GRANT.

> **Common error:** `CX_OA2C_PROT_HTTP_FAILURE` on the Request Token button in OA2C_GRANT typically points to an HTTP communication issue — often the same certificate trust problem covered in Part 1, or a network/proxy block preventing SAP from reaching Google's endpoints.

### Step 6 — Validate

- If using SOAUTH2_CLIENT, use its built-in **token validation** check to confirm a valid token exists.
- Otherwise, run a small ABAP test snippet:

```abap
DATA(lo_oa2c_client) = cl_oauth2_client=>create( i_profile = 'ZGDRIVE_CLIENT_PROFILE' ).
lo_oa2c_client->set_token( io_http_client = lo_http_client ).
```

If this raises `CX_OA2C` on a lookup against `OA2C_TOKEN_ADM`, it usually means Step 5 (initial interactive authorization) hasn't been completed yet, or the client configuration itself has an error (mismatched redirect URI, wrong scope, etc.).

---

## Troubleshooting Quick Reference

| Symptom | Likely Cause |
|---|---|
| SSL handshake error in SM59 test | Missing root/intermediate CA in STRUST, or wrong PSE |
| `CX_OA2C` exception on `SET_TOKEN` | No token yet in OA2C_TOKEN_ADM — run initial "Get Token" flow |
| `invalid_grant` / `redirect_uri_mismatch` from Google | Redirect URI in OA2C_CONFIG doesn't exactly match Google Cloud Console entry |
| `invalid_scope` | Scope in client profile doesn't match what's enabled/consented on the Google Cloud side |
| Authorization missing error when running the config | User lacks S_OA2C_ADM / S_SEC_COMM (setup) or S_OA2C_USE (runtime) |
| `CX_OA2C_PROT_HTTP_FAILURE` in OA2C_GRANT when clicking Request Token | Usually the same certificate trust issue as Part 1, or a network/proxy/firewall block to Google's endpoints |

---

## References
- SAP Help Portal — *Configuring an OAuth 2.0 Client in the ABAP Platform (SOAUTH2_CLIENT)*
- SAP Community — *Configuring OAuth 2.0 and Creating an ABAP Program That Uses OAuth 2.0 Client API*
