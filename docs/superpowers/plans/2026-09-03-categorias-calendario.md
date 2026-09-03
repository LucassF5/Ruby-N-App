# Categorias + Calendário de Plantões Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user define reusable shift categories (name, default time range, color) and create/view shifts from a month calendar, where clicking a day opens a modal to pick a category (auto-filling its time range) and the day gets marked with the category's color.

**Architecture:** Two new Rails resources (`Categoria`, and a `CalendarioController` that is view-only over `Plantao`/`Categoria`) layered onto the existing `Plantao` CRUD. The calendar's day modal is a Turbo Frame (`day_modal`) that swaps in place without a full page reload; the app currently ships zero JS (no Turbo/Stimulus/importmap), so Task 1 adds the minimum Turbo setup first.

**Tech Stack:** Rails 8.1, Propshaft, SQLite, Minitest + fixtures, Tailwind (already set up), Turbo (`turbo-rails` + `importmap-rails`, added in Task 1 — no Stimulus, no custom JS).

**Spec:** `docs/superpowers/specs/2026-09-03-categorias-calendario-design.md`

## Global Constraints

- Single-user app, no auth, no `user_id` scoping anywhere.
- 100% local SQLite — no remote backend, no sync.
- Minitest + fixtures convention (`fixtures :all` in `test/test_helper.rb`) — every new table needs a `test/fixtures/<table>.yml`.
- Tailwind utility classes matching existing `plantoes` views' style (white cards, `border-slate-200`, `indigo-600` accents, `rounded-lg`/`rounded` mix as already used).
- No `show` action for either `Categoria` or `Plantao` — list + edit form cover the CRUD loop (`resources ..., except: [:show]`).
- Week grid starts on Sunday.
- `return_to` param (on `plantoes#create`/`#destroy`) is only honored when it starts with `/`; otherwise fall back to `root_path` (open-redirect guard).
- Deleting a `Categoria` in use must nullify (`dependent: :nullify`), never block or cascade-delete `Plantao` rows.
- No Stimulus, no custom JS controllers — Turbo Frames alone are sufficient for this feature.

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

### Task 5: Plantoes list flow — optional categoria, return_to

**Files:**
- Modify: `app/controllers/plantoes_controller.rb`
- Modify: `app/views/plantoes/_form.html.erb`
- Modify: `app/views/plantoes/index.html.erb`
- Test: `test/controllers/plantoes_controller_test.rb`

**Interfaces:**
- Consumes: `Categoria` (Task 2/3), `categorias_path` unused here (uses `Categoria.order(:nome)` directly for the select).
- Produces: `plantoes#create`/`#destroy` honor a top-level `return_to` param (redirect there if it starts with `/`, else `root_path`) — this is what Task 7's day-modal form and remove button will rely on.

- [ ] **Step 1: Write the failing tests**

Append to `test/controllers/plantoes_controller_test.rb` (inside the class, before the final `end`):

```ruby
  test "should create plantao with categoria filling times automatically" do
    categoria = categorias(:hospital_x)

    assert_difference("Plantao.count") do
      post plantoes_url, params: { plantao: { data: "2026-09-20", categoria_id: categoria.id } }
    end

    plantao = Plantao.last
    assert_equal categoria.hora_inicio, plantao.hora_inicio
    assert_equal categoria.hora_fim, plantao.hora_fim
  end

  test "should redirect to return_to when it is a relative path" do
    post plantoes_url, params: { plantao: { data: "2026-09-21", hora_inicio: "08:00", hora_fim: "12:00" }, return_to: "/calendario" }
    assert_redirected_to "/calendario"
  end

  test "should ignore return_to when it is not a relative path" do
    post plantoes_url, params: { plantao: { data: "2026-09-22", hora_inicio: "08:00", hora_fim: "12:00" }, return_to: "https://evil.example.com" }
    assert_redirected_to root_url
  end

  test "should destroy plantao and redirect to return_to" do
    assert_difference("Plantao.count", -1) do
      delete plantao_url(@plantao), params: { return_to: "/calendario" }
    end
    assert_redirected_to "/calendario"
  end
```

- [ ] **Step 2: Run and confirm failure**

Run: `bin/rails test test/controllers/plantoes_controller_test.rb`
Expected: FAIL — the categoria test fails because `categoria_id` isn't permitted yet (times stay blank, save fails, count doesn't change); the `return_to` tests fail because responses redirect to `root_url` regardless.

- [ ] **Step 3: Update the controller**

Replace `app/controllers/plantoes_controller.rb` with:

