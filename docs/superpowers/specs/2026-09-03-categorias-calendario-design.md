# Categorias + Calendário de Plantões — Design

Date: 2026-09-03
Status: Approved

## Context

[[Fase 1 (Meus Plantões)|2026-09-03-plantoes-fase1-design.md]] shipped a
flat list CRUD for `Plantao` and explicitly deferred any calendar-grid UI
("No calendar grid UI in this phase — explicitly chosen over a month-view
calendar to keep the prototype simple and avoid a JS calendar dependency").

This design reverses that specific deferral (not the "no JS lib" part —
the calendar grid stays server-rendered, no JS calendar dependency added)
and adds a new concept: **Categoria** (e.g. "Hospital X"), which bundles a
name, a default time range, and a color. Categories exist to make shift
creation from a calendar faster: pick a day, pick a category, done — no
retyping times/local each time.

Two flows now coexist:
1. **List flow** (existing, `/`) — free-text form, category optional.
2. **Calendar flow** (new, `/calendario`) — click a day, pick a category
   from a modal, shift is created with the category's time range applied
   automatically.

## Data model

### `categorias` (new table)

| column | type | notes |
|---|---|---|
| `nome` | string | required |
| `cor` | string | required, hex color (e.g. `#4f46e5`) |
| `hora_inicio` | time | required |
| `hora_fim` | time | required |

Validations: presence on all four; `hora_fim` must be after `hora_inicio`
(same pattern as `Plantao`, same-day only).

### `plantoes` (existing table, add column)

| column | type | notes |
|---|---|---|
| `categoria_id` | references, nullable | optional — plantões created via the list form may have no category |

`belongs_to :categoria, optional: true`. On `Categoria` destroy, associated
plantões keep existing (`dependent: :nullify` on the `has_many` side) —
deleting a category never deletes shift history.

**Auto-fill callback** (`Plantao`, `before_validation`): if `categoria` is
present and `hora_inicio`/`hora_fim` are blank, copy them from
`categoria.hora_inicio` / `categoria.hora_fim`. This lets the calendar
modal submit only `categoria_id` + `data` and still pass presence
validation. The list form's typed-in times are never overwritten (only
blank fields are filled).

`local` is untouched by category selection — it stays a free-text field
independent of `categoria.nome`. Views display `categoria.nome` (with its
color) when present, falling back to `local` otherwise.

## Routes

```ruby
resources :categorias
resources :plantoes, except: [:show]
get "calendario", to: "calendario#show", as: :calendario
get "calendario/:data", to: "calendario#dia", as: :calendario_dia,
    constraints: { data: /\d{4}-\d{2}-\d{2}/ }
root "plantoes#index"
```

No `show` for either resource — same rationale as Fase 1 (list/edit forms
cover the CRUD loop; the calendar day view covers per-day inspection).

## Controllers

- `CategoriasController` — standard `index, new, create, edit, update,
  destroy`.
- `CalendarioController`:
  - `#show` — computes the month grid for `params[:mes]` (format
    `YYYY-MM`, defaults to current month), loads
    `Plantao.where(data: month_range).includes(:categoria)` grouped by
    `data` to know which colors to dot on each day.
  - `#dia` — renders the `turbo_frame_tag "day_modal"` partial for
    `params[:data]`: plantões of that day (with categoria color/name or
    local, remove button) + a form with just a `categoria` select and a
    hidden `data` field, posting to `plantoes#create`.
- `PlantoesController#create` / `#destroy` — accept an optional top-level
  `return_to` param. If present and it starts with `/`, redirect there
  instead of `root_path` (used by the calendar modal to redirect back into
  `calendario_dia_path` instead of the list). Any other value (or absent)
  falls back to `root_path` — prevents open redirect.
  `plantao_params` gains `:categoria_id`.

## Views

- `app/views/calendario/show.html.erb`: month grid, Sunday-start weeks,
  prev/next month links (`?mes=YYYY-MM`, plain links, no JS). Each day
  cell with plantões shows one small colored dot per distinct category
  present that day (gray dot for category-less plantões), and links (as a
  Turbo Frame trigger) to `calendario_dia_path`. Header has a "Gerenciar
  categorias" link to `/categorias`.
- `app/views/calendario/dia.html.erb` (or a partial): the `day_modal`
  Turbo Frame content — list of that day's plantões (categoria badge +
  time range, remove button with `return_to` set to the current day's
  `calendario_dia_path`) plus the add-plantao mini-form (categoria select
  + hidden date, `return_to` likewise set to the day frame).
- `app/views/plantoes/index.html.erb`: unchanged list, gains a "Ver
  calendário" link to `/calendario`.
- `app/views/plantoes/_form.html.erb`: gains an optional categoria
  `select` (blank option first). Existing time/local fields stay
  untouched — no client-side auto-fill JS in this flow, matching "form da
  lista fica como está" otherwise.
- `app/views/categorias/`: `index.html.erb` (name, color swatch, time
  range, edit/remove), `_form.html.erb` (`nome` text_field, `cor`
  `color_field`, `hora_inicio`/`hora_fim` time_field), `new.html.erb` /
  `edit.html.erb` thin wrappers — same conventions as `plantoes`.

## Error handling

- Categoria `hora_fim <= hora_inicio`: same validation/message pattern as
  `Plantao`.
- `return_to` sanitized to same-origin relative paths only (`starts_with?("/")`),
  else `root_path`.
- Deleting a categoria in use: allowed, plantões become category-less
  (`dependent: :nullify`), never blocked or cascade-deleted.

## Testing

Follow existing Minitest + fixtures convention:
- `test/models/categoria_test.rb` — presence validations, `hora_fim` >
  `hora_inicio`.
- `test/models/plantao_test.rb` — add: optional `categoria` association,
  auto-fill of `hora_inicio`/`hora_fim` from categoria when blank, no
  overwrite when already present.
- `test/controllers/categorias_controller_test.rb` — index/new/create/
  edit/update/destroy, destroy nullifies rather than blocking.
- `test/controllers/calendario_controller_test.rb` — `#show` renders
  current month by default and a given `?mes=`; `#dia` renders plantões
  for that date plus the add form.
- `test/controllers/plantoes_controller_test.rb` — add: create with
  `categoria_id` fills times via callback; create/destroy honor
  `return_to` when it's a relative path and ignore it otherwise.

## Out of scope

- Editing a plantão's category after creation via the calendar modal
  (still done through the existing `plantoes#edit` form).
- Reordering or archiving categories.
- Any visual distinction for overlapping/conflicting shifts on the same
  day beyond the colored dots.
- Fase 2 (lembrete automático) and Fase 3 (indisponibilidade) — untouched,
  still deferred per the Fase 1 design.
