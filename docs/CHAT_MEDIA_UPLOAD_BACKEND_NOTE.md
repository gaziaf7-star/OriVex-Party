# Chat (inbox) photo / video send – Backend Note (OriVex Party)

Host: `https://hello.im143.com`. Same chat media flow as the Im Chat app, which is already verified
working against its backend (`imchat.im143.com`). This backend must behave the same way.

## Confirmed failure (app log, 2026-10-13)
```
POST https://hello.im143.com/api/chatVideo
Body: { "name": "1000051708.jpg", "type": "image/jpeg", "size": 769135 }

-> 500 Internal Server Error  (4.4 s)
{ "status": false,
  "message": "Failed to generate upload URL: Credentials fetcher does not implement Google\Auth\SignBlobInterface" }
```
The request is valid. The storage is **Google Cloud Storage** and the server cannot create the signed upload URL
because the credentials it is using cannot sign. This happens when the app runs with Application Default
Credentials from the VM / Cloud Run metadata server (a "credentials fetcher") instead of a service-account key, so
there is no private key to sign with.

Fix (do ONE of these on the server):
1. **Service-account key (simplest).** Create a key (JSON) for the service account that owns the bucket, put the file on the server (outside the web root), and point the GCS disk at it: `key_file` / `keyFilePath` in `config/filesystems.php` (or `GOOGLE_APPLICATION_CREDENTIALS`). The JSON contains `private_key`, which is what V4 signing needs. The service account needs `Storage Object Admin` (or at least create/get objects) on the bucket.
2. **No key file (keyless signing).** Keep the metadata credentials, enable the *IAM Service Account Credentials API*, and grant the service account the role `Service Account Token Creator` **on itself**. Then sign through IAM (`signBlob`) – in the Google PHP client use `$object->signedUrl(..., ['version' => 'v4', 'method' => 'PUT', 'contentType' => $type])` with a credentials object that implements `SignBlobInterface` (for example `Google\Auth\Credentials\IAMCredentials` / `ImpersonatedServiceAccountCredentials`), not the plain `GCECredentials`.
3. **Alternative.** If you would rather not use GCS signing, let the app upload through your own endpoint (multipart `POST`) and we change the app to that.

After the change `POST /api/chatVideo` must return 200 with `upload_url` and `name` (see below). Make sure the bucket has a CORS rule for `PUT` and that the objects are publicly readable (or the public URL is served through your storage proxy).

## How the app sends a photo / video in the inbox
1. Ask the server for an upload link:
```
POST /api/chatVideo
Authorization: Bearer <token>
Body: { "name": "1000049836.jpg", "type": "image/jpeg", "size": 1094238, "folder": "chat" }
```
2. Server answers 200:
```
{ "upload_url": "<pre-signed PUT url>", "name": "<stored object name, e.g. chat/xyz.jpg>" }
```
3. App does `PUT <upload_url>` with the raw bytes (header `Content-Type` = the same mime type, NO `Authorization` header – the URL carries its own signature). Any 2xx = success.
4. App sends the message: `POST /api/Chat-Message` with the stored `name`. The public URL shown in the chat is built from `name` (same helper as profile images), so `name` must be the object path under the public storage root.

If step 1 returns an error (for example a generic 500) the message stays in the chat as "Resend Message" and the file is never uploaded.

## What the backend has to provide
1. `POST /api/chatVideo` exists and returns `200` + `upload_url` + `name` in < 500 ms. Accept `name`, `type`, `size` and the optional `folder` (the app sends `"chat"`; ignore it if you don't need it, but do not reject unknown keys).
2. The pre-signed URL must be valid for at least 30 minutes (videos are slow), allow `PUT`, and allow the sent content type and size (1 MB – 100 MB).
3. Storage driver credentials (S3 / MinIO / R2 / DO Spaces): key, secret, bucket, region, endpoint, `use_path_style_endpoint`. A wrong/expired key or a missing bucket is the usual reason for a 500 here – check `storage/logs/laravel.log` at the time of the request.
4. Bucket CORS / policy allows `PUT` from the app and the object is publicly readable, so `GET https://hello.im143.com/storage/<name>` shows the image.
5. Errors must be proper: `422` with a clear message for bad input, never a generic `500`.

## Message format the app relies on (do not change without telling us)
- Photo message: `type: "img"` (gif: `"gif"`, voice: `"voice"` or `"audio"`, video: `"video"`).
- `albums` is an ARRAY; the app shows `albums[0].file` (absolute URL).
- Same shape in the `/Chat-Message` response, `/v1/sync/rooms` -> `last_message`, the realtime push, and message history.

## `GET /api/user-status/{id}`
The app accepts both shapes: `{ "online": 1, "last_seen_at": "..." }` and `{ "status": true, "data": { "user_id": .., "online": 1, "last_seen_at": ".." } }` (`online` may be `0/1` or `true/false`).
- Send `Cache-Control: private, max-age=10` (the app caches it for 10 s).
- Keep `last_seen_at` fresh (update on socket connect/disconnect or any authenticated request, keep in Redis). A value that stays at an old date for hours makes users look offline.

## Speed (target < 300 ms each, read / user-status / token < 100 ms)
Chat endpoints: `POST /Chat-Message`, `POST /Chat-room/{id}/read`, `GET /v1/sync/rooms`, `GET /user-status/{id}`, `POST /centrifugo/token`, `GET /role-requests`, `POST /chatVideo`.
- Redis cache for `user-status`, `centrifugo/token`, `role-requests` and the first page of `sync/rooms`.
- `Chat-room/{id}/read`: only set `last_read_seq` (one UPDATE / Redis) and return; do counters and notifications in a queue.
- `Chat-Message`: publish to the realtime server first, persist / notify after the response.
- Octane (Swoole / RoadRunner) or at least opcache + `config:cache` + `route:cache`.

## Test checklist
1. `POST /api/chatVideo` with the body above returns 200 + `upload_url` + `name` in < 500 ms.
2. `PUT upload_url` with the image bytes returns 200.
3. `GET https://hello.im143.com/storage/<name>` shows the image.
4. `POST /api/Chat-Message` returns `type: "img"` and `albums: [{ "file": ... }]`.
5. The other user receives the photo through the realtime push with `albums[0].file`.
6. Same for a ~20 MB `video/mp4`.