```ruby
class PlantoesController < ApplicationController
  before_action :set_plantao, only: [:edit, :update, :destroy]

  def index
    @plantoes = Plantao.order(:data, :hora_inicio)
  end

  def new
    @plantao = Plantao.new
  end

  def create
    @plantao = Plantao.new(plantao_params)

    if @plantao.save
      redirect_to destino_apos_salvar, notice: "Plantão criado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @plantao.update(plantao_params)
      redirect_to root_path, notice: "Plantão atualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @plantao.destroy
    redirect_to destino_apos_salvar, notice: "Plantão removido."
  end

  private

  def set_plantao
    @plantao = Plantao.find(params[:id])
  end

  def plantao_params
    params.require(:plantao).permit(:data, :hora_inicio, :hora_fim, :local, :observacao, :categoria_id)
  end

  def destino_apos_salvar
    return_to = params[:return_to]
    return_to.present? && return_to.start_with?("/") ? return_to : root_path
  end
end
```

- [ ] **Step 4: Update the form**

In `app/views/plantoes/_form.html.erb`, find:

```erb
  <%= f.label :local, "Local (opcional)", class: "text-sm font-medium" %>
```

Replace with:

```erb
  <%= f.label :categoria_id, "Categoria (opcional)", class: "text-sm font-medium" %>
  <%= f.collection_select :categoria_id, Categoria.order(:nome), :id, :nome, { include_blank: "Nenhuma" }, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :local, "Local (opcional)", class: "text-sm font-medium" %>
```

- [ ] **Step 5: Update the index view**

In `app/views/plantoes/index.html.erb`, replace the header block:

```erb
<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold">Meus Plantões</h1>
  <%= link_to "Novo plantão", new_plantao_path, class: "bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700" %>
</div>
```

with:

```erb
<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold">Meus Plantões</h1>
  <div class="flex gap-3 items-center">
    <%= link_to "Ver calendário", calendario_path, class: "text-indigo-600 text-sm hover:underline" %>
    <%= link_to "Novo plantão", new_plantao_path, class: "bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700" %>
  </div>
</div>
```

And replace the `local` display block:

```erb
            <% if plantao.local.present? %>
              <p class="text-slate-600 mt-1"><%= plantao.local %></p>
            <% end %>
```

with:

```erb
            <% if plantao.categoria.present? %>
              <p class="text-slate-600 mt-1 flex items-center gap-2">
                <span class="inline-block w-3 h-3 rounded-full shrink-0" style="background-color: <%= plantao.categoria.cor %>"></span>
                <%= plantao.categoria.nome %>
              </p>
            <% elsif plantao.local.present? %>
              <p class="text-slate-600 mt-1"><%= plantao.local %></p>
            <% end %>
```

Note: `index.html.erb` now links to `calendario_path`, which doesn't exist until Task 6. Same as Task 4's note — expected, no test visits that link yet.

- [ ] **Step 6: Run and confirm pass**

Run: `bin/rails test test/controllers/plantoes_controller_test.rb`
Expected: PASS (all tests, old and new).

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all PASS.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/plantoes_controller.rb app/views/plantoes/_form.html.erb app/views/plantoes/index.html.erb test/controllers/plantoes_controller_test.rb
git commit -m "Add optional categoria and return_to support to Plantoes flow"
```

---

### Task 6: Calendário month grid

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/calendario_controller.rb`
- Create: `app/views/calendario/show.html.erb`
- Test: `test/controllers/calendario_controller_test.rb`

