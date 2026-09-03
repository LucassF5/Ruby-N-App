# Categorias + Calendário de Plantões Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user define reusable shift categories (name, default time range, color) and create/view shifts from a month calendar, where clicking a day opens a modal to pick a category (auto-filling its time range) and the day gets marked with the category's color.

**Architecture:** Two new Rails resources (`Category`, and a `CalendarController` that is view-only over `Shift`/`Category`) layered onto the existing `Shift` CRUD (renamed from the original `Plantao`/`plantoes` naming — see Task 5). The calendar's day modal is a Turbo Frame (`day_modal`) that swaps in place without a full page reload; the app currently ships zero JS (no Turbo/Stimulus/importmap), so Task 1 adds the minimum Turbo setup first.

**Naming note:** Tasks 1-4 were implemented (and reviewed, and committed) under the original Portuguese naming (`Categoria`/`categorias`, `Plantao`/`plantoes`) before this rule was adopted mid-execution. Task 5 renames everything built so far — plus the pre-existing `Plantao`/`plantoes` code from the earlier Fase 1 work — to English. Tasks 6-8 (originally numbered 5-7) are written directly against the post-rename English names.

**Tech Stack:** Rails 8.1, Propshaft, SQLite, Minitest + fixtures, Tailwind (already set up), Turbo (`turbo-rails` + `importmap-rails`, added in Task 1 — no Stimulus, no custom JS).

**Spec:** `docs/superpowers/specs/2026-09-03-categorias-calendario-design.md`

## Global Constraints

