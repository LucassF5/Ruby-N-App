# UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply a consistent design system (colors, buttons, form fields) across the whole app, restructure the tab bar (Home / Calendário / Profile), redesign auth pages, and merge `/settings` into `/profile`.

**Architecture:** Four shared ERB partials (`_button_primary`, `_button_danger`, `_link_action`, `_field`) become the single source of markup/classes for interactive elements. Views are updated page-group by page-group to consume them. Navigation config (`ruby_native.yml` tabs + web navbar) is updated once, early, since it has no coupling to the partials. `/settings` is merged into `/profile` last, since it's the only task that changes routes/controllers.

**Tech Stack:** Rails 8, Tailwind CSS v4 (`tailwindcss-rails`, CSS-based config, no `tailwind.config.js` — arbitrary value classes like `bg-[#007AFF]` work out of the box via content scanning), Minitest (`ActionDispatch::IntegrationTest`), `ruby_native` gem (native tab bar driven by `config/ruby_native.yml`).

**Spec:** `docs/superpowers/specs/2026-09-04-ui-redesign-design.md`

## Global Constraints

- Primary color is `#007AFF` (from `appearance.tint_color` in `config/ruby_native.yml`) — written as literal Tailwind arbitrary-value classes (`bg-[#007AFF]`, `text-[#007AFF]`, `border-[#007AFF]`), not `indigo-*`. Hover shade is `#0066CC`.
- Danger color stays `red-600` / `red-700` (unchanged, just moved into a partial).
- Neutral colors stay `slate-*` (unchanged).
- Light-only. No `dark:` classes, no `{light:, dark:}` in YAML.
- No new button sizes — one size everywhere: `px-4 py-2 rounded font-medium` (primary/danger), `text-sm hover:underline` (link action).
- No behavior/validation changes anywhere except the `/settings` → `/profile` route merge (Task 5) — that task preserves `SettingsController#update`'s exact logic.
- After editing any view in a task, run `bin/rails tailwindcss:build` before running tests, so new arbitrary-value classes exist in the compiled CSS.

---

## Task 1: Design system partials + Home (shifts index & form)

**Files:**
- Create: `app/views/shared/_button_primary.html.erb`
- Create: `app/views/shared/_button_danger.html.erb`
- Create: `app/views/shared/_link_action.html.erb`
- Create: `app/views/shared/_field.html.erb`
- Modify: `app/views/shifts/index.html.erb`
- Modify: `app/views/shifts/_form.html.erb`
- Test: `test/controllers/shifts_controller_test.rb`

**Interfaces:**
- Produces (used by every later task):
  - `render "shared/button_primary", text:, url:, method: :get (default), html: {}` — solid `#007AFF` button/link.
  - `render "shared/button_danger", text:, url:, method: :delete (default), html: {}` — solid red button (used with `html: { form: { data: { turbo_confirm: "..." } } } }` for confirm dialogs).
  - `render "shared/link_action", text:, url:, variant: :primary (default) | :neutral, method: :get (default), html: {}` — underlined text link/button.
  - `render "shared/field", form:, attribute:, label:, type: :text (default) | :email | :password | :file, options: {}` — labeled form field.

- [ ] **Step 1: Write failing test asserting the new button markup on the shifts index page**

Edit `test/controllers/shifts_controller_test.rb`, add after the `"should get index"` test:

```ruby
  test "index uses the primary button partial for the new-shift action" do
    get root_url
    assert_response :success
    assert_match "bg-[#007AFF]", response.body
    assert_match "Novo plantão", response.body
  end

  test "index uses the danger button partial for removing a shift" do
    get root_url
    assert_response :success
    assert_match "Remover", response.body
    assert_match "bg-red-600", response.body
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/controllers/shifts_controller_test.rb -n "/index uses the/"`
Expected: FAIL — `bg-[#007AFF]` not found in `response.body` (page still renders old `indigo-600`/`red-600` inline classes, so the danger one may already pass; the primary one must fail).

- [ ] **Step 3: Create the four shared partials**