**Interfaces:**
- Consumes: `Plantao`/`Categoria` (Tasks 2/3), `categorias_path` (Task 4, for the "Gerenciar categorias" link).
- Produces: `calendario_path` (this is what Task 4/5's dangling links resolve to), `@mes` (a `Date`, first day of the displayed month), `@semanas` (array of 7-day `Date` arrays), `@cores_por_dia` (`Hash` of `Date => Array<String>` hex colors) — all `CalendarioController` instance variables other tasks don't touch.

- [ ] **Step 1: Write the failing controller test**

Create `test/controllers/calendario_controller_test.rb`:

```ruby
require "test_helper"

class CalendarioControllerTest < ActionDispatch::IntegrationTest
  test "should get calendario for current month" do
    get calendario_url
    assert_response :success
  end

  test "should get calendario for a given month" do
    get calendario_url(mes: "2026-12")
    assert_response :success
  end

  test "should show a colored dot for a day with a categoria plantao" do
    categoria = categorias(:hospital_x)
    Plantao.create!(data: Date.new(2026, 9, 20), categoria: categoria)

    get calendario_url(mes: "2026-09")

    assert_response :success
    assert_match categoria.cor, response.body
  end
end
```

- [ ] **Step 2: Run and confirm it fails**

Run: `bin/rails test test/controllers/calendario_controller_test.rb`
Expected: FAIL with a routing error (`calendario_url` undefined).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, add above `root "plantoes#index"`:

```ruby
  get "calendario", to: "calendario#show", as: :calendario
```

- [ ] **Step 4: Create the controller**

Create `app/controllers/calendario_controller.rb`:

```ruby
class CalendarioController < ApplicationController
  def show
    @mes = mes_param
    @semanas = semanas_do_mes(@mes)
    @cores_por_dia = cores_por_dia(@mes)
  end

  private

  def mes_param
    Date.strptime(params[:mes], "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end

  def semanas_do_mes(mes)
    inicio = mes.beginning_of_month.beginning_of_week(:sunday)
    fim = mes.end_of_month.end_of_week(:sunday)
    (inicio..fim).to_a.each_slice(7).to_a
  end

  def cores_por_dia(mes)
    Plantao.where(data: mes.beginning_of_month..mes.end_of_month)
           .includes(:categoria)
           .group_by(&:data)
           .transform_values { |plantoes| plantoes.map { |p| p.categoria&.cor || "#94a3b8" }.uniq }
  end
end
```

- [ ] **Step 5: Create the view**

Create `app/views/calendario/show.html.erb`:

```erb
<% content_for :title, "Calendário" %>

<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold"><%= @mes.strftime("%B %Y") %></h1>
  <%= link_to "Gerenciar categorias", categorias_path, class: "text-sm text-indigo-600 hover:underline" %>
</div>

<div class="flex justify-between items-center mb-4">
  <%= link_to "‹ Mês anterior", calendario_path(mes: (@mes - 1.month).strftime("%Y-%m")), class: "text-indigo-600 hover:underline text-sm" %>
  <%= link_to "Próximo mês ›", calendario_path(mes: (@mes + 1.month).strftime("%Y-%m")), class: "text-indigo-600 hover:underline text-sm" %>
</div>

<div class="grid grid-cols-7 gap-2 text-center text-sm font-medium text-slate-500 mb-2">
  <% %w[Dom Seg Ter Qua Qui Sex Sáb].each do |dia| %>
    <div><%= dia %></div>
  <% end %>
</div>

<div class="flex flex-col gap-2">
  <% @semanas.each do |semana| %>
    <div class="grid grid-cols-7 gap-2">
      <% semana.each do |dia| %>
        <%= link_to calendario_dia_path(data: dia.strftime("%Y-%m-%d")), data: { turbo_frame: "day_modal" }, class: "border border-slate-200 rounded-lg p-2 h-16 flex flex-col items-center hover:bg-slate-50 #{"text-slate-300" unless dia.month == @mes.month}" do %>
          <span class="text-sm"><%= dia.day %></span>
          <div class="flex gap-1 mt-1">
            <% (@cores_por_dia[dia] || []).each do |cor| %>
              <span class="w-2 h-2 rounded-full" style="background-color: <%= cor %>"></span>
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

Note: this view links to `calendario_dia_path`, which doesn't exist until Task 7 — expected, no test in this task clicks that link.

- [ ] **Step 6: Run and confirm pass**

Run: `bin/rails test test/controllers/calendario_controller_test.rb`
Expected: PASS (3 tests).

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all PASS — this also confirms Task 4's `categorias/index.html.erb` and Task 5's `plantoes/index.html.erb` links to `calendario_path` now resolve.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/calendario_controller.rb app/views/calendario/show.html.erb test/controllers/calendario_controller_test.rb
git commit -m "Add calendário month grid view"
```

---

### Task 7: Calendário day modal (Turbo Frame)

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/calendario_controller.rb`
- Create: `app/views/calendario/dia.html.erb`
- Test: `test/controllers/calendario_controller_test.rb`

**Interfaces:**
- Consumes: `calendario_path` (Task 6), `plantoes_path` and `return_to`/`categoria_id` handling (Task 5), `Categoria`/`Plantao` (Tasks 2/3).
- Produces: `calendario_dia_path(data: "YYYY-MM-DD")` — this is what Task 6's day links and this task's own "Fechar"/remove links/redirects target.

- [ ] **Step 1: Write the failing controller tests**

Append to `test/controllers/calendario_controller_test.rb` (inside the class, before the final `end`):

```ruby
  test "should get dia with existing plantoes" do
    categoria = categorias(:hospital_x)
    Plantao.create!(data: Date.new(2026, 9, 20), categoria: categoria)

    get calendario_dia_url(data: "2026-09-20")

    assert_response :success
    assert_match categoria.nome, response.body
  end

  test "should get dia without plantoes" do
    get calendario_dia_url(data: "2026-09-25")

    assert_response :success
    assert_match "Nenhum plantão", response.body
  end
```

- [ ] **Step 2: Run and confirm failure**

Run: `bin/rails test test/controllers/calendario_controller_test.rb`
Expected: FAIL with a routing error (`calendario_dia_url` undefined).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, add right after the `calendario` route:

```ruby
  get "calendario/:data", to: "calendario#dia", as: :calendario_dia, constraints: { data: /\d{4}-\d{2}-\d{2}/ }
```

- [ ] **Step 4: Add the controller action**

In `app/controllers/calendario_controller.rb`, add a public `dia` action above `private`:

```ruby
  def dia
    @data = Date.parse(params[:data])
    @plantoes = Plantao.where(data: @data).includes(:categoria).order(:hora_inicio)
    @categorias = Categoria.order(:nome)
  end
```

- [ ] **Step 5: Create the view**

Create `app/views/calendario/dia.html.erb`:

```erb
<%= turbo_frame_tag "day_modal" do %>
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg p-4 w-full max-w-sm flex flex-col gap-3">
      <div class="flex justify-between items-center">
        <h2 class="font-semibold"><%= @data.strftime("%d/%m/%Y") %></h2>
        <%= link_to "Fechar", calendario_path(mes: @data.strftime("%Y-%m")), class: "text-sm text-slate-500 hover:underline" %>
      </div>

      <% if @plantoes.any? %>
        <div class="flex flex-col gap-2">
          <% @plantoes.each do |plantao| %>
            <div class="flex justify-between items-center border border-slate-200 rounded px-3 py-2">
              <div class="flex items-center gap-2">
                <span class="w-3 h-3 rounded-full shrink-0" style="background-color: <%= plantao.categoria&.cor || "#94a3b8" %>"></span>
                <span class="text-sm">
                  <%= plantao.categoria&.nome || plantao.local || "Sem categoria" %>
                  · <%= plantao.hora_inicio.strftime("%H:%M") %>–<%= plantao.hora_fim.strftime("%H:%M") %>
                </span>
              </div>
              <%= button_to "Remover", plantao_path(plantao), method: :delete, params: { return_to: calendario_dia_path(data: @data.strftime("%Y-%m-%d")) }, class: "text-red-600 text-xs hover:underline", form: { data: { turbo_confirm: "Remover este plantão?" } } %>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="text-slate-500 text-sm">Nenhum plantão neste dia.</p>
      <% end %>

      <%= form_with url: plantoes_path, method: :post, class: "flex flex-col gap-2 border-t border-slate-200 pt-3" do %>
        <%= hidden_field_tag "plantao[data]", @data.strftime("%Y-%m-%d") %>
        <%= hidden_field_tag "return_to", calendario_dia_path(data: @data.strftime("%Y-%m-%d")) %>
        <%= label_tag "plantao_categoria_id", "Categoria", class: "text-sm font-medium" %>
        <%= collection_select(:plantao, :categoria_id, @categorias, :id, :nome, {}, class: "border border-slate-300 rounded px-3 py-2") %>
        <%= submit_tag "Adicionar plantão", class: "self-start bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 cursor-pointer" %>
      <% end %>
    </div>
  </div>
<% end %>
```

- [ ] **Step 6: Run and confirm pass**

Run: `bin/rails test test/controllers/calendario_controller_test.rb`
Expected: PASS (5 tests).

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all PASS.

- [ ] **Step 8: Manual smoke test**

Run: `bin/dev` (or `bin/rails server`), open `/calendario`, click a day, confirm the modal appears in place (no full page reload), pick a category and submit, confirm the day now shows a colored dot and the modal lists the new plantão, click "Remover" and confirm it disappears, click "Fechar" and confirm the modal closes back to the plain grid. Stop the server afterward.

- [ ] **Step 9: Commit**

```bash
git add config/routes.rb app/controllers/calendario_controller.rb app/views/calendario/dia.html.erb test/controllers/calendario_controller_test.rb
git commit -m "Add calendário day modal for creating/removing plantões by categoria"
```
