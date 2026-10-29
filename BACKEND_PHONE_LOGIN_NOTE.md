# Phone + Password Login — Backend Note (OriVex Party)

App side done:
- Intro page: "Quick Login" (guest) button removed → "Sign in with Phone" button.
- Phone login page: phone number + password only (no country code, no OTP),
  one "Login" button.
  The old `/check-phone` "Next" step is no longer called.

## 0. NO OTP

Login is phone number + password only. No OTP / SMS / Firebase phone verification.
- `/auth/login` with `type: "phone_pass"` must NOT require `firebase_id_token`,
  `otp`, `code` or any SMS verification.
- Do not send an OTP before or after login.

## 1. Login API (must work)

`POST {baseURL}/auth/login` (`baseURL` = `<domain>/api`)

Request body (JSON):
```json
{
  "type": "phone_pass",
  "phone": "01712345678",
  "password": "user_password",
  "device_token": "<device id>",
  "is_multi": false
}
```
- NO country code: `phone` arrives exactly as the user typed it
  (e.g. `01712345678`), no `+` and no country code. Store it in the DB the same
  way and match it with `where('phone', $request->phone)`.
- Phone must be unique in `users` (no two accounts with the same number).

Success response:
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "id": 123,
    "auth_token": "<sanctum / bearer token>",
    "is_first": false
  }
}
```
- `message` must ALWAYS be a string (app crashes if it is missing/null).
- `data.auth_token` is saved and sent later as `Authorization: Bearer <token>`.

Error responses (HTTP 4xx, the app shows `message` as a toast):
| Case | Response |
|---|---|
| Phone not registered | `422 {"success": false, "message": "This phone number is not registered"}` |
| Wrong password | `422 {"success": false, "message": "Wrong password"}` |
| User banned | `403 {"success": false, "message": "Your account is banned ..."}` |
| Validation | `422 {"success": false, "message": "The phone field is required"}` |

## 2. Laravel logic for `type == phone_pass`

```php
$request->validate([
    'phone'    => 'required|string',
    'password' => 'required|string',
]);

$user = User::where('phone', $request->phone)->first();
if (!$user) {
    return response()->json(['success' => false, 'message' => 'This phone number is not registered'], 422);
}
if (empty($user->password) || !Hash::check($request->password, $user->password)) {
    return response()->json(['success' => false, 'message' => 'Wrong password'], 422);
}
// ban check (same as other login types)

$user->update(['device_token' => $request->device_token]);
$token = $user->createToken('auth')->plainTextToken;

return response()->json([
    'success' => true,
    'message' => 'Login successful',
    'data'    => ['id' => $user->id, 'auth_token' => $token, 'is_first' => false],
]);
```
- Password must be stored with `Hash::make()` (bcrypt) — never plain text.
- Optional: rate-limit (e.g. `throttle:5,1`) to stop password guessing.

## 3. How users get a password

Users must have phone (no country code) + password in the `users` table. Pick what you need:

1. **Admin panel**: add "Phone" + "Set password" fields on the user edit page
   (save with `Hash::make`). Simplest option, no OTP.
2. The app's old register / forgot-password screens use Firebase OTP. They are
   NOT part of this login and are not needed. Since there is no OTP, phone
   accounts + passwords are created from the admin panel (option 1).
3. **Logged-in user sets/changes password**: `POST /account/reset_password`
   body `{phone, password, type}`. `firebase_id_token` must stay optional
   (no OTP).

## 4. Guest / Quick Login

The app no longer calls `type: "guest"`. Existing guest accounts keep working
only if they also get a phone + password (option 1 above). The guest code can
stay on the server; nothing needs to be deleted.

## 5. Test checklist
- [ ] Correct phone + password → logs in and opens home, with no OTP asked.
- [ ] Wrong password → toast "Wrong password".
- [ ] Unknown phone → toast "not registered".
- [ ] Banned user → ban message.
- [ ] Phone saved without country code (same as typed) in DB.