`app/views/shared/_button_primary.html.erb`:
```erb
<%
  button_method = local_assigns.fetch(:method, :get)
  extra_html = local_assigns.fetch(:html, {})
  base_css = "inline-block bg-[#007AFF] hover:bg-[#0066CC] text-white px-4 py-2 rounded font-medium"
  css = [base_css, extra_html[:class]].compact.join(" ")
%>
<% if button_method == :get %>
  <%= link_to text, url, extra_html.except(:class, :form).merge(class: css) %>
<% else %>
  <%= button_to text, url, method: button_method, class: css, form: extra_html.fetch(:form, {}) %>
<% end %>
```

`app/views/shared/_button_danger.html.erb`:
```erb
<%
  button_method = local_assigns.fetch(:method, :delete)
  extra_html = local_assigns.fetch(:html, {})
  base_css = "inline-block bg-red-600 hover:bg-red-700 text-white px-4 py-2 rounded font-medium"
  css = [base_css, extra_html[:class]].compact.join(" ")
%>
<% if button_method == :get %>
  <%= link_to text, url, extra_html.except(:class, :form).merge(class: css) %>
<% else %>
  <%= button_to text, url, method: button_method, class: css, form: extra_html.fetch(:form, {}) %>
<% end %>
```

`app/views/shared/_link_action.html.erb`:
```erb
<%
  variant = local_assigns.fetch(:variant, :primary)
  link_method = local_assigns.fetch(:method, :get)
  extra_html = local_assigns.fetch(:html, {})
  color = variant == :neutral ? "text-slate-500" : "text-[#007AFF]"
  base_css = "#{color} hover:underline text-sm"
  css = [base_css, extra_html[:class]].compact.join(" ")
%>
<% if link_method == :get %>
  <%= link_to text, url, extra_html.except(:class, :form).merge(class: css) %>
<% else %>
  <%= button_to text, url, method: link_method, class: "#{css} bg-transparent border-0 p-0 cursor-pointer", form: extra_html.fetch(:form, {}) %>
<% end %>
```

