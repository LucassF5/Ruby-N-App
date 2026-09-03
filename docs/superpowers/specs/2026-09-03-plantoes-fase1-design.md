# Plantões — Fase 1 (Meus Plantões) — Design

Date: 2026-09-03
Status: Approved

## Context

RubyNative is a single-user Rails 8 demo app (no auth, no `User` model),
shipped as a native mobile shell via the `ruby_native` gem (tabs: Home,
Profile, Settings). It currently has a bare `Post` model used only to
demonstrate the gem's CRUD/navigation flow for a talk.

New direction: the app's primary purpose becomes individual on-call/shift
management ("gestão de plantões") for healthcare/security workers — a single
user registers, views, and (later) gets reminders for their own shifts.

Full product scope spans three phases:
1. **Meus Plantões** — CRUD + list of shifts (this design)
2. **Lembrete automático** — local notification before a shift starts
3. **Indisponibilidade** — marking unavailable days on a calendar

This design covers **Fase 1 only**. Fases 2 and 3 are deliberately deferred
(see Out of scope) and documented here only to keep the data model and
navigation choices from painting Fase 1 into a corner.

Constraints carried over from the original product spec: single user, no
login, no remote backend/sync — everything lives in the local SQLite DB.

## Data model

### `plantoes` (new table, replaces `posts`)

| column | type | notes |
|---|---|---|
| `data` | date | required |
| `hora_inicio` | time | required |
| `hora_fim` | time | required |
| `local` | string | optional |
| `observacao` | text | optional |

No `user_id` — single-user app, no ownership scoping needed.

Migration: `create_plantoes` (new table) + a second migration dropping the
`posts` table. `Post` model, controller, views, tests, and fixture are
deleted outright (demo content, not needed going forward).

Validations: `data`, `hora_inicio`, `hora_fim` presence; `hora_fim` must be
after `hora_inicio` (same-day shift only — overnight shifts crossing
midnight are out of scope for this prototype).

## Controller/Routes

`PlantoesController` with `index, new, create, edit, update, destroy`
(no `show` — the index list plus the edit form cover the full CRUD loop,
matching the "lista simples" UI decision below). Root route becomes
`plantoes#index`.

```ruby
resources :plantoes, except: [:show]
root "plantoes#index"
```

## Views

- `index.html.erb`: flat list ordered by `data, hora_inicio` (ascending —
  soonest shift first). Each row shows date, time range, local (if present),
  and Editar/Remover links. Empty state message when there are no plantões.
- `_form.html.erb`: shared between `new`/`edit` — `data` (date_field),
  `hora_inicio`/`hora_fim` (time_field), `local` (text_field, optional),
  `observacao` (text_area, optional).
- `new.html.erb` / `edit.html.erb`: thin wrappers rendering `_form`, matching
  the existing Tailwind styling conventions used in the current `posts`
  views.

No calendar grid UI in this phase — explicitly chosen over a month-view
calendar to keep the prototype simple and avoid a JS calendar dependency.

## Navigation

- `_navbar.html.erb`: no changes needed beyond what already exists (it does
  not currently reference Posts by name).
- `config/ruby_native.yml`: tabs unchanged (Home `/`, Profile, Settings) —
  Home's path already points at `/`, which now resolves to
  `plantoes#index`. Profile stays as-is (placeholder, unrelated to
  plantões, kept per explicit decision rather than removed).

## Testing

Follow existing Minitest + fixtures convention:
- `test/models/plantao_test.rb` — presence validations, `hora_fim` >
  `hora_inicio` validation
- `test/controllers/plantoes_controller_test.rb` — index/new/create/edit/
  update/destroy, replacing `posts_controller_test.rb`
- Remove `test/models/post_test.rb`, `test/controllers/posts_controller_test.rb`,
  `test/fixtures/posts.yml`

## Out of scope (explicitly, deferred to later specs)

- **Fase 2 — Lembrete automático**: blocked on a decision the user will
  provide later. The `ruby_native` gem only exposes *remote* push
  (device-token registration + Apple webhook), which needs a live backend —
  conflicting with the "100% local, no remote backend" constraint. No
  `Notificacao`/reminder scheduling code, columns, or jobs are added in this
  phase.
- **Fase 3 — Indisponibilidade**: no `indisponibilidades` table, no
  calendar view, no visual marking of unavailable days in this phase.
- Calendar/month-grid view of plantões (list view chosen instead).
- Multi-user, auth, shift trading, cloud sync — excluded per original
  product scope.
