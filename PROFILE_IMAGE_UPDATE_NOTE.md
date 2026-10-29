# Profile picture / name update — where it goes stale (OriVex Party)

After a user saves a new profile picture/name, some screens show the new one and
some keep the old one. There are two sources of stale data:

- **Server copies:** the backend stores a *copy* of the user's image/name in
  other tables and caches, and only the main `users`/profile row is updated.
- **App caches:** the app keeps its own copies on the phone.

---

## A. Backend (most of the problem)

When `POST /api/...add-info` (profile update) saves a new image or name, every
place that holds a **copy** of it must be updated too, or must read it live.

### 1. Find every copied image/name column
Search the DB for columns that store a user's picture/name outside `users`:
```
owner_image, owner_name, user_image, user_name, sender_image, sender_name,
avatar, image, name (on rooms, chat_rooms, chat_members, moments, comments,
family_members, agency_members, coin_sellers/resellers, rankings, gifts_log …)
```
Seen in API responses as copies:
- `/api/rooms`, `/api/rooms/mine` → `owner_image`, `owner_name`, `room_name`
- `/api/v1/sync/rooms` (chat list) → `title`, `avatar` per conversation
- `/api/ranking/top_user_ranking` → `sender[]`, `receiver[]` image lists
- `/api/countries` → `supporters[].avatar`, `supporters[].name`
- reseller / coin-seller list, family list, agency host list

**Best fix:** stop storing copies and return `users.image`/`users.name` through
a relation (`with('user')`), or a model accessor.

**If copies must stay:** add a `User::updated` observer that syncs them:
```php
// app/Observers/UserObserver.php
public function updated(User $user): void
{
    if (!$user->wasChanged(['image', 'name'])) return;

    Room::where('owner_id', $user->id)->update([
        'owner_image' => $user->image,
        'owner_name'  => $user->name,
    ]);
    ChatRoomMember::where('user_id', $user->id)->update([
        'avatar' => $user->image, 'title' => $user->name,
    ]);
    // …same for every table found in step 1

    Cache::forget("user:{$user->id}");
    Cache::tags(['rankings', 'rooms', 'countries'])->flush(); // if tags are used
}
```
Register it in `AppServiceProvider::boot()`: `User::observe(UserObserver::class);`

### 2. Clear server caches
Ranking, room list, country supporters and `my-data` responses are often cached
(Redis / `Cache::remember`). Clear the user's keys on profile update (above), or
keep these caches short (1–5 min).

### 3. Always save a NEW file name
Every upload must produce a new path (`profile/<new-hash>.jpg`), never
overwrite the same file name. The app caches images **by URL**, so the same URL
means the phone keeps showing the old picture.

### 4. Tell other users in real time (optional, best)
After the update, publish a Centrifugo event to the rooms/chats the user is in:
```json
{ "action_type": "user_profile_updated", "user_id": 123,
  "name": "New Name", "image": "profile/<new-hash>.jpg" }
```
The app can then refresh that user everywhere without a restart (app side
needs a small handler for this event).

### 5. Profile update response
`data` must contain the new `profile.image` and `name` (the app already uses
these to update the user's own mic seat while inside a room).

---

## B. App (what already happens / what can be added)

Already done after a successful update (`edit_information_bloc.dart`):
- `my-data` is fetched again → own profile page/header update.
- Own entry in the room user cache (`UsersCache`) is removed.
- If inside a room, own seat avatar/name is re-published to the seat.

Still stale on the app side:
1. **`UsersCache` (Hive, `ROOM_USERS_BOX`) never expires.** Other users'
   picture/name is cached on each phone forever. Viewers keep seeing the old
   picture in room profile cards, visitor list, gift recipients, @mention and
   invite-to-mic lists. Fix: add a time limit (e.g. 30 min) or clear it when
   the app starts.
2. **Chat list / messages DB (`avatarUrl`, `avatarCache`).** It stores the
   peer's avatar locally and only updates when `/v1/sync/rooms` sends a new
   `avatar`. It only updates once the backend fixes A.1.
3. **Seats in a room the user is NOT in.** Seat attributes are written on
   join. Other rooms show the new picture only after the user re-joins.

---

## Test checklist
- [ ] Change picture → own profile, home "my room" card, room seat update.
- [ ] Another phone: room list owner image, chat list, ranking, country
      supporters show the new picture (after refresh).
- [ ] New picture has a NEW URL (not the same file name).