Note: `extra_html[:class]`, when passed, is *appended* to the base classes (not a full replace) via the `[base_css, extra_html[:class]].compact.join(" ")` line — so callers can add sizing/utility classes (e.g. Task 4's compact danger button in the day modal) without losing the partial's default color/shape classes.

`app/views/shared/_field.html.erb`:
```erb
<%
  field_type = local_assigns.fetch(:type, :text)
  options = local_assigns.fetch(:options, {})
  input_css = "w-full border border-slate-300 rounded px-3 py-2"
%>
<div>
  <%= form.label attribute, label, class: "block text-sm font-medium mb-1" %>
  <% case field_type %>
  <% when :email %>
    <%= form.email_field attribute, options.reverse_merge(class: input_css) %>
  <% when :password %>
    <%= form.password_field attribute, options.reverse_merge(class: input_css) %>
  <% when :file %>
    <%= form.file_field attribute, options.reverse_merge(class: "w-full") %>
  <% else %>
    <%= form.text_field attribute, options.reverse_merge(class: input_css) %>
  <% end %>
</div>
```

- [ ] **Step 4: Wire the partials into `app/views/shifts/index.html.erb`**

Replace the file with:

```erb
<% content_for :title, "Meus Plantões" %>

<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold">Meus Plantões</h1>
  <div class="flex gap-3 items-center">
    <%= render "shared/link_action", text: "Ver calendário", url: calendar_path %>
    <%= render "shared/button_primary", text: "Novo plantão", url: new_shift_path %>
  </div>
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
            <% if shift.category.present? %>
              <p class="text-slate-600 mt-1 flex items-center gap-2">
                <span class="inline-block w-3 h-3 rounded-full shrink-0" style="background-color: <%= shift.category.color %>"></span>
                <%= shift.category.name %>
              </p>
            <% elsif shift.location.present? %>
              <p class="text-slate-600 mt-1"><%= shift.location %></p>
            <% end %>
            <% if shift.notes.present? %>
              <p class="text-slate-500 text-sm mt-1"><%= shift.notes %></p>
            <% end %>
          </div>
          <div class="flex gap-3 shrink-0 items-center">
            <%= render "shared/link_action", text: "Editar", url: edit_shift_path(shift) %>
            <%= render "shared/button_danger", text: "Remover", url: shift_path(shift), html: { form: { data: { turbo_confirm: "Remover este plantão?" } } } %>
          </div>
        </div>
      </div>
    <% end %>
  </div>
<% end %>
```

- [ ] **Step 5: Wire the primary button into `app/views/shifts/_form.html.erb`**

Replace the file with:

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

  <%= f.label :category_id, "Categoria (opcional)", class: "text-sm font-medium" %>
  <%= f.collection_select :category_id, @categories, :id, :name, { include_blank: "Nenhuma" }, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :location, "Local (opcional)", class: "text-sm font-medium" %>
  <%= f.text_field :location, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :notes, "Observação (opcional)", class: "text-sm font-medium" %>
  <%= f.text_area :notes, rows: 3, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.submit "Salvar", class: "self-start bg-[#007AFF] hover:bg-[#0066CC] text-white px-4 py-2 rounded font-medium cursor-pointer" %>
<% end %>
```

Note: `_button_primary` renders its own `link_to`/`button_to` with an explicit `url:` — it can't submit an enclosing `form_with` block. Form submits (here and in Task 5's profile form) keep using `f.submit`/`submit_tag` with the same three classes (`bg-[#007AFF] hover:bg-[#0066CC] text-white ... rounded font-medium`) copied literally, so the color stays in sync without forcing an awkward partial API onto plain submit buttons.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/shifts_controller_test.rb`
Expected: PASS (all tests, including the two new ones).

- [ ] **Step 7: Rebuild Tailwind CSS**

Run: `bin/rails tailwindcss:build`

- [ ] **Step 8: Commit**

```bash
git add app/views/shared app/views/shifts test/controllers/shifts_controller_test.rb app/assets/builds/tailwind.css
git commit -m "Add shared button/field partials, restyle Home with primary color"
```

---

## Task 2: Navigation (tab bar + web navbar)

**Files:**
- Modify: `config/ruby_native.yml`
- Modify: `app/views/layouts/_navbar.html.erb`
- Test: `test/config/ruby_native_tabs_test.rb` (new)

**Interfaces:**
- Consumes: `render "shared/link_action", text:, url:, method:, html:` from Task 1 (for the "Sair" logout button in the navbar).
- Produces: tab bar with 3 tabs — no other task depends on this beyond it existing.

- [ ] **Step 1: Write a failing test for the tab list**

Create `test/config/ruby_native_tabs_test.rb`:

```ruby
require "test_helper"
require "yaml"

class RubyNativeTabsTest < ActiveSupport::TestCase
  test "tab bar has Home, Calendário and Profile, and no Settings" do
    config = YAML.load_file(Rails.root.join("config/ruby_native.yml"))
    titles = config["tabs"].map { |tab| tab["title"] }

    assert_equal ["Home", "Calendário", "Profile"], titles
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/config/ruby_native_tabs_test.rb`
Expected: FAIL — `titles` is `["Home", "Profile", "Settings"]`.

- [ ] **Step 3: Update the tabs in `config/ruby_native.yml`**

Replace the `tabs:` section (currently lines 93–107) with:

```yaml
tabs:
  # Icons are SF Symbols on iOS and Material Icons on Android.
  # https://rubynative.com/docs/icons
  - title: Home
    path: /
    icon: house

  - title: Calendário
    path: /calendar
    icon: calendar

  - title: Profile
    path: /profile
    icon: person
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/config/ruby_native_tabs_test.rb`
Expected: PASS

- [ ] **Step 5: Update the web navbar fallback**

Replace `app/views/layouts/_navbar.html.erb` with:

```erb
<nav class="bg-white border-b border-slate-200">
  <div class="container mx-auto px-5 py-4 flex gap-6 items-center">
    <%= link_to "Home", root_path, class: "font-medium hover:text-[#007AFF]" %>
    <%= link_to "Calendário", calendar_path, class: "font-medium hover:text-[#007AFF]" %>
    <%= link_to "Profile", profile_path, class: "font-medium hover:text-[#007AFF]" %>
    <% if authenticated? %>
      <div class="ml-auto">
        <%= render "shared/link_action", text: "Sair", url: session_path, method: :delete, variant: :neutral %>
      </div>
    <% end %>
  </div>
</nav>
```

- [ ] **Step 6: Run the full test suite to check nothing else broke**

Run: `bin/rails test`
Expected: PASS (navbar isn't asserted on by any existing test, but the `profile_path` helper must already exist at this point — it does, unchanged until Task 5).

- [ ] **Step 7: Rebuild Tailwind CSS**

Run: `bin/rails tailwindcss:build`

- [ ] **Step 8: Commit**

```bash
git add config/ruby_native.yml app/views/layouts/_navbar.html.erb test/config/ruby_native_tabs_test.rb app/assets/builds/tailwind.css
git commit -m "Restructure tab bar: Home, Calendário, Profile (drop Settings tab)"
```

---

## Task 3: Auth pages (registrations, sessions, passwords)

**Files:**
- Modify: `app/views/registrations/new.html.erb`
- Modify: `app/views/sessions/new.html.erb`
- Modify: `app/views/passwords/new.html.erb`
- Modify: `app/views/passwords/edit.html.erb`

**Interfaces:**
- Consumes: `render "shared/field"`, `render "shared/button_primary"`, `render "shared/link_action"` from Task 1.

- [ ] **Step 1: Confirm current auth tests pass before touching views (baseline)**

Run: `bin/rails test test/controllers/registrations_controller_test.rb test/controllers/sessions_controller_test.rb`
Expected: PASS (this is the regression baseline these views must keep passing — no new test is added in this task since no behavior changes, only markup).

- [ ] **Step 2: Redesign `app/views/registrations/new.html.erb`**

Replace with:

```erb
<% content_for :title, "Criar conta" %>

<div class="max-w-sm mx-auto mt-8 bg-white border border-slate-200 rounded-lg p-6">
  <h1 class="text-2xl font-semibold mb-4">Criar conta</h1>

  <%= form_with model: @user, url: registrations_path, class: "space-y-4" do |form| %>
    <% if @user.errors.any? %>
      <ul class="text-red-600 text-sm">
        <% @user.errors.full_messages.each do |message| %>
          <li><%= message %></li>
        <% end %>
      </ul>
    <% end %>

    <%= render "shared/field", form: form, attribute: :name, label: "Nome", options: { required: true, autofocus: true } %>
    <%= render "shared/field", form: form, attribute: :email_address, label: "Email", type: :email, options: { required: true } %>
    <%= render "shared/field", form: form, attribute: :password, label: "Senha", type: :password, options: { required: true, autocomplete: "new-password" } %>
    <%= render "shared/field", form: form, attribute: :password_confirmation, label: "Confirmar senha", type: :password, options: { required: true, autocomplete: "new-password" } %>

    <%= form.submit "Criar conta", class: "bg-[#007AFF] hover:bg-[#0066CC] text-white rounded px-4 py-2 font-medium cursor-pointer" %>
  <% end %>
</div>
```

- [ ] **Step 3: Redesign `app/views/sessions/new.html.erb`**

Replace with:

```erb
<% content_for :title, "Entrar" %>

<div class="max-w-sm mx-auto mt-8 bg-white border border-slate-200 rounded-lg p-6">
  <h1 class="text-2xl font-semibold mb-4">Entrar</h1>

  <%= form_with url: session_path, class: "space-y-4" do |form| %>
    <%= render "shared/field", form: form, attribute: :email_address, label: "Email", type: :email, options: { required: true, autofocus: true } %>
    <%= render "shared/field", form: form, attribute: :password, label: "Senha", type: :password, options: { required: true, autocomplete: "current-password" } %>

    <%= form.submit "Entrar", class: "bg-[#007AFF] hover:bg-[#0066CC] text-white rounded px-4 py-2 font-medium cursor-pointer" %>
  <% end %>

  <%= button_to "Entrar com Apple", "/auth/apple", data: { turbo: false }, class: "mt-4 bg-black hover:bg-slate-800 text-white rounded px-4 py-2 font-medium cursor-pointer" %>

  <p class="mt-4 text-sm flex gap-2">
    <%= render "shared/link_action", text: "Criar conta", url: new_registration_path %> ·
    <%= render "shared/link_action", text: "Esqueci minha senha", url: new_password_path %>
  </p>
</div>
```

- [ ] **Step 4: Redesign `app/views/passwords/new.html.erb`**

Replace with:

```erb
<% content_for :title, "Esqueci minha senha" %>

<div class="max-w-sm mx-auto mt-8 bg-white border border-slate-200 rounded-lg p-6">
  <h1 class="text-2xl font-semibold mb-4">Esqueci minha senha</h1>

  <%= form_with url: passwords_path, class: "space-y-4" do |form| %>
    <%= render "shared/field", form: form, attribute: :email_address, label: "Email", type: :email, options: { required: true, autofocus: true } %>

    <%= form.submit "Enviar link de redefinição", class: "bg-[#007AFF] hover:bg-[#0066CC] text-white rounded px-4 py-2 font-medium cursor-pointer" %>
  <% end %>
</div>
```

- [ ] **Step 5: Redesign `app/views/passwords/edit.html.erb`**

Replace with:

```erb
<% content_for :title, "Redefinir senha" %>

<div class="max-w-sm mx-auto mt-8 bg-white border border-slate-200 rounded-lg p-6">
  <h1 class="text-2xl font-semibold mb-4">Redefinir senha</h1>

  <%= form_with url: password_path(params[:token]), method: :put, class: "space-y-4" do |form| %>
    <%= render "shared/field", form: form, attribute: :password, label: "Nova senha", type: :password, options: { required: true, autocomplete: "new-password" } %>
    <%= render "shared/field", form: form, attribute: :password_confirmation, label: "Confirmar senha", type: :password, options: { required: true, autocomplete: "new-password" } %>

    <%= form.submit "Redefinir senha", class: "bg-[#007AFF] hover:bg-[#0066CC] text-white rounded px-4 py-2 font-medium cursor-pointer" %>
  <% end %>
</div>
```

- [ ] **Step 6: Run the tests to verify nothing broke**

Run: `bin/rails test test/controllers/registrations_controller_test.rb test/controllers/sessions_controller_test.rb`
Expected: PASS

- [ ] **Step 7: Rebuild Tailwind CSS**

Run: `bin/rails tailwindcss:build`

- [ ] **Step 8: Commit**

```bash
git add app/views/registrations app/views/sessions app/views/passwords app/assets/builds/tailwind.css
git commit -m "Redesign auth pages with card layout and shared field/button partials"
```

---

## Task 4: Calendar (show + day)

**Files:**
- Modify: `app/views/calendar/show.html.erb`
- Modify: `app/views/calendar/day.html.erb`
- Test: `test/controllers/calendar_controller_test.rb`

**Interfaces:**
- Consumes: `render "shared/link_action"`, `render "shared/button_primary"`, `render "shared/button_danger"` from Task 1.

- [ ] **Step 1: Write a failing test asserting the "Ver lista" link is gone**

Edit `test/controllers/calendar_controller_test.rb`, add after `"should get calendar for current month"`:

```ruby
  test "does not show the redundant 'Ver lista' link now that Home and Calendário are separate tabs" do
    get calendar_url
    assert_response :success
    assert_no_match "Ver lista", response.body
  end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/calendar_controller_test.rb -n "/redundant/"`
Expected: FAIL — "Ver lista" link is still present.

- [ ] **Step 3: Redesign `app/views/calendar/show.html.erb`**

Replace with:

```erb
<% content_for :title, "Calendário" %>

<div class="flex justify-between items-center mb-4">
  <h1 class="text-2xl font-semibold"><%= @month.strftime("%B %Y") %></h1>
  <%= render "shared/link_action", text: "Gerenciar categorias", url: categories_path %>
</div>

<div class="flex justify-between items-center mb-4">
  <%= render "shared/link_action", text: "‹ Mês anterior", url: calendar_path(month: (@month - 1.month).strftime("%Y-%m")) %>
  <%= render "shared/link_action", text: "Próximo mês ›", url: calendar_path(month: (@month + 1.month).strftime("%Y-%m")) %>
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
```

- [ ] **Step 4: Redesign `app/views/calendar/day.html.erb`**

Replace with:

```erb
<%= turbo_frame_tag "day_modal" do %>
  <div class="fixed inset-0 bg-black/40 flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-lg p-4 w-full max-w-sm flex flex-col gap-3">
      <div class="flex justify-between items-center">
        <h2 class="font-semibold"><%= @date.strftime("%d/%m/%Y") %></h2>
        <%= render "shared/link_action", text: "Fechar", url: calendar_path(month: @date.strftime("%Y-%m")), variant: :neutral %>
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
              <%= render "shared/button_danger", text: "Remover", url: shift_path(shift), html: { class: "!px-3 !py-1 !text-xs", form: { data: { turbo_confirm: "Remover este plantão?" } } } %>
            </div>
          <% end %>
        </div>
      <% else %>
        <p class="text-slate-500 text-sm">Nenhum plantão neste dia.</p>
      <% end %>

      <% if @categories.empty? %>
        <p class="text-slate-500 text-sm border-t border-slate-200 pt-3">
          Cadastre uma categoria antes de adicionar um plantão.
          <%= render "shared/link_action", text: "Nova categoria", url: new_category_path %>
        </p>
      <% else %>
        <%= form_with url: shifts_path, method: :post, class: "flex flex-col gap-2 border-t border-slate-200 pt-3" do %>
          <%= hidden_field_tag "shift[date]", @date.strftime("%Y-%m-%d") %>
          <%= hidden_field_tag "return_to", calendar_day_path(date: @date.strftime("%Y-%m-%d")) %>
          <%= label_tag "shift_category_id", "Categoria", class: "text-sm font-medium" %>
          <%= collection_select(:shift, :category_id, @categories, :id, :name, {}, class: "border border-slate-300 rounded px-3 py-2") %>
          <%= submit_tag "Adicionar plantão", class: "self-start bg-[#007AFF] hover:bg-[#0066CC] text-white px-4 py-2 rounded font-medium cursor-pointer" %>
        <% end %>
      <% end %>
    </div>
  </div>
<% end %>
```

Note: `_button_danger`'s default size is `px-4 py-2` (button-sized); inside the compact shift row the original design used a smaller `text-xs` link. `html: { class: "!px-3 !py-1 !text-xs" }` appends Tailwind `!important` overrides on top of the partial's base classes (see the append behavior added to the partials in Task 1, Step 3) — no `size:` option needed on the partial itself (YAGNI, only this one caller needs it).

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/calendar_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Rebuild Tailwind CSS**

Run: `bin/rails tailwindcss:build`

- [ ] **Step 7: Commit**

```bash
git add app/views/calendar test/controllers/calendar_controller_test.rb app/assets/builds/tailwind.css
git commit -m "Redesign calendar pages, drop redundant 'Ver lista' link"
```

---

## Task 5: Profile absorbs Settings

**Files:**
- Create: `app/controllers/profiles_controller.rb`
- Create: `app/views/profiles/show.html.erb`
- Delete: `app/controllers/pages_controller.rb`
- Delete: `app/controllers/settings_controller.rb`
- Delete: `app/views/pages/profile.html.erb` (and the now-empty `app/views/pages/` directory)
- Delete: `app/views/settings/edit.html.erb` (and the now-empty `app/views/settings/` directory)
- Delete: `test/controllers/pages_controller_test.rb`
- Delete: `test/controllers/settings_controller_test.rb`
- Create: `test/controllers/profiles_controller_test.rb`
- Modify: `config/routes.rb`
- Modify: `test/controllers/sessions_controller_test.rb`

**Interfaces:**
- Consumes: `render "shared/field"`, `render "shared/button_primary"` from Task 1.
- Produces: `profile_path` / `profile_url` route helper (GET → `ProfilesController#show`, PATCH → `ProfilesController#update`) — already used by `_navbar.html.erb` (Task 2) and `sessions_controller_test.rb`, both unaffected by the helper name (it doesn't change, only what it points to).

- [ ] **Step 1: Write the failing test for the merged controller**

Create `test/controllers/profiles_controller_test.rb`:

```ruby
require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get show" do
    get profile_url
    assert_response :success
  end

  test "show displays the signed-in user's name and email" do
    get profile_url
    assert_match users(:jane).name, response.body
    assert_match users(:jane).email_address, response.body
  end

  test "updates name and email" do
    patch profile_url, params: { user: { name: "Jane Updated", email_address: "jane.updated@example.com", current_password: "password" } }
    assert_redirected_to profile_url
    assert_equal "Jane Updated", users(:jane).reload.name
    assert_equal "jane.updated@example.com", users(:jane).reload.email_address
  end

  test "rejects email change without current password" do
    patch profile_url, params: { user: { email_address: "jane.updated@example.com" } }
    assert_response :unprocessable_entity
    assert_equal "jane@example.com", users(:jane).reload.email_address
  end

  test "rejects email change with wrong current password" do
    patch profile_url, params: { user: { email_address: "jane.updated@example.com", current_password: "wrong" } }
    assert_response :unprocessable_entity
    assert_equal "jane@example.com", users(:jane).reload.email_address
  end

  test "updates password when current password is correct" do
    patch profile_url, params: { user: { current_password: "password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to profile_url
    assert users(:jane).reload.authenticate("newpassword")
  end

  test "rejects password change when current password is wrong" do
    patch profile_url, params: { user: { current_password: "wrong", password: "newpassword", password_confirmation: "newpassword" } }
    assert_response :unprocessable_entity
    assert_not users(:jane).reload.authenticate("newpassword")
  end

  test "updates avatar" do
    file = fixture_file_upload("avatar.png", "image/png")

    patch profile_url, params: { user: { avatar: file } }

    assert_redirected_to profile_url
    assert users(:jane).reload.avatar.attached?
  end

  test "rejects avatar with disallowed content type" do
    file = fixture_file_upload("not_an_image.txt", "text/plain")

    patch profile_url, params: { user: { avatar: file } }

    assert_response :unprocessable_entity
    assert_not users(:jane).reload.avatar.attached?
  end

  test "destroys other sessions after password change" do
    other_session = open_session
    other_session.post session_url, params: { email_address: users(:jane).email_address, password: "password" }
    other_session_id = users(:jane).sessions.order(:created_at).last.id

    patch profile_url, params: { user: { current_password: "password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to profile_url

    assert_nil Session.find_by(id: other_session_id)

    other_session.get profile_url
    other_session.assert_redirected_to new_session_url
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/profiles_controller_test.rb`
Expected: FAIL — `uninitialized constant ProfilesController` (or routing error).

- [ ] **Step 3: Update `config/routes.rb`**

Remove these two lines:
```ruby
  get "profile" => "pages#profile"
  resource :settings, only: %i[ edit update ]
```

Add in their place:
```ruby
  resource :profile, only: %i[ show update ]
```

- [ ] **Step 4: Create `app/controllers/profiles_controller.rb`**

```ruby
class ProfilesController < ApplicationController
  def show
    @user = Current.user
  end

  def update
    @user = Current.user

    if requires_current_password? && !@user.authenticate(profile_params[:current_password])
      @user.errors.add(:current_password, "está incorreta")
      render :show, status: :unprocessable_entity
      return
    end

    if @user.update(update_params)
      @user.sessions.where.not(id: Current.session.id).destroy_all if password_change_requested?
      redirect_to profile_path, notice: "Perfil atualizado."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private
    def profile_params
      params.require(:user).permit(:name, :email_address, :current_password, :password, :password_confirmation, :avatar)
    end

    def password_change_requested?
      profile_params[:password].present?
    end

    def email_change_requested?
      profile_params[:email_address].present? && profile_params[:email_address] != @user.email_address
    end

    def requires_current_password?
      password_change_requested? || email_change_requested?
    end

    def update_params
      attrs = profile_params.except(:current_password)
      attrs = attrs.except(:password, :password_confirmation) unless password_change_requested?
      attrs
    end
end
```

- [ ] **Step 5: Create `app/views/profiles/show.html.erb`**

```erb
<% content_for :title, "Profile" %>

<h1 class="text-2xl font-semibold mb-4">Profile</h1>

<div class="bg-white border border-slate-200 rounded-lg p-4 mb-6 flex items-center gap-4">
  <% if @user.avatar.attached? %>
    <%= image_tag @user.avatar, class: "w-16 h-16 rounded-full object-cover" %>
  <% end %>
  <div>
    <p class="text-slate-900 font-medium"><%= @user.name %></p>
    <p class="text-slate-600"><%= @user.email_address %></p>
  </div>
</div>

<%= form_with model: @user, url: profile_path, method: :patch, multipart: true, class: "space-y-4 max-w-sm" do |form| %>
  <% if @user.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% @user.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <%= render "shared/field", form: form, attribute: :name, label: "Nome" %>
  <%= render "shared/field", form: form, attribute: :email_address, label: "Email", type: :email %>
  <%= render "shared/field", form: form, attribute: :avatar, label: "Foto de perfil", type: :file %>

  <fieldset class="border-t border-slate-200 pt-4">
    <legend class="text-sm font-medium mb-2">Trocar senha (opcional)</legend>

    <%= render "shared/field", form: form, attribute: :current_password, label: "Senha atual", type: :password, options: { autocomplete: "current-password" } %>
    <%= render "shared/field", form: form, attribute: :password, label: "Nova senha", type: :password, options: { autocomplete: "new-password" } %>
    <%= render "shared/field", form: form, attribute: :password_confirmation, label: "Confirmar nova senha", type: :password, options: { autocomplete: "new-password" } %>
  </fieldset>

  <%= form.submit "Salvar", class: "bg-[#007AFF] hover:bg-[#0066CC] text-white rounded px-4 py-2 font-medium cursor-pointer" %>
<% end %>
```

- [ ] **Step 6: Delete the old controllers, views, and tests**

```bash
git rm app/controllers/pages_controller.rb app/controllers/settings_controller.rb
git rm app/views/pages/profile.html.erb app/views/settings/edit.html.erb
git rm test/controllers/pages_controller_test.rb test/controllers/settings_controller_test.rb
rmdir app/views/pages app/views/settings 2>/dev/null || true
```

- [ ] **Step 7: Update `test/controllers/sessions_controller_test.rb`**

In the `"redirects unauthenticated visitors to sign in"` test, remove this block (the route no longer exists):

```ruby
    get edit_settings_url
    assert_redirected_to new_session_url
```

(`profile_url` is already asserted a few lines above it in the same test, so coverage of the merged route stays intact.)

- [ ] **Step 8: Run the full test suite**

Run: `bin/rails test`
Expected: PASS — every test, including `profiles_controller_test.rb`, `sessions_controller_test.rb`, and all tests from Tasks 1–4.

- [ ] **Step 9: Rebuild Tailwind CSS**

Run: `bin/rails tailwindcss:build`

- [ ] **Step 10: Manual smoke test**

Run: `bin/dev` (or `bin/rails server` + `bin/rails tailwindcss:watch` in another terminal), then in a browser: sign in, confirm the tab bar/navbar shows Home/Calendário/Profile (no Settings), visit `/profile` and confirm it shows the avatar/name/email AND the edit form on one page, update the name, confirm the redirect stays on `/profile` with the new name shown. Visit `/calendar`, confirm it's reachable as a tab and has no "Ver lista" link. Visit `/session/new`, `/registrations/new`, `/passwords/new` and confirm the card layout renders correctly.

- [ ] **Step 11: Commit**

```bash
git add -A
git commit -m "Merge Settings into Profile as a single page; remove Settings controller/route"
```