- Single-user app, no auth, no `user_id` scoping anywhere.
- 100% local SQLite — no remote backend, no sync.
- Minitest + fixtures convention (`fixtures :all` in `test/test_helper.rb`) — every new table needs a `test/fixtures/<table>.yml`.
- Tailwind utility classes matching existing views' style (white cards, `border-slate-200`, `indigo-600` accents, `rounded-lg`/`rounded` mix as already used).
- No `show` action for either `Category` or `Shift` — list + edit form cover the CRUD loop (`resources ..., except: [:show]`).
- Week grid starts on Sunday.
- `return_to` param (on `shifts#create`/`#destroy`) is only honored when it starts with `/`; otherwise fall back to `root_path` (open-redirect guard).
- Deleting a `Category` in use must nullify (`dependent: :nullify`), never block or cascade-delete `Shift` rows.
- No Stimulus, no custom JS controllers — Turbo Frames alone are sufficient for this feature.
- **English-only code, Portuguese-only content (added after Task 4, applies from Task 5 onward):** every Ruby/Rails identifier — model and class names, file and directory names, controller/action names, route names and URL path segments, method and variable names, database table and column names, fixture file names and fixture label keys — must be in English. The **only** things that stay in Portuguese are user-facing view text: headings, labels, button text, flash notices, validation error message strings, and example/seed data values that represent real-world Portuguese-language content (e.g. a category's sample `name` like "Hospital X" is data, not code, and stays as-is).

---

### Task 1: Add Turbo (turbo-rails + importmap-rails)

**Files:**
- Modify: `Gemfile`
- Create: `config/importmap.rb`
- Create: `app/javascript/application.js`
- Modify: `app/views/layouts/application.html.erb`

**Interfaces:**
- Produces: `javascript_importmap_tags` available in layouts; `turbo_frame_tag` / `turbo-frame` navigation available in all views from Task 6+ onward.

- [ ] **Step 1: Run the full test suite to confirm a green baseline**

Run: `bin/rails test`
Expected: all existing tests PASS (baseline before touching anything).

- [ ] **Step 2: Add the gems**

In `Gemfile`, after the `tailwindcss-rails` line, add:

```ruby
gem "turbo-rails"
gem "importmap-rails"
```

- [ ] **Step 3: Install**

Run: `bundle install`
Expected: `Gemfile.lock` gains `turbo-rails` and `importmap-rails` (and their deps, e.g. `actioncable`).

- [ ] **Step 4: Create the importmap config**

Create `config/importmap.rb`:

```ruby
pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
```

- [ ] **Step 5: Create the JS entrypoint**

Create `app/javascript/application.js`:

```js
import "@hotwired/turbo-rails"
```

- [ ] **Step 6: Wire the importmap tags into the layout**

In `app/views/layouts/application.html.erb`, find:

```erb
    <%= stylesheet_link_tag :ruby_native %>
  </head>
```

Replace with:

```erb
    <%= stylesheet_link_tag :ruby_native %>

    <%= javascript_importmap_tags %>
  </head>
```

- [ ] **Step 7: Run the full test suite again**

Run: `bin/rails test`
Expected: all tests still PASS (Turbo is loaded but nothing uses it yet, so behavior is unchanged).

- [ ] **Step 8: Commit**

```bash
git add Gemfile Gemfile.lock config/importmap.rb app/javascript/application.js app/views/layouts/application.html.erb
git commit -m "Add Turbo (turbo-rails + importmap-rails) for the calendar day modal"
```

---

### Task 2: Categoria model

**Files:**
- Create: `db/migrate/[timestamp]_create_categorias.rb`
- Create: `app/models/categoria.rb`
- Create: `test/fixtures/categorias.yml`
- Test: `test/models/categoria_test.rb`

**Interfaces:**
- Produces: `Categoria` model with attributes `nome:string`, `cor:string`, `hora_inicio:time`, `hora_fim:time`, presence validations on all four, and a `hora_fim > hora_inicio` validation matching `Plantao`'s pattern. `categorias(:hospital_x)` and `categorias(:posto_sul)` fixtures for later tasks.

- [ ] **Step 1: Write the failing model test**

Create `test/models/categoria_test.rb`:

```ruby
require "test_helper"

class CategoriaTest < ActiveSupport::TestCase
  test "valid with nome, cor, hora_inicio, hora_fim" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: "07:00", hora_fim: "19:00")
    assert categoria.valid?
  end

  test "invalid without nome" do
    categoria = Categoria.new(nome: nil, cor: "#4f46e5", hora_inicio: "07:00", hora_fim: "19:00")
    assert_not categoria.valid?
  end

  test "invalid without cor" do
    categoria = Categoria.new(nome: "Hospital X", cor: nil, hora_inicio: "07:00", hora_fim: "19:00")
    assert_not categoria.valid?
  end

  test "invalid without hora_inicio" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: nil, hora_fim: "19:00")
    assert_not categoria.valid?
  end

  test "invalid without hora_fim" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: "07:00", hora_fim: nil)
    assert_not categoria.valid?
  end

  test "invalid when hora_fim is before hora_inicio" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: "19:00", hora_fim: "07:00")
    assert_not categoria.valid?
    assert_includes categoria.errors[:hora_fim], "deve ser depois do horário de início"
  end

  test "invalid when hora_fim equals hora_inicio" do
    categoria = Categoria.new(nome: "Hospital X", cor: "#4f46e5", hora_inicio: "07:00", hora_fim: "07:00")
    assert_not categoria.valid?
  end
end
```

- [ ] **Step 2: Run it and confirm it fails**

Run: `bin/rails test test/models/categoria_test.rb`
Expected: FAIL with `NameError: uninitialized constant CategoriaTest::Categoria` (no fixture file exists yet, so this is safe to run before Step 3).

- [ ] **Step 3: Create and run the migration**

Run: `bin/rails generate migration CreateCategorias`

Replace the generated file's contents with:

```ruby
class CreateCategorias < ActiveRecord::Migration[8.1]
  def change
    create_table :categorias do |t|
      t.string :nome, null: false
      t.string :cor, null: false
      t.time :hora_inicio, null: false
      t.time :hora_fim, null: false

      t.timestamps
    end
  end
end
```

Run: `bin/rails db:migrate`
Expected: `db/schema.rb` now includes a `categorias` table.

- [ ] **Step 4: Create the model**

Create `app/models/categoria.rb`:

```ruby
class Categoria < ApplicationRecord
  validates :nome, presence: true
  validates :cor, presence: true
  validates :hora_inicio, presence: true
  validates :hora_fim, presence: true
  validate :hora_fim_depois_da_hora_inicio

  private

  def hora_fim_depois_da_hora_inicio
    return if hora_inicio.blank? || hora_fim.blank?

    errors.add(:hora_fim, "deve ser depois do horário de início") if hora_fim <= hora_inicio
  end
end
```

- [ ] **Step 5: Run the test again and confirm it passes**

Run: `bin/rails test test/models/categoria_test.rb`
Expected: PASS (7 tests).

- [ ] **Step 6: Add fixtures (needed by later tasks)**

Create `test/fixtures/categorias.yml`:

```yaml
hospital_x:
  nome: Hospital X
  cor: "#4f46e5"
  hora_inicio: "07:00"
  hora_fim: "19:00"

posto_sul:
  nome: Posto Sul
  cor: "#16a34a"
  hora_inicio: "13:00"
  hora_fim: "19:00"
```

- [ ] **Step 7: Run the full suite to confirm the new fixture loads cleanly**

Run: `bin/rails test`
Expected: all tests PASS (fixture loading doesn't break anything since the table already exists).

- [ ] **Step 8: Commit**

```bash
git add db/migrate db/schema.rb app/models/categoria.rb test/models/categoria_test.rb test/fixtures/categorias.yml
git commit -m "Add Categoria model"
```

---

### Task 3: Plantao ↔ Categoria association + time auto-fill

**Files:**
- Create: `db/migrate/[timestamp]_add_categoria_to_plantoes.rb`
- Modify: `app/models/plantao.rb`
- Modify: `app/models/categoria.rb`
- Test: `test/models/plantao_test.rb`

**Interfaces:**
- Consumes: `Categoria` (Task 2) — `hora_inicio`, `hora_fim`.
- Produces: `Plantao#categoria` (optional `belongs_to`), `Categoria#plantoes` (nullified on categoria destroy), `Plantao`'s `hora_inicio`/`hora_fim` auto-filled from its `categoria` on `before_validation` when blank (never overwritten when already set).

- [ ] **Step 1: Write the failing tests**

Append to `test/models/plantao_test.rb` (inside the `class PlantaoTest < ActiveSupport::TestCase` block, before the final `end`):

```ruby
  test "valid with categoria and no explicit hora_inicio/hora_fim" do
    categoria = categorias(:hospital_x)
    plantao = Plantao.new(data: Date.new(2026, 9, 10), categoria: categoria)

    assert plantao.valid?
    assert_equal categoria.hora_inicio, plantao.hora_inicio
    assert_equal categoria.hora_fim, plantao.hora_fim
  end

  test "keeps explicit hora_inicio/hora_fim even with categoria set" do
    categoria = categorias(:hospital_x)
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "09:00", hora_fim: "10:00", categoria: categoria)

    assert plantao.valid?
    assert_equal "09:00", plantao.hora_inicio.strftime("%H:%M")
    assert_equal "10:00", plantao.hora_fim.strftime("%H:%M")
  end

  test "valid without categoria" do
    plantao = Plantao.new(data: Date.new(2026, 9, 10), hora_inicio: "08:00", hora_fim: "14:00")
    assert plantao.valid?
    assert_nil plantao.categoria
  end

  test "destroying categoria nullifies associated plantao" do
    categoria = categorias(:hospital_x)
    plantao = Plantao.create!(data: Date.new(2026, 9, 10), categoria: categoria)

    categoria.destroy

    assert_nil plantao.reload.categoria_id
  end
```

- [ ] **Step 2: Run and confirm failure**

Run: `bin/rails test test/models/plantao_test.rb`
Expected: FAIL with `NoMethodError` / `ActiveModel::UnknownAttributeError` on `categoria=` (column and association don't exist yet).

- [ ] **Step 3: Create and run the migration**

Run: `bin/rails generate migration AddCategoriaToPlantoes`

Replace the generated file's contents with:

```ruby
class AddCategoriaToPlantoes < ActiveRecord::Migration[8.1]
  def change
    add_reference :plantoes, :categoria, foreign_key: true, null: true
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 4: Update the models**

Replace `app/models/plantao.rb` with:

```ruby
class Plantao < ApplicationRecord
  belongs_to :categoria, optional: true

  before_validation :aplicar_horario_da_categoria

  validates :data, presence: true
  validates :hora_inicio, presence: true
  validates :hora_fim, presence: true
  validate :hora_fim_depois_da_hora_inicio

  private

  def aplicar_horario_da_categoria
    return unless categoria

    self.hora_inicio ||= categoria.hora_inicio
    self.hora_fim ||= categoria.hora_fim
  end

  def hora_fim_depois_da_hora_inicio
    return if hora_inicio.blank? || hora_fim.blank?

    errors.add(:hora_fim, "deve ser depois do horário de início") if hora_fim <= hora_inicio
  end
end
```

Replace `app/models/categoria.rb`'s first line (`class Categoria < ApplicationRecord`) block to add the association — full file:

```ruby
class Categoria < ApplicationRecord
  has_many :plantoes, dependent: :nullify

  validates :nome, presence: true
  validates :cor, presence: true
  validates :hora_inicio, presence: true
  validates :hora_fim, presence: true
  validate :hora_fim_depois_da_hora_inicio

  private

  def hora_fim_depois_da_hora_inicio
    return if hora_inicio.blank? || hora_fim.blank?

    errors.add(:hora_fim, "deve ser depois do horário de início") if hora_fim <= hora_inicio
  end
end
```

- [ ] **Step 5: Run and confirm pass**

Run: `bin/rails test test/models/plantao_test.rb`
Expected: PASS (all tests, old and new).

- [ ] **Step 6: Run the full suite**

Run: `bin/rails test`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add db/migrate db/schema.rb app/models/plantao.rb app/models/categoria.rb test/models/plantao_test.rb
git commit -m "Associate Plantao with Categoria, auto-fill horário from categoria"
```

---

### Task 4: Categorias CRUD (controller + views + routes)

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/categorias_controller.rb`
- Create: `app/views/categorias/index.html.erb`
- Create: `app/views/categorias/_form.html.erb`
- Create: `app/views/categorias/new.html.erb`
- Create: `app/views/categorias/edit.html.erb`
- Test: `test/controllers/categorias_controller_test.rb`

**Interfaces:**
- Consumes: `Categoria` (Task 2/3).
- Produces: `categorias_path`, `new_categoria_path`, `edit_categoria_path`, `categoria_path` route helpers used by Task 6/7's "Gerenciar categorias" link and the calendar day form's category select.

- [ ] **Step 1: Write the failing controller test**

Create `test/controllers/categorias_controller_test.rb`:

```ruby
require "test_helper"

class CategoriasControllerTest < ActionDispatch::IntegrationTest
  setup do
    @categoria = categorias(:hospital_x)
  end

  test "should get index" do
    get categorias_url
    assert_response :success
  end

  test "should get new" do
    get new_categoria_url
    assert_response :success
  end

  test "should create categoria" do
    assert_difference("Categoria.count") do
      post categorias_url, params: { categoria: { nome: "Hospital Y", cor: "#f97316", hora_inicio: "08:00", hora_fim: "20:00" } }
    end

    assert_redirected_to categorias_url
  end

  test "should not create categoria with invalid times" do
    assert_no_difference("Categoria.count") do
      post categorias_url, params: { categoria: { nome: "Hospital Y", cor: "#f97316", hora_inicio: "20:00", hora_fim: "08:00" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_categoria_url(@categoria)
    assert_response :success
  end

  test "should update categoria" do
    patch categoria_url(@categoria), params: { categoria: { nome: "Hospital X Renovado" } }
    assert_redirected_to categorias_url
    assert_equal "Hospital X Renovado", @categoria.reload.nome
  end

  test "should destroy categoria" do
    assert_difference("Categoria.count", -1) do
      delete categoria_url(@categoria)
    end

    assert_redirected_to categorias_url
  end

  test "destroying categoria nullifies associated plantoes instead of blocking" do
    plantao = Plantao.create!(data: Date.new(2026, 9, 10), categoria: @categoria)

    delete categoria_url(@categoria)

    assert_nil plantao.reload.categoria_id
  end
end
```

- [ ] **Step 2: Run and confirm it fails**

Run: `bin/rails test test/controllers/categorias_controller_test.rb`
Expected: FAIL with a routing error (`categorias_url` undefined — no route yet).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, add `resources :categorias, except: [:show]` above `resources :plantoes, except: [:show]`:

```ruby
  resources :categorias, except: [:show]
  resources :plantoes, except: [:show]
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/categorias_controller.rb`:

```ruby
class CategoriasController < ApplicationController
  before_action :set_categoria, only: [:edit, :update, :destroy]

  def index
    @categorias = Categoria.order(:nome)
  end

  def new
    @categoria = Categoria.new
  end

  def create
    @categoria = Categoria.new(categoria_params)

    if @categoria.save
      redirect_to categorias_path, notice: "Categoria criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @categoria.update(categoria_params)
      redirect_to categorias_path, notice: "Categoria atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @categoria.destroy
    redirect_to categorias_path, notice: "Categoria removida."
  end

  private

  def set_categoria
    @categoria = Categoria.find(params[:id])
  end

  def categoria_params
    params.require(:categoria).permit(:nome, :cor, :hora_inicio, :hora_fim)
  end
end
```

- [ ] **Step 5: Create the views**

Create `app/views/categorias/_form.html.erb`:

```erb
<%= form_with model: categoria, class: "bg-white border border-slate-200 rounded-lg p-4 mb-8 flex flex-col gap-3" do |f| %>
  <% if categoria.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% categoria.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <%= f.label :nome, "Nome", class: "text-sm font-medium" %>
  <%= f.text_field :nome, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :cor, "Cor", class: "text-sm font-medium" %>
  <%= f.color_field :cor, class: "border border-slate-300 rounded h-10 w-20" %>

  <%= f.label :hora_inicio, "Horário de início", class: "text-sm font-medium" %>
  <%= f.time_field :hora_inicio, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :hora_fim, "Horário de término", class: "text-sm font-medium" %>
  <%= f.time_field :hora_fim, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.submit "Salvar", class: "self-start bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 cursor-pointer" %>
<% end %>
```

Create `app/views/categorias/index.html.erb`:

```erb
<% content_for :title, "Categorias" %>

<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold">Categorias</h1>
  <%= link_to "Nova categoria", new_categoria_path, class: "bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700" %>
</div>

<% if @categorias.empty? %>
  <p class="text-slate-600">Nenhuma categoria cadastrada ainda.</p>
<% else %>
  <div class="flex flex-col gap-4">
    <% @categorias.each do |categoria| %>
      <div class="bg-white border border-slate-200 rounded-lg p-4 flex justify-between items-center">
        <div class="flex items-center gap-3">
          <span class="w-4 h-4 rounded-full shrink-0" style="background-color: <%= categoria.cor %>"></span>
          <div>
            <h2 class="font-semibold"><%= categoria.nome %></h2>
            <p class="text-slate-600 text-sm"><%= categoria.hora_inicio.strftime("%H:%M") %>–<%= categoria.hora_fim.strftime("%H:%M") %></p>
          </div>
        </div>
        <div class="flex gap-3 shrink-0">
          <%= link_to "Editar", edit_categoria_path(categoria), class: "text-indigo-600 text-sm hover:underline" %>
          <%= button_to "Remover", categoria_path(categoria), method: :delete, class: "text-red-600 text-sm hover:underline", form: { data: { turbo_confirm: "Remover esta categoria?" } } %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>

<%= link_to "Voltar ao calendário", calendario_path, class: "text-sm text-indigo-600 hover:underline mt-4 inline-block" %>
```

Create `app/views/categorias/new.html.erb`:

```erb
<% content_for :title, "Nova Categoria" %>

<h1 class="text-2xl font-semibold mb-4">Nova Categoria</h1>

<%= render "form", categoria: @categoria %>

<%= link_to "Voltar", categorias_path, class: "text-sm text-indigo-600 hover:underline" %>
```

Create `app/views/categorias/edit.html.erb`:

```erb
<% content_for :title, "Editar Categoria" %>

<h1 class="text-2xl font-semibold mb-4">Editar Categoria</h1>

<%= render "form", categoria: @categoria %>

<%= link_to "Voltar", categorias_path, class: "text-sm text-indigo-600 hover:underline" %>
```

Note: `index.html.erb` links to `calendario_path`, which doesn't exist until Task 6 — this is expected to be a broken link until then; it doesn't affect this task's tests (none visit that link).

- [ ] **Step 6: Run and confirm pass**

Run: `bin/rails test test/controllers/categorias_controller_test.rb`
Expected: PASS (8 tests).

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/categorias_controller.rb app/views/categorias test/controllers/categorias_controller_test.rb
git commit -m "Add Categorias CRUD"
```

---

### Task 5: Rename everything to English (Plantao→Shift, Categoria→Category)

**Why this task exists:** After Tasks 1-4 were implemented (and merged into this branch) under Portuguese naming, the naming convention was changed: every code identifier — models, controllers, files, routes, database columns — must be in English; only user-facing view text (headings, labels, button text, flash notices, validation messages) and realistic sample data values stay in Portuguese. This task performs that rename across both the pre-existing `Plantao`/`plantoes` code (from the earlier Fase 1 work, predating this plan) and this plan's own Tasks 2-4 (`Categoria`/`categorias`). It also removes the unrequested `get "calendario" => "pages#calendar"` placeholder route that Task 4's implementer added (flagged Important by that task's review — folded into this rewrite of `routes.rb` rather than a separate one-line fix).

**Files:**
- Create: `db/migrate/[timestamp]_rename_to_english.rb`
- Rename + rewrite: `app/models/plantao.rb` → `app/models/shift.rb`
- Rename + rewrite: `app/models/categoria.rb` → `app/models/category.rb`
- Rename + rewrite: `app/controllers/plantoes_controller.rb` → `app/controllers/shifts_controller.rb`
- Rename + rewrite: `app/controllers/categorias_controller.rb` → `app/controllers/categories_controller.rb`
- Rename + rewrite: `app/views/plantoes/_form.html.erb`, `index.html.erb`, `new.html.erb`, `edit.html.erb` → `app/views/shifts/` (same filenames)
- Rename + rewrite: `app/views/categorias/_form.html.erb`, `index.html.erb`, `new.html.erb`, `edit.html.erb` → `app/views/categories/` (same filenames)
- Modify: `config/routes.rb`
- Modify: `config/initializers/inflections.rb`
- Rename + rewrite: `test/models/plantao_test.rb` → `test/models/shift_test.rb`
- Rename + rewrite: `test/models/categoria_test.rb` → `test/models/category_test.rb`
- Rename + rewrite: `test/controllers/plantoes_controller_test.rb` → `test/controllers/shifts_controller_test.rb`
- Rename + rewrite: `test/controllers/categorias_controller_test.rb` → `test/controllers/categories_controller_test.rb`
- Rename + rewrite: `test/fixtures/plantoes.yml` → `test/fixtures/shifts.yml`
- Rename + rewrite: `test/fixtures/categorias.yml` → `test/fixtures/categories.yml`

**Interfaces:**
- Produces (replacing everything Tasks 1-4 produced under Portuguese names): `Shift` (table `shifts`, columns `date`, `start_time`, `end_time`, `location`, `notes`, `category_id`), `Category` (table `categories`, columns `name`, `color`, `start_time`, `end_time`), `ShiftsController`, `CategoriesController`, route helpers `shifts_path`/`shift_path`/`new_shift_path`/`edit_shift_path`, `categories_path`/`category_path`/`new_category_path`/`edit_category_path`, `shifts(:one)`/`shifts(:two)` and `categories(:hospital_x)`/`categories(:posto_sul)` fixtures. Tasks 6-8 are written against these names.

**A note on what does NOT get renamed:** Only Ruby/Rails *identifiers* change. Every quoted string that is displayed to the user — page titles (`content_for :title, "Meus Plantões"`), headings (`"Meus Plantões"`, `"Categorias"`), labels (`"Local (opcional)"`), button/link text (`"Novo plantão"`, `"Editar"`, `"Remover"`), flash notices (`"Plantão criado."`), `turbo_confirm` text, and the validation error message string (`"deve ser depois do horário de início"`) — stays exactly as it is, verbatim, in Portuguese. Sample data values in fixtures (`name: Hospital X`, `location: Hospital Central`) also stay as-is — they're realistic Portuguese-language content, not code. The only fixture-file change beyond column renaming is the fixture *label* keys in `shifts.yml`: `um`/`dois` (Portuguese for "one"/"two", pure sequence labels with no data meaning) become `one`/`two`; `categorias.yml`'s `hospital_x`/`posto_sul` keys stay as-is (already Latin-alphabet identifiers standing in for real category names, not grammatical Portuguese).

- [ ] **Step 1: Create and run the migration**

Run: `bin/rails generate migration RenameToEnglish`

Replace the generated file's contents with:

```ruby
class RenameToEnglish < ActiveRecord::Migration[8.1]
  def change
    rename_table :plantoes, :shifts
    rename_table :categorias, :categories

    rename_column :shifts, :data, :date
    rename_column :shifts, :hora_inicio, :start_time
    rename_column :shifts, :hora_fim, :end_time
    rename_column :shifts, :local, :location
    rename_column :shifts, :observacao, :notes
    rename_column :shifts, :categoria_id, :category_id

    rename_column :categories, :nome, :name
    rename_column :categories, :cor, :color
    rename_column :categories, :hora_inicio, :start_time
    rename_column :categories, :hora_fim, :end_time
  end
end
```

Run: `bin/rails db:migrate`
Expected: succeeds; `db/schema.rb` now shows `shifts` and `categories` tables with the new English column names (and `shifts.category_id` still a foreign key referencing `categories`).

- [ ] **Step 2: Rename and rewrite the models**

Run: `git mv app/models/plantao.rb app/models/shift.rb`

Replace `app/models/shift.rb`'s contents with:

```ruby
class Shift < ApplicationRecord
  belongs_to :category, optional: true

  before_validation :apply_category_schedule

  validates :date, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  private

  def apply_category_schedule
    return unless category

    self.start_time ||= category.start_time
    self.end_time ||= category.end_time
  end

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "deve ser depois do horário de início") if end_time <= start_time
  end
end
```

Run: `git mv app/models/categoria.rb app/models/category.rb`

Replace `app/models/category.rb`'s contents with:

```ruby
class Category < ApplicationRecord
  has_many :shifts, dependent: :nullify

  validates :name, presence: true
  validates :color, presence: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time

  private

  def end_time_after_start_time
    return if start_time.blank? || end_time.blank?

    errors.add(:end_time, "deve ser depois do horário de início") if end_time <= start_time
  end
end
```

- [ ] **Step 3: Rename and rewrite the controllers**

Run: `git mv app/controllers/plantoes_controller.rb app/controllers/shifts_controller.rb`

Replace `app/controllers/shifts_controller.rb`'s contents with:

```ruby
class ShiftsController < ApplicationController
  before_action :set_shift, only: [:edit, :update, :destroy]

  def index
    @shifts = Shift.order(:date, :start_time)
  end

  def new
    @shift = Shift.new
  end

  def create
    @shift = Shift.new(shift_params)

    if @shift.save
      redirect_to root_path, notice: "Plantão criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shift.update(shift_params)
      redirect_to root_path, notice: "Plantão atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shift.destroy
    redirect_to root_path, notice: "Plantão removido."
  end

  private

  def set_shift
    @shift = Shift.find(params[:id])
  end

  def shift_params
    params.require(:shift).permit(:date, :start_time, :end_time, :location, :notes)
  end
end
```

Run: `git mv app/controllers/categorias_controller.rb app/controllers/categories_controller.rb`

Replace `app/controllers/categories_controller.rb`'s contents with:

```ruby
class CategoriesController < ApplicationController
  before_action :set_category, only: [:edit, :update, :destroy]

  def index
    @categories = Category.order(:name)
  end

  def new
    @category = Category.new
  end

  def create
    @category = Category.new(category_params)

    if @category.save
      redirect_to categories_path, notice: "Categoria criada."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to categories_path, notice: "Categoria atualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.destroy
    redirect_to categories_path, notice: "Categoria removida."
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :color, :start_time, :end_time)
  end
end
```

- [ ] **Step 4: Rename and rewrite the shifts views**

Run:
```bash
git mv app/views/plantoes app/views/shifts
```

Replace `app/views/shifts/_form.html.erb`'s contents with:

```erb
<%= form_with model: shift, class: "bg-white border border-slate-200 rounded-lg p-4 mb-8 flex flex-col gap-3" do |f| %>
  <% if shift.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% shift.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <%= f.label :date, "Data", class: "text-sm font-medium" %>
  <%= f.date_field :date, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :start_time, "Horário de início", class: "text-sm font-medium" %>
  <%= f.time_field :start_time, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :end_time, "Horário de término", class: "text-sm font-medium" %>
  <%= f.time_field :end_time, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :location, "Local (opcional)", class: "text-sm font-medium" %>
  <%= f.text_field :location, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :notes, "Observação (opcional)", class: "text-sm font-medium" %>
  <%= f.text_area :notes, rows: 3, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.submit "Salvar", class: "self-start bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 cursor-pointer" %>
<% end %>
```

Replace `app/views/shifts/new.html.erb`'s contents with:

```erb
<% content_for :title, "Novo Plantão" %>

<h1 class="text-2xl font-semibold mb-4">Novo Plantão</h1>

<%= render "form", shift: @shift %>

<%= link_to "Voltar", root_path, class: "text-sm text-indigo-600 hover:underline" %>
```

Replace `app/views/shifts/edit.html.erb`'s contents with:

```erb
<% content_for :title, "Editar Plantão" %>

<h1 class="text-2xl font-semibold mb-4">Editar Plantão</h1>

<%= render "form", shift: @shift %>

<%= link_to "Voltar", root_path, class: "text-sm text-indigo-600 hover:underline" %>
```

Replace `app/views/shifts/index.html.erb`'s contents with:

```erb
<% content_for :title, "Meus Plantões" %>

<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold">Meus Plantões</h1>
  <%= link_to "Novo plantão", new_shift_path, class: "bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700" %>
</div>

<% if @shifts.empty? %>
  <p class="text-slate-600">Nenhum plantão cadastrado ainda.</p>
<% else %>
  <div class="flex flex-col gap-4">
    <% @shifts.each do |shift| %>
      <div class="bg-white border border-slate-200 rounded-lg p-4">
        <div class="flex justify-between items-start">
          <div>
            <h2 class="font-semibold">
              <%= l(shift.date, format: :long) %> · <%= shift.start_time.strftime("%H:%M") %>–<%= shift.end_time.strftime("%H:%M") %>
            </h2>
            <% if shift.location.present? %>
              <p class="text-slate-600 mt-1"><%= shift.location %></p>
            <% end %>
            <% if shift.notes.present? %>
              <p class="text-slate-500 text-sm mt-1"><%= shift.notes %></p>
            <% end %>
          </div>
          <div class="flex gap-3 shrink-0">
            <%= link_to "Editar", edit_shift_path(shift), class: "text-indigo-600 text-sm hover:underline" %>
            <%= button_to "Remover", shift_path(shift), method: :delete, class: "text-red-600 text-sm hover:underline", form: { data: { turbo_confirm: "Remover este plantão?" } } %>
          </div>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 5: Rename and rewrite the categories views**

Run:
```bash
git mv app/views/categorias app/views/categories
```

Replace `app/views/categories/_form.html.erb`'s contents with:

```erb
<%= form_with model: category, class: "bg-white border border-slate-200 rounded-lg p-4 mb-8 flex flex-col gap-3" do |f| %>
  <% if category.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% category.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <%= f.label :name, "Nome", class: "text-sm font-medium" %>
  <%= f.text_field :name, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :color, "Cor", class: "text-sm font-medium" %>
  <%= f.color_field :color, class: "border border-slate-300 rounded h-10 w-20" %>

  <%= f.label :start_time, "Horário de início", class: "text-sm font-medium" %>
  <%= f.time_field :start_time, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :end_time, "Horário de término", class: "text-sm font-medium" %>
  <%= f.time_field :end_time, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.submit "Salvar", class: "self-start bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 cursor-pointer" %>
<% end %>
```

Replace `app/views/categories/new.html.erb`'s contents with:

```erb
<% content_for :title, "Nova Categoria" %>

<h1 class="text-2xl font-semibold mb-4">Nova Categoria</h1>

<%= render "form", category: @category %>

<%= link_to "Voltar", categories_path, class: "text-sm text-indigo-600 hover:underline" %>
```

Replace `app/views/categories/edit.html.erb`'s contents with:

```erb
<% content_for :title, "Editar Categoria" %>

<h1 class="text-2xl font-semibold mb-4">Editar Categoria</h1>

<%= render "form", category: @category %>

<%= link_to "Voltar", categories_path, class: "text-sm text-indigo-600 hover:underline" %>
```

Replace `app/views/categories/index.html.erb`'s contents with:

```erb
<% content_for :title, "Categorias" %>

<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold">Categorias</h1>
  <%= link_to "Nova categoria", new_category_path, class: "bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700" %>
</div>

<% if @categories.empty? %>
  <p class="text-slate-600">Nenhuma categoria cadastrada ainda.</p>
<% else %>
  <div class="flex flex-col gap-4">
    <% @categories.each do |category| %>
      <div class="bg-white border border-slate-200 rounded-lg p-4 flex justify-between items-center">
        <div class="flex items-center gap-3">
          <span class="w-4 h-4 rounded-full shrink-0" style="background-color: <%= category.color %>"></span>
          <div>
            <h2 class="font-semibold"><%= category.name %></h2>
            <p class="text-slate-600 text-sm"><%= category.start_time.strftime("%H:%M") %>–<%= category.end_time.strftime("%H:%M") %></p>
          </div>
        </div>
        <div class="flex gap-3 shrink-0">
          <%= link_to "Editar", edit_category_path(category), class: "text-indigo-600 text-sm hover:underline" %>
          <%= button_to "Remover", category_path(category), method: :delete, class: "text-red-600 text-sm hover:underline", form: { data: { turbo_confirm: "Remover esta categoria?" } } %>
        </div>
      </div>
    <% end %>
  </div>
<% end %>

<%= link_to "Voltar ao calendário", calendar_path, class: "text-sm text-indigo-600 hover:underline mt-4 inline-block" %>
```

Note: this still links to `calendar_path`, which doesn't exist until Task 7 — same dangling-link situation Task 4 had with `calendario_path`, just under the new name. Do NOT add a placeholder route for it (that's exactly the mistake this task is cleaning up) — leave it dangling, Task 7 resolves it.

- [ ] **Step 6: Rewrite routes.rb**

Replace `config/routes.rb`'s entire contents with:

```ruby
Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  get "profile" => "pages#profile"
  get "settings" => "pages#settings"

  resources :categories, except: [:show]
  resources :shifts, except: [:show]

  # Defines the root path route ("/")
  root "shifts#index"
end
```

This deliberately drops the `get "calendario" => "pages#calendar"` line Task 4 added — it pointed at a nonexistent controller action and is not needed (Task 7 adds the real `calendar` route).

- [ ] **Step 7: Clean up the now-dead inflection rules**

The custom Portuguese pluralization rules in `config/initializers/inflections.rb` (`"plantao"`/`"plantoes"` and `"categoria"`/`"categorias"`) are no longer used by any model — `"shift"`/`"shifts"` and `"category"`/`"categories"` both pluralize correctly under Rails' default English rules, no custom rule needed. Replace `config/initializers/inflections.rb`'s contents with:

```ruby
# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, "\\1en"
#   inflect.singular /^(ox)en/i, "\\1"
#   inflect.irregular "person", "people"
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym "RESTful"
# end
```

- [ ] **Step 8: Rename and rewrite the model tests**

Run: `git mv test/models/plantao_test.rb test/models/shift_test.rb`

Replace `test/models/shift_test.rb`'s contents with:

```ruby
require "test_helper"

class ShiftTest < ActiveSupport::TestCase
  test "valid with date, start_time, end_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00")
    assert shift.valid?
  end

  test "invalid without date" do
    shift = Shift.new(date: nil, start_time: "08:00", end_time: "14:00")
    assert_not shift.valid?
  end

  test "invalid without start_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: nil, end_time: "14:00")
    assert_not shift.valid?
  end

  test "invalid without end_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: nil)
    assert_not shift.valid?
  end

  test "invalid when end_time is before start_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "14:00", end_time: "08:00")
    assert_not shift.valid?
    assert_includes shift.errors[:end_time], "deve ser depois do horário de início"
  end

  test "invalid when end_time equals start_time" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "08:00")
    assert_not shift.valid?
  end

  test "valid without location or notes" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00", location: nil, notes: nil)
    assert shift.valid?
  end

  test "valid with category and no explicit start_time/end_time" do
    category = categories(:hospital_x)
    shift = Shift.new(date: Date.new(2026, 9, 10), category: category)

    assert shift.valid?
    assert_equal category.start_time, shift.start_time
    assert_equal category.end_time, shift.end_time
  end

  test "keeps explicit start_time/end_time even with category set" do
    category = categories(:hospital_x)
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "09:00", end_time: "10:00", category: category)

    assert shift.valid?
    assert_equal "09:00", shift.start_time.strftime("%H:%M")
    assert_equal "10:00", shift.end_time.strftime("%H:%M")
  end

  test "valid without category" do
    shift = Shift.new(date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00")
    assert shift.valid?
    assert_nil shift.category
  end

  test "destroying category nullifies associated shift" do
    category = categories(:hospital_x)
    shift = Shift.create!(date: Date.new(2026, 9, 10), category: category)

    category.destroy

    assert_nil shift.reload.category_id
  end
end
```

Run: `git mv test/models/categoria_test.rb test/models/category_test.rb`

Replace `test/models/category_test.rb`'s contents with:

```ruby
require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "valid with name, color, start_time, end_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: "19:00")
    assert category.valid?
  end

  test "invalid without name" do
    category = Category.new(name: nil, color: "#4f46e5", start_time: "07:00", end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without color" do
    category = Category.new(name: "Hospital X", color: nil, start_time: "07:00", end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without start_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: nil, end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without end_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: nil)
    assert_not category.valid?
  end

  test "invalid when end_time is before start_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: "19:00", end_time: "07:00")
    assert_not category.valid?
    assert_includes category.errors[:end_time], "deve ser depois do horário de início"
  end

  test "invalid when end_time equals start_time" do
    category = Category.new(name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: "07:00")
    assert_not category.valid?
  end
end
```

- [ ] **Step 9: Rename and rewrite the controller tests**

Run: `git mv test/controllers/plantoes_controller_test.rb test/controllers/shifts_controller_test.rb`

Replace `test/controllers/shifts_controller_test.rb`'s contents with:

```ruby
require "test_helper"

class ShiftsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @shift = shifts(:one)
  end

  test "should get index" do
    get root_url
    assert_response :success
  end

  test "should get new" do
    get new_shift_url
    assert_response :success
  end

  test "should create shift" do
    assert_difference("Shift.count") do
      post shifts_url, params: { shift: { date: "2026-09-15", start_time: "09:00", end_time: "17:00", location: "Posto Sul" } }
    end

    assert_redirected_to root_url
  end

  test "should not create shift with invalid times" do
    assert_no_difference("Shift.count") do
      post shifts_url, params: { shift: { date: "2026-09-15", start_time: "17:00", end_time: "09:00" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_shift_url(@shift)
    assert_response :success
  end

  test "should update shift" do
    patch shift_url(@shift), params: { shift: { location: "Novo Local" } }
    assert_redirected_to root_url
    assert_equal "Novo Local", @shift.reload.location
  end

  test "should not update shift with invalid times" do
    patch shift_url(@shift), params: { shift: { start_time: "17:00", end_time: "09:00" } }
    assert_response :unprocessable_entity
  end

  test "should destroy shift" do
    assert_difference("Shift.count", -1) do
      delete shift_url(@shift)
    end

    assert_redirected_to root_url
  end
end
```

Run: `git mv test/controllers/categorias_controller_test.rb test/controllers/categories_controller_test.rb`

Replace `test/controllers/categories_controller_test.rb`'s contents with:

```ruby
require "test_helper"

class CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @category = categories(:hospital_x)
  end

  test "should get index" do
    get categories_url
    assert_response :success
  end

  test "should get new" do
    get new_category_url
    assert_response :success
  end

  test "should create category" do
    assert_difference("Category.count") do
      post categories_url, params: { category: { name: "Hospital Y", color: "#f97316", start_time: "08:00", end_time: "20:00" } }
    end

    assert_redirected_to categories_url
  end

  test "should not create category with invalid times" do
    assert_no_difference("Category.count") do
      post categories_url, params: { category: { name: "Hospital Y", color: "#f97316", start_time: "20:00", end_time: "08:00" } }
    end

    assert_response :unprocessable_entity
  end

  test "should get edit" do
    get edit_category_url(@category)
    assert_response :success
  end

  test "should update category" do
    patch category_url(@category), params: { category: { name: "Hospital X Renovado" } }
    assert_redirected_to categories_url
    assert_equal "Hospital X Renovado", @category.reload.name
  end

  test "should destroy category" do
    assert_difference("Category.count", -1) do
      delete category_url(@category)
    end

    assert_redirected_to categories_url
  end

  test "destroying category nullifies associated shifts instead of blocking" do
    shift = Shift.create!(date: Date.new(2026, 9, 10), category: @category)

    delete category_url(@category)

    assert_nil shift.reload.category_id
  end
end
```

- [ ] **Step 10: Rename and rewrite the fixtures**

Run: `git mv test/fixtures/plantoes.yml test/fixtures/shifts.yml`

Replace `test/fixtures/shifts.yml`'s contents with:

```yaml
one:
  date: 2026-09-10
  start_time: "08:00"
  end_time: "14:00"
  location: Hospital Central
  notes: Plantão de rotina

two:
  date: 2026-09-12
  start_time: "20:00"
  end_time: "23:30"
```

Run: `git mv test/fixtures/categorias.yml test/fixtures/categories.yml`

Replace `test/fixtures/categories.yml`'s contents with:

```yaml
hospital_x:
  name: Hospital X
  color: "#4f46e5"
  start_time: "07:00"
  end_time: "19:00"

posto_sul:
  name: Posto Sul
  color: "#16a34a"
  start_time: "13:00"
  end_time: "19:00"
```

- [ ] **Step 11: Run the full suite**

Run: `bin/rails test`
Expected: all PASS (same total test count as before this task — 11 shift model tests + 7 category model tests + 8 shifts controller tests + 8 categories controller tests + 2 pages controller tests = 36).

- [ ] **Step 12: Verify no leftover Portuguese identifiers**

Run: `grep -rn "Plantao\|plantao_id\|categoria_id\|Categoria\b" app/ config/routes.rb test/ --include="*.rb" --include="*.yml"`
Expected: no output (the word "Categoria"/"categorias" may still legitimately appear as quoted Portuguese UI text inside `.erb` files — e.g. `content_for :title, "Categorias"` — grep only `.rb`/`.yml`/routes here specifically to catch leftover *code* identifiers, not view text). If anything prints, fix it before committing.

- [ ] **Step 13: Commit**

```bash
git add -A
git commit -m "Rename Plantao/Categoria to Shift/Category (English identifiers, Portuguese UI text unchanged)"
```

---

### Task 6: Shifts list flow — optional category, return_to

**Files:**
- Modify: `app/controllers/shifts_controller.rb`
- Modify: `app/views/shifts/_form.html.erb`
- Modify: `app/views/shifts/index.html.erb`
- Test: `test/controllers/shifts_controller_test.rb`

**Interfaces:**
- Consumes: `Category` (Task 2/3/5), `categories_path` unused here (uses `Category.order(:name)` directly for the select).
- Produces: `shifts#create`/`#destroy` honor a top-level `return_to` param (redirect there if it starts with `/`, else `root_path`) — this is what Task 8's day-modal form and remove button will rely on.

- [ ] **Step 1: Write the failing tests**

Append to `test/controllers/shifts_controller_test.rb` (inside the class, before the final `end`):

```ruby
  test "should create shift with category filling times automatically" do
    category = categories(:hospital_x)

    assert_difference("Shift.count") do
      post shifts_url, params: { shift: { date: "2026-09-20", category_id: category.id } }
    end

    shift = Shift.last
    assert_equal category.start_time, shift.start_time
    assert_equal category.end_time, shift.end_time
  end

  test "should redirect to return_to when it is a relative path" do
    post shifts_url, params: { shift: { date: "2026-09-21", start_time: "08:00", end_time: "12:00" }, return_to: "/calendar" }
    assert_redirected_to "/calendar"
  end

  test "should ignore return_to when it is not a relative path" do
    post shifts_url, params: { shift: { date: "2026-09-22", start_time: "08:00", end_time: "12:00" }, return_to: "https://evil.example.com" }
    assert_redirected_to root_url
  end

  test "should destroy shift and redirect to return_to" do
    assert_difference("Shift.count", -1) do
      delete shift_url(@shift), params: { return_to: "/calendar" }
    end
    assert_redirected_to "/calendar"
  end
```

- [ ] **Step 2: Run and confirm failure**

Run: `bin/rails test test/controllers/shifts_controller_test.rb`
Expected: FAIL — the category test fails because `category_id` isn't permitted yet (times stay blank, save fails, count doesn't change); the `return_to` tests fail because responses redirect to `root_url` regardless.

- [ ] **Step 3: Update the controller**

Replace `app/controllers/shifts_controller.rb` with:

```ruby
class ShiftsController < ApplicationController
  before_action :set_shift, only: [:edit, :update, :destroy]

  def index
    @shifts = Shift.order(:date, :start_time)
  end

  def new
    @shift = Shift.new
  end

  def create
    @shift = Shift.new(shift_params)

    if @shift.save
      redirect_to destination_after_save, notice: "Plantão criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shift.update(shift_params)
      redirect_to root_path, notice: "Plantão atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shift.destroy
    redirect_to destination_after_save, notice: "Plantão removido."
  end

  private

  def set_shift
    @shift = Shift.find(params[:id])
  end

  def shift_params
    params.require(:shift).permit(:date, :start_time, :end_time, :location, :notes, :category_id)
  end

  def destination_after_save
    return_to = params[:return_to]
    return_to.present? && return_to.start_with?("/") ? return_to : root_path
  end
end
```

- [ ] **Step 4: Update the form**

In `app/views/shifts/_form.html.erb`, find:

```erb
  <%= f.label :location, "Local (opcional)", class: "text-sm font-medium" %>
```

Replace with:

```erb
  <%= f.label :category_id, "Categoria (opcional)", class: "text-sm font-medium" %>
  <%= f.collection_select :category_id, Category.order(:name), :id, :name, { include_blank: "Nenhuma" }, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :location, "Local (opcional)", class: "text-sm font-medium" %>
```

- [ ] **Step 5: Update the index view**

In `app/views/shifts/index.html.erb`, replace the header block:

```erb
<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold">Meus Plantões</h1>
  <%= link_to "Novo plantão", new_shift_path, class: "bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700" %>
</div>
```

with:

```erb
<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold">Meus Plantões</h1>
  <div class="flex gap-3 items-center">
    <%= link_to "Ver calendário", calendar_path, class: "text-indigo-600 text-sm hover:underline" %>
    <%= link_to "Novo plantão", new_shift_path, class: "bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700" %>
  </div>
</div>
```

And replace the `location` display block:

```erb
            <% if shift.location.present? %>
              <p class="text-slate-600 mt-1"><%= shift.location %></p>
            <% end %>
```

with:

```erb
            <% if shift.category.present? %>
              <p class="text-slate-600 mt-1 flex items-center gap-2">
                <span class="inline-block w-3 h-3 rounded-full shrink-0" style="background-color: <%= shift.category.color %>"></span>
                <%= shift.category.name %>
              </p>
            <% elsif shift.location.present? %>
              <p class="text-slate-600 mt-1"><%= shift.location %></p>
            <% end %>
```

Note: `index.html.erb` now links to `calendar_path`, which doesn't exist until Task 7. Same as Task 5's note on `categories/index.html.erb` — expected, no test visits that link yet.

- [ ] **Step 6: Run and confirm pass**

Run: `bin/rails test test/controllers/shifts_controller_test.rb`
Expected: PASS (all tests, old and new).

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/shifts_controller.rb app/views/shifts/_form.html.erb app/views/shifts/index.html.erb test/controllers/shifts_controller_test.rb
git commit -m "Add optional category and return_to support to Shifts flow"
```

---

### Task 7: Calendar month grid

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/calendar_controller.rb`
- Create: `app/views/calendar/show.html.erb`
- Test: `test/controllers/calendar_controller_test.rb`

**Interfaces:**
- Consumes: `Shift`/`Category` (Tasks 2/3/5), `categories_path` (Task 5, for the "Gerenciar categorias" link).
- Produces: `calendar_path` (this is what Task 5/6's dangling links resolve to), `@month` (a `Date`, first day of the displayed month), `@weeks` (array of 7-day `Date` arrays), `@colors_by_day` (`Hash` of `Date => Array<String>` hex colors) — all `CalendarController` instance variables other tasks don't touch.

- [ ] **Step 1: Write the failing controller test**

Create `test/controllers/calendar_controller_test.rb`:

```ruby
require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  test "should get calendar for current month" do
    get calendar_url
    assert_response :success
  end

  test "should get calendar for a given month" do
    get calendar_url(month: "2026-12")
    assert_response :success
  end

  test "should show a colored dot for a day with a category shift" do
    category = categories(:hospital_x)
    Shift.create!(date: Date.new(2026, 9, 20), category: category)

    get calendar_url(month: "2026-09")

    assert_response :success
    assert_match category.color, response.body
  end
end
```

- [ ] **Step 2: Run and confirm it fails**

Run: `bin/rails test test/controllers/calendar_controller_test.rb`
Expected: FAIL with a routing error (`calendar_url` undefined).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, add above `root "shifts#index"`:

```ruby
  get "calendar", to: "calendar#show", as: :calendar
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/calendar_controller.rb`:

```ruby
class CalendarController < ApplicationController
  def show
    @month = month_param
    @weeks = weeks_of_month(@month)
    @colors_by_day = colors_by_day(@month)
  end

  private

  def month_param
    Date.strptime(params[:month], "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end

  def weeks_of_month(month)
    first = month.beginning_of_month.beginning_of_week(:sunday)
    last = month.end_of_month.end_of_week(:sunday)
    (first..last).to_a.each_slice(7).to_a
  end

  def colors_by_day(month)
    Shift.where(date: month.beginning_of_month..month.end_of_month)
         .includes(:category)
         .group_by(&:date)
         .transform_values { |shifts| shifts.map { |s| s.category&.color || "#94a3b8" }.uniq }
  end
end
```

- [ ] **Step 5: Create the view**

Create `app/views/calendar/show.html.erb`:

```erb
<% content_for :title, "Calendário" %>

<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold"><%= @month.strftime("%B %Y") %></h1>
  <%= link_to "Gerenciar categorias", categories_path, class: "text-sm text-indigo-600 hover:underline" %>
</div>

<div class="flex justify-between items-center mb-4">
  <%= link_to "‹ Mês anterior", calendar_path(month: (@month - 1.month).strftime("%Y-%m")), class: "text-indigo-600 hover:underline text-sm" %>
  <%= link_to "Próximo mês ›", calendar_path(month: (@month + 1.month).strftime("%Y-%m")), class: "text-indigo-600 hover:underline text-sm" %>
</div>

<div class="grid grid-cols-7 gap-2 text-center text-sm font-medium text-slate-500 mb-2">
  <% %w[Dom Seg Ter Qua Qui Sex Sáb].each do |day_name| %>
    <div><%= day_name %></div>
  <% end %>
</div>

<div class="flex flex-col gap-2">
  <% @weeks.each do |week| %>
    <div class="grid grid-cols-7 gap-2">
      <% week.each do |day| %>
        <%= link_to calendar_day_path(date: day.strftime("%Y-%m-%d")), data: { turbo_frame: "day_modal" }, class: "border border-slate-200 rounded-lg p-2 h-16 flex flex-col items-center hover:bg-slate-50 #{"text-slate-300" unless day.month == @month.month}" do %>
          <span class="text-sm"><%= day.day %></span>
          <div class="flex gap-1 mt-1">
            <% (@colors_by_day[day] || []).each do |color| %>
              <span class="w-2 h-2 rounded-full" style="background-color: <%= color %>"></span>
            <% end %>
          </div>
        <% end %>
      <% end %>
    </div>
  <% end %>
</div>

<%= turbo_frame_tag "day_modal" %>

<%= link_to "Ver lista", root_path, class: "text-sm text-indigo-600 hover:underline mt-4 inline-block" %>
```

Note: this view links to `calendar_day_path`, which doesn't exist until Task 8 — expected, no test in this task clicks that link.

- [ ] **Step 6: Run and confirm pass**

Run: `bin/rails test test/controllers/calendar_controller_test.rb`
Expected: PASS (3 tests).

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all PASS — this also confirms Task 5's `categories/index.html.erb` and Task 6's `shifts/index.html.erb` links to `calendar_path` now resolve.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/calendar_controller.rb app/views/calendar/show.html.erb test/controllers/calendar_controller_test.rb
git commit -m "Add calendar month grid view"
```

---

### Task 8: Calendar day modal (Turbo Frame)

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/calendar_controller.rb`
- Create: `app/views/calendar/day.html.erb`
- Test: `test/controllers/calendar_controller_test.rb`

**Interfaces:**
- Consumes: `calendar_path` (Task 7), `shifts_path` and `return_to`/`category_id` handling (Task 6), `Category`/`Shift` (Tasks 2/3/5).
- Produces: `calendar_day_path(date: "YYYY-MM-DD")` — this is what Task 7's day links and this task's own "Fechar"/remove links/redirects target.

- [ ] **Step 1: Write the failing controller tests**

Append to `test/controllers/calendar_controller_test.rb` (inside the class, before the final `end`):

```ruby
  test "should get day with existing shifts" do
    category = categories(:hospital_x)
    Shift.create!(date: Date.new(2026, 9, 20), category: category)

    get calendar_day_url(date: "2026-09-20")

    assert_response :success
    assert_match category.name, response.body
  end

  test "should get day without shifts" do
    get calendar_day_url(date: "2026-09-25")

    assert_response :success
    assert_match "Nenhum plantão", response.body
  end
```

- [ ] **Step 2: Run and confirm failure**

Run: `bin/rails test test/controllers/calendar_controller_test.rb`
Expected: FAIL with a routing error (`calendar_day_url` undefined).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, add right after the `calendar` route:

```ruby
  get "calendar/:date", to: "calendar#day", as: :calendar_day, constraints: { date: /\d{4}-\d{2}-\d{2}/ }
```

- [ ] **Step 4: Add the controller action**

In `app/controllers/calendar_controller.rb`, find:

```ruby
  def show
    @month = month_param
    @weeks = weeks_of_month(@month)
    @colors_by_day = colors_by_day(@month)
  end

  private
```

Replace with:

```ruby
  def show
    @month = month_param
    @weeks = weeks_of_month(@month)
    @colors_by_day = colors_by_day(@month)
  end

  def day
    @date = Date.parse(params[:date])
    @shifts = Shift.where(date: @date).includes(:category).order(:start_time)
    @categories = Category.order(:name)
  end

  private
```

- [ ] **Step 5: Create the view**

Create `app/views/calendar/day.html.erb`:

```erb
<%= turbo_frame_tag "day_modal" do %>
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg p-4 w-full max-w-sm flex flex-col gap-3">
      <div class="flex justify-between items-center">
        <h2 class="font-semibold"><%= @date.strftime("%d/%m/%Y") %></h2>
        <%= link_to "Fechar", calendar_path(month: @date.strftime("%Y-%m")), class: "text-sm text-slate-500 hover:underline" %>
      </div>

      <% if @shifts.any? %>
        <div class="flex flex-col gap-2">
          <% @shifts.each do |shift| %>
            <div class="flex justify-between items-center border border-slate-200 rounded px-3 py-2">
              <div class="flex items-center gap-2">
                <span class="w-3 h-3 rounded-full shrink-0" style="background-color: <%= shift.category&.color || "#94a3b8" %>"></span>
                <span class="text-sm">
                  <%= shift.category&.name || shift.location || "Sem categoria" %>
                  · <%= shift.start_time.strftime("%H:%M") %>–<%= shift.end_time.strftime("%H:%M") %>
                </span>
              </div>
              <%= button_to "Remover", shift_path(shift), method: :delete, params: { return_to: calendar_day_path(date: @date.strftime("%Y-%m-%d")) }, class: "text-red-600 text-xs hover:underline", form: { data: { turbo_confirm: "Remover este plantão?" } } %>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="text-slate-500 text-sm">Nenhum plantão neste dia.</p>
      <% end %>

      <%= form_with url: shifts_path, method: :post, class: "flex flex-col gap-2 border-t border-slate-200 pt-3" do %>
        <%= hidden_field_tag "shift[date]", @date.strftime("%Y-%m-%d") %>
        <%= hidden_field_tag "return_to", calendar_day_path(date: @date.strftime("%Y-%m-%d")) %>
        <%= label_tag "shift_category_id", "Categoria", class: "text-sm font-medium" %>
        <%= collection_select(:shift, :category_id, @categories, :id, :name, {}, class: "border border-slate-300 rounded px-3 py-2") %>
        <%= submit_tag "Adicionar plantão", class: "self-start bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 cursor-pointer" %>
      <% end %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 6: Run and confirm pass**

Run: `bin/rails test test/controllers/calendar_controller_test.rb`
Expected: PASS (5 tests).

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all PASS.

- [ ] **Step 8: Manual smoke test**

Run: `bin/dev` (or `bin/rails server`), open `/calendar`, click a day, confirm the modal appears in place (no full page reload), pick a category and submit, confirm the day now shows a colored dot and the modal lists the new plantão, click "Remover" and confirm it disappears, click "Fechar" and confirm the modal closes back to the plain grid. Stop the server afterward.

- [ ] **Step 9: Commit**

```bash
git add config/routes.rb app/controllers/calendar_controller.rb app/views/calendar/day.html.erb test/controllers/calendar_controller_test.rb
git commit -m "Add calendar day modal for creating/removing shifts by category"
```
