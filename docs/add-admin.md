# Add an admin account

This guide explains how to grant a user access to the production admin
dashboard. The backend does not have a public admin-registration endpoint:
letting anyone register as an admin would expose the whole dashboard.

The dashboard is at:

```text
https://srv1518746.hstgr.cloud/admin
```

If your deployment uses a different domain, substitute it below.

## 1. Create the Firebase account

1. In Firebase Console, select the project whose ID matches
   `FIREBASE_PROJECT_ID` in the VPS's `backend/.env.production`.
2. Open **Authentication → Sign-in method** and enable **Email/Password**,
   **Google**, or whichever provider you intend to use.
3. Register an account through the Flutter app configured for this Firebase
   project, or create the user in **Authentication → Users** in Firebase
   Console.
4. For email/password accounts, verify the email address. Keep the Firebase
   login credentials private; they are not MySQL credentials.

## 2. Get the Firebase UID

In Firebase Console, open **Authentication → Users**, select the account, and
copy its **User UID**. Check that the account's email and project are the ones
you intend to grant access to. The UID identifies the account; it is not a
password.

## 3. Create the backend profile if it does not exist

The normal path is to sign in to the Flutter app with this Firebase account,
with the app configured to use the production API:

```text
https://srv1518746.hstgr.cloud
```

The app's authenticated `GET /api/v1/users/me` request verifies the Firebase
ID token and creates a MySQL profile for a new user with the `customer` role.
Then continue to step 4.

If the profile still does not appear, you can insert it directly in MySQL as
part of the controlled first-admin setup in step 4. Do not put the Firebase
password or ID token in SQL.

## 4. Grant the admin role on the VPS

Make sure the production schema migration has already completed before
running the SQL below.

SSH into the VPS and open MySQL from the deployed backend directory:

```sh
cd ~/fudokoma-app/backend
docker compose --env-file .env.production -f docker-compose.prod.yml exec mysql mysql -u root -p
```

Enter the `MYSQL_ROOT_PASSWORD` from `.env.production` at the password prompt.
Do not add the password to the command or shell history.

Select the configured database (the example deployment uses `follo_cart`) and
check whether the Firebase account already has a profile:

```sql
USE follo_cart;

SELECT id, firebase_uid, email, name, role, is_blocked
FROM users
WHERE firebase_uid = 'PASTE_FIREBASE_UID_HERE';
```

If exactly one row is returned, promote that existing account:

```sql
UPDATE users
SET role = 'admin', is_blocked = 0
WHERE firebase_uid = 'PASTE_FIREBASE_UID_HERE';

SELECT ROW_COUNT();
```

`ROW_COUNT()` should be `1`. If it is `0`, verify the UID, and check whether
the row was already an active admin. If it is greater than `1`, stop and
investigate before proceeding; Firebase UIDs should be unique.

If the `SELECT` returned no rows, create the profile and make it admin in one
statement, replacing all three example values with the Firebase account's
actual UID, email, and display name:

```sql
INSERT INTO users
    (id, firebase_uid, email, name, role, is_blocked, created_at, updated_at)
VALUES
    (
        REPLACE(UUID(), '-', ''),
        'PASTE_FIREBASE_UID_HERE',
        'admin@example.com',
        'Admin Name',
        'admin',
        0,
        UTC_TIMESTAMP(),
        UTC_TIMESTAMP()
    );
```

The Firebase UID must be copied exactly from Firebase Console. Do not use a
made-up UID, and do not insert a Firebase password or service-account secret
into MySQL.

Verify the account now has the intended role and is not blocked:

```sql
SELECT firebase_uid, email, role, is_blocked
FROM users
WHERE firebase_uid = 'PASTE_FIREBASE_UID_HERE';
```

Expected result: one row with `role` equal to `admin` and `is_blocked` equal to
`0`. Exit the MySQL prompt:

```sql
EXIT;
```

## 5. Sign in and verify

Open `/admin` on the deployment and sign in with the same verified Firebase
account. The dashboard checks the current MySQL role and blocked status; it
will reject an account that is not an active admin.

To check that the backend is running, visit:

```text
https://srv1518746.hstgr.cloud/api/v1/ready
```

## Optional username/password dashboard fallback

An optional `ADMIN_USERNAME` / `ADMIN_PASSWORD` fallback can be enabled in
`backend/.env.production` if Firebase dashboard sign-in is temporarily
unavailable. This is **not** Firebase login, does not create a MySQL user,
does not authenticate Flutter/API requests, and grants dashboard access
without checking a user's MySQL admin role. Use a unique password of at least
20 characters. After changing `.env.production`, recreate the API container:

```sh
docker compose --env-file .env.production -f docker-compose.prod.yml up -d --build --force-recreate api
```

Remove both fallback settings and recreate the API again when Firebase sign-in
works. Never use a short, reused, or previously shared password.

## Security reminders

- Never commit `.env.production` or the Firebase Admin SDK JSON key.
- Never share Firebase passwords, Firebase ID tokens, MySQL passwords, or
  private keys in chat.
- Grant admin only to trusted accounts. Use the dashboard's role controls for
  subsequent role changes instead of making manual SQL edits.
- MySQL, Redis, and the API port should not be exposed directly to the
  internet; access them through the Compose network.
