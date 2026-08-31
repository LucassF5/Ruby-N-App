# Posts CRUD, Profile, Settings — Design

Date: 2026-08-18
Status: Approved

## Context

RubyNative is a single-user Rails 8 app (no auth, no `User` model). It currently
has a bare-bones `Post` model (`title`, `body`) with index/create/destroy only,
and empty placeholder pages for `profile` and `settings`.

Goal: complete Post CRUD, add scheduling and privacy to posts, build a real
profile page (avatar, description, post count), and a real settings page that
controls how the home feed is displayed.

Because there is no login, `Profile` and `Setting` are **singletons** — one row
each, representing the single owner/app instance. No multi-tenancy.

## Data model

### `posts` (existing table, new columns)

| column | type | default | notes |
|---|---|---|---|
| `private` | boolean | `false` | never shown on home unless override |
| `scheduled_at` | datetime | `nil` | if future, post hidden until that time |

Migration: `add_column :posts, :private, :boolean, default: false, null: false`
and `add_column :posts, :scheduled_at, :datetime`.

### `profiles` (new table, singleton)

| column | type | notes |
|---|---|---|
| `description` | text | |
| `avatar` | Active Storage `has_one_attached` | not a DB column, join table |

Post count is **not stored** — computed on read via `Post.count`.

Singleton access pattern: `Profile.instance` class method does
`first_or_create!`.

### `settings` (new table, singleton)

| column | type | default | notes |
|---|---|---|---|
| `posts_per_page` | integer | `10` | limits home feed |
| `default_status_filter` | string | `"published"` | enum: `published`, `scheduled`, `private`, `all` |
| `show_private_posts` | boolean | `false` | overrides privacy hiding on home |
| `filter_from_date` | date | `nil` | optional default date range start |
| `filter_to_date` | date | `nil` | optional default date range end |

Singleton access pattern: `Setting.instance` (`first_or_create!`), same as
`Profile`.

Active Storage: requires running `bin/rails active_storage:install` to
generate the `active_storage_blobs`, `active_storage_attachments`,
`active_storage_variant_records` tables. No `image_processing` gem / variants
— avatar is rendered at natural size, constrained with CSS only (YAGNI).

## Post CRUD

Routes become full `resources :posts` (currently `only: [:index, :create,
:destroy]`). Add `show`, `edit`, `update` actions/views following existing
Tailwind styling conventions in `app/views/posts/index.html.erb`.

Form (shared partial `_form.html.erb`) gains:
- `scheduled_at` — `datetime_field`, optional
- `private` — checkbox

List/show views gain a status badge computed from a `Post#status` method:
- `scheduled` if `scheduled_at.present? && scheduled_at > Time.current`
- `private` if `private?`
- `published` otherwise

(scheduled + private can both be true; badge shows scheduled taking precedence
since it's not visible at all yet — private is the second-order state once
it's live)

## Visibility rule

There's no separate admin/management screen — `posts#index` is both the
public-style feed *and* the only place the owner manages posts (create form +
edit/delete live there). So the hard requirement ("scheduled hidden until due,
private hidden by default") only applies to the **default** view. Explicitly
selecting a status filter is an intentional owner action and is allowed to
surface hidden posts — otherwise a scheduled or private post would be
permanently unreachable from the UI (a real bug caught in spec self-review,
not present in the original approved chat design).

```ruby
scope :not_scheduled_future, -> { where("scheduled_at IS NULL OR scheduled_at <= ?", Time.current) }
scope :scheduled_future, -> { where("scheduled_at > ?", Time.current) }

def self.visible(setting = Setting.instance)
  relation = not_scheduled_future
  relation = relation.where(private: false) unless setting.show_private_posts
  relation
end
```

- **Default view** (no explicit `status` param — the common "just browsing
  home" case): `Post.visible(setting)`. Future-scheduled posts are always
  excluded here, no matter what. Private posts are excluded unless
  `Setting#show_private_posts` is on (this is exactly the "visualizar posts
  privados" toggle the user asked for, applied to the default view).
- **Explicit status filter** (`status=scheduled` / `status=private` /
  `status=all`, chosen via the filter dropdown that lives on Settings and can
  be overridden per-request via query param): bypasses the corresponding gate,
  because choosing it is the owner deliberately asking to manage that bucket.
  `status=scheduled` → `Post.scheduled_future`. `status=private` →
  `Post.where(private: true)`. `status=all` → `Post.all`. `status=published`
  behaves the same as the default view.

This keeps the literal ask intact (browse home = scheduled/private hidden by
default) while keeping every post reachable for editing/deleting through the
same page, via the filter control — no separate admin screen needed.

## Home feed (`PostsController#index`)

Reads `Setting.instance` for defaults, but accepts query params to override
per-request (no persistence of the override unless changed on the Settings
page):

- `params[:status]` → resolved per the Visibility rule above; defaults to
  `Setting#default_status_filter`
- `params[:from]` / `params[:to]` → filters `created_at` range, defaulting to
  `Setting#filter_from_date` / `filter_to_date` when params absent
- Pagination: simple `limit`/`offset` using `Setting#posts_per_page` (or
  `params[:per_page]` override) and `params[:page]` (default 1). No
  Kaminari/pagy — manual `.limit().offset()` plus a computed `total_pages` for
  prev/next links.

Filter application order: resolve status scope first (per Visibility rule),
then apply date narrowing, then order `created_at: :desc`, then paginate.

## Profile page

`GET /profile` — show avatar, description, `Post.count`.
`GET /profile/edit`, `PATCH /profile` — edit description + upload avatar.

`PagesController` gains `edit_profile`/`update_profile` or a dedicated
`ProfilesController` — going with a dedicated `ProfilesController` (singleton
resource: `resource :profile, only: [:show, :edit, :update]`) since it now has
real persistence logic, keeping `PagesController` for truly static pages only
(there may be none left — evaluate removal during implementation).

## Settings page

`GET /settings`, `PATCH /settings` — form for all `Setting` columns above.
Same pattern: dedicated `SettingsController` (`resource :setting, ...`)
replacing the `PagesController#settings` placeholder.

## Testing

Follow existing Minitest + fixtures convention:
- `test/models/post_test.rb` — extend with scheduling/privacy validation and
  `.visible` scope cases
- `test/models/profile_test.rb`, `test/models/setting_test.rb` — new,
  singleton behavior (`.instance` always returns same row)
- `test/controllers/posts_controller_test.rb` — extend with edit/update, plus
  visibility filtering assertions (scheduled/private posts excluded from
  default index; included when settings override; and included when
  explicitly requested via `status=scheduled`/`status=private`/`status=all`)
- `test/controllers/profiles_controller_test.rb`,
  `test/controllers/settings_controller_test.rb` — new

## Out of scope (explicitly)

- Multi-user auth — confirmed not wanted, single global singleton instead
- Separate admin/management screen — filter dropdown on the single index page
  covers reaching scheduled/private posts instead
- Image variants/resizing for avatar — raw attachment only
- Full-text search filter (only status + date filters, per user's selection)
