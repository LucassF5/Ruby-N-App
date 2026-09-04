# Autenticação Rails + OAuth Apple Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Rails 8 native authentication (email/senha + cadastro aberto), tornar o app multiusuário, adicionar login com Apple via OAuth, e uma página Settings funcional (nome/email/senha/avatar) e Profile com dados reais.

**Architecture:** Usa o gerador `bin/rails generate authentication` do Rails 8 (User/Session/Current + concern `Authentication`) como base. `Shift`/`Category` passam a pertencer a um `User` (multiusuário). Login com Apple via `omniauth` + `omniauth-apple`, reaproveitando o mesmo `Session`/`Current` criado pela auth base. Settings/Profile passam a operar sobre `Current.user`.

**Tech Stack:** Rails 8.1, Minitest (fixtures), `has_secure_password` (bcrypt), `omniauth`/`omniauth-apple`/`omniauth-rails_csrf_protection`, Active Storage + `image_processing` (avatar).

**Spec:** `docs/superpowers/specs/2026-09-03-auth-oauth-apple-design.md`

## Global Constraints

- Signup é aberto (qualquer um cria conta com email/senha).
- Só Apple como provider OAuth por ora — nada de Google/GitHub.
- App vira multiusuário: `Shift` e `Category` sempre escopados por `Current.user`, nunca consultados pela classe bare em controllers.
- Settings atualiza nome, email, senha e avatar.
- Sem dados de produção — migrations de `user_id` podem ser `null: false` direto, sem backfill.
- Sem outros providers, push, badges, toasts — fora de escopo deste plano.

---

## Task 1: Base de autenticação (gerador Rails 8)

**Files:**
- Modify: `Gemfile`
- Modify: `config/application.rb`
- Create: `app/models/user.rb`
- Create: `app/models/session.rb`
- Create: `app/models/current.rb`
- Create: `app/controllers/concerns/authentication.rb`
- Modify: `app/controllers/application_controller.rb`
- Create: `app/controllers/sessions_controller.rb`
- Create: `app/controllers/passwords_controller.rb`
- Create: `app/mailers/passwords_mailer.rb`
- Create: `app/views/passwords_mailer/reset.html.erb`
- Create: `app/views/passwords_mailer/reset.text.erb`
- Create: `app/views/sessions/new.html.erb`
- Create: `app/views/passwords/new.html.erb`
- Create: `app/views/passwords/edit.html.erb`
- Create: `db/migrate/20260904000001_create_users.rb`
- Create: `db/migrate/20260904000002_create_sessions.rb`
- Modify: `config/routes.rb`
- Modify: `test/test_helper.rb`
- Create: `test/fixtures/users.yml`
- Modify: `app/views/layouts/_navbar.html.erb`
- Modify: `test/controllers/shifts_controller_test.rb`
- Modify: `test/controllers/categories_controller_test.rb`
- Modify: `test/controllers/calendar_controller_test.rb`
- Modify: `test/controllers/pages_controller_test.rb`
- Test: `test/controllers/sessions_controller_test.rb`

**Interfaces:**
- Produces: `User` (`email_address`, `password_digest`, `name`, `has_secure_password`), `Session` (`belongs_to :user`), `Current.session`/`Current.user`, `Authentication` concern methods `authenticated?`, `require_authentication`, `allow_unauthenticated_access(**opts)` (class method), `start_new_session_for(user)`, `terminate_session`, `after_authentication_url`. Route helpers `new_session_path`, `session_path`. Test helper `sign_in_as(user, password: "password")` on `ActionDispatch::IntegrationTest`.
- Consumes: nothing (first task).

- [ ] **Step 1: Add bcrypt gem and enable Action Mailer/Active Job**

`has_secure_password` needs bcrypt; `PasswordsMailer` needs Action Mailer, and `deliver_later` needs Active Job. Both railties are currently commented out.

Edit `Gemfile`, add after the `sqlite3` line:

```ruby
gem "bcrypt", "~> 3.1.7"
```

Edit `config/application.rb`, uncomment two lines:

```ruby
require "active_job/railtie"
```
```ruby
require "action_mailer/railtie"
```

Run: `bundle install`

- [ ] **Step 2: Create the users and sessions migrations**

Create `db/migrate/20260904000001_create_users.rb`:

```ruby
class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
```

Create `db/migrate/20260904000002_create_sessions.rb`:

```ruby
class CreateSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
```

Run: `bin/rails db:migrate`
Expected: both tables created, `db/schema.rb` now lists `users` and `sessions`.

- [ ] **Step 3: Write the models**

Create `app/models/user.rb`:

```ruby
class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
end
```

Create `app/models/session.rb`:

```ruby
class Session < ApplicationRecord
  belongs_to :user
end
```

Create `app/models/current.rb`:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :session
  delegate :user, to: :session, allow_nil: true
end
```

- [ ] **Step 4: Write the Authentication concern and wire it into ApplicationController**

Create `app/controllers/concerns/authentication.rb`:

```ruby
module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      Session.find_by(id: cookies.signed[:session_id])
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    def after_authentication_url
      session.delete(:return_to_after_authenticating) || root_url
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = { value: session.id, httponly: true, same_site: :lax }
      end
    end

    def terminate_session
      Current.session.destroy
      cookies.delete(:session_id)
    end
end
```

Edit `app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
end
```

- [ ] **Step 5: Write SessionsController and its view**

Create `app/controllers/sessions_controller.rb`:

```ruby
class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Tente novamente mais tarde." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Email ou senha inválidos."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path
  end
end
```

Create `app/views/sessions/new.html.erb`:

```erb
<% content_for :title, "Entrar" %>

<h1 class="text-2xl font-semibold mb-4">Entrar</h1>

<%= form_with url: session_path, class: "space-y-4 max-w-sm" do |form| %>
  <div>
    <%= form.label :email_address, "Email", class: "block text-sm font-medium mb-1" %>
    <%= form.email_field :email_address, required: true, autofocus: true, class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <div>
    <%= form.label :password, "Senha", class: "block text-sm font-medium mb-1" %>
    <%= form.password_field :password, required: true, autocomplete: "current-password", class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <%= form.submit "Entrar", class: "bg-indigo-600 text-white rounded px-4 py-2 font-medium" %>
<% end %>

<p class="mt-4 text-sm">
  <%= link_to "Criar conta", new_registration_path %> ·
  <%= link_to "Esqueci minha senha", new_password_path %>
</p>
```

- [ ] **Step 6: Write PasswordsController, mailer, and views**

Create `app/controllers/passwords_controller.rb`:

```ruby
class PasswordsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token, only: %i[ edit update ]

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Se esse email existir, enviamos um link para redefinir a senha."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      redirect_to new_session_path, notice: "Senha redefinida."
    else
      redirect_to edit_password_path(params[:token]), alert: "Não foi possível redefinir a senha."
    end
  end

  private
    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Link de redefinição inválido ou expirado."
    end
end
```

Add password reset token support to `app/models/user.rb` — replace the file with:

```ruby
class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  has_many :sessions, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true

  private
    def password_salt
      password_digest
    end
end
```

Create `app/mailers/passwords_mailer.rb`:

```ruby
class PasswordsMailer < ApplicationMailer
  def reset(user)
    @user = user
    mail subject: "Redefinir senha", to: user.email_address
  end
end
```

Create `app/mailers/application_mailer.rb` only if it does not already exist — check first with `ls app/mailers/application_mailer.rb`; if missing, create it:

```ruby
class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
end
```

Create `app/views/passwords_mailer/reset.html.erb`:

```erb
<p>Alguém pediu para redefinir a senha da sua conta.</p>
<p><%= link_to "Redefinir senha", edit_password_url(@user.generate_token_for(:password_reset)) %></p>
<p>Se não foi você, ignore este email.</p>
```

Create `app/views/passwords_mailer/reset.text.erb`:

```erb
Alguém pediu para redefinir a senha da sua conta.

Redefinir senha: <%= edit_password_url(@user.generate_token_for(:password_reset)) %>

Se não foi você, ignore este email.
```

Create `app/views/passwords/new.html.erb`:

```erb
<% content_for :title, "Esqueci minha senha" %>

<h1 class="text-2xl font-semibold mb-4">Esqueci minha senha</h1>

<%= form_with url: passwords_path, class: "space-y-4 max-w-sm" do |form| %>
  <div>
    <%= form.label :email_address, "Email", class: "block text-sm font-medium mb-1" %>
    <%= form.email_field :email_address, required: true, autofocus: true, class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <%= form.submit "Enviar link de redefinição", class: "bg-indigo-600 text-white rounded px-4 py-2 font-medium" %>
<% end %>
```

Create `app/views/passwords/edit.html.erb`:

```erb
<% content_for :title, "Redefinir senha" %>

<h1 class="text-2xl font-semibold mb-4">Redefinir senha</h1>

<%= form_with url: password_path(params[:token]), method: :put, class: "space-y-4 max-w-sm" do |form| %>
  <div>
    <%= form.label :password, "Nova senha", class: "block text-sm font-medium mb-1" %>
    <%= form.password_field :password, required: true, autocomplete: "new-password", class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <div>
    <%= form.label :password_confirmation, "Confirmar senha", class: "block text-sm font-medium mb-1" %>
    <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password", class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <%= form.submit "Redefinir senha", class: "bg-indigo-600 text-white rounded px-4 py-2 font-medium" %>
<% end %>
```

- [ ] **Step 7: Add routes**

Edit `config/routes.rb`, add right after the `rails_health_check` line:

```ruby
  resource :session
  resources :passwords, param: :token
```

- [ ] **Step 8: Add users fixture and sign_in_as test helper**

Create `test/fixtures/users.yml`:

```yaml
jane:
  name: Jane Doe
  email_address: jane@example.com
  password_digest: <%= BCrypt::Password.create("password") %>

john:
  name: John Smith
  email_address: john@example.com
  password_digest: <%= BCrypt::Password.create("password") %>
```

Edit `test/test_helper.rb`:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  def sign_in_as(user, password: "password")
    post session_url, params: { email_address: user.email_address, password: password }
  end
end
```

- [ ] **Step 9: Add "Sair" link to the navbar**

Edit `app/views/layouts/_navbar.html.erb`:

```erb
<nav class="bg-white border-b border-slate-200">
  <div class="container mx-auto px-5 py-4 flex gap-6 items-center">
    <%= link_to "Home", root_path, class: "font-medium hover:text-indigo-600" %>
    <%= link_to "Profile", profile_path, class: "font-medium hover:text-indigo-600" %>
    <%= link_to "Settings", edit_settings_path, class: "font-medium hover:text-indigo-600" %>
    <% if authenticated? %>
      <%= button_to "Sair", session_path, method: :delete, class: "font-medium hover:text-indigo-600 bg-transparent border-0 p-0 cursor-pointer ml-auto" %>
    <% end %>
  </div>
</nav>
```

Note: `edit_settings_path` will exist only after Task 6 adds the `resource :settings` route. This is fine — it will raise a `NameError` if hit before Task 6 runs, but no test exercises the navbar's settings link before then.

- [ ] **Step 10: Sign in inside the existing controller tests so they keep passing**

The `Authentication` concern now requires login on every action by default. Add a `setup` block that signs in to each existing controller test.

Edit `test/controllers/shifts_controller_test.rb`, change the setup block:

```ruby
  setup do
    sign_in_as users(:jane)
    @shift = shifts(:one)
  end
```

Edit `test/controllers/categories_controller_test.rb`, change the setup block:

```ruby
  setup do
    sign_in_as users(:jane)
    @category = categories(:hospital_x)
  end
```

Edit `test/controllers/calendar_controller_test.rb`, add a setup block right after the `class` line:

```ruby
class CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

```

Edit `test/controllers/pages_controller_test.rb`, add a setup block right after the `class` line:

```ruby
class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

```

- [ ] **Step 11: Write the failing test for SessionsController**

Create `test/controllers/sessions_controller_test.rb`:

```ruby
require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signs in with valid credentials" do
    post session_url, params: { email_address: users(:jane).email_address, password: "password" }
    assert_redirected_to root_url
    follow_redirect!
    assert_response :success
  end

  test "rejects invalid credentials" do
    post session_url, params: { email_address: users(:jane).email_address, password: "wrong" }
    assert_redirected_to new_session_url
  end

  test "signs out" do
    sign_in_as users(:jane)
    delete session_url
    assert_redirected_to new_session_url
  end

  test "redirects unauthenticated visitors to sign in" do
    get root_url
    assert_redirected_to new_session_url
  end
end
```

- [ ] **Step 12: Run the full test suite**

Run: `bin/rails test`
Expected: all tests pass (existing suite + the new `sessions_controller_test.rb`).

- [ ] **Step 13: Commit**

```bash
git add Gemfile Gemfile.lock config/application.rb config/routes.rb app/models/user.rb app/models/session.rb app/models/current.rb app/controllers/concerns/authentication.rb app/controllers/application_controller.rb app/controllers/sessions_controller.rb app/controllers/passwords_controller.rb app/mailers/ app/views/passwords_mailer/ app/views/sessions/ app/views/passwords/ app/views/layouts/_navbar.html.erb db/migrate/20260904000001_create_users.rb db/migrate/20260904000002_create_sessions.rb db/schema.rb test/test_helper.rb test/fixtures/users.yml test/controllers/sessions_controller_test.rb test/controllers/shifts_controller_test.rb test/controllers/categories_controller_test.rb test/controllers/calendar_controller_test.rb test/controllers/pages_controller_test.rb
git commit -m "Add Rails 8 authentication base (login, logout, password reset)"
```

---

## Task 2: Cadastro público (Registrations)

**Files:**
- Create: `app/controllers/registrations_controller.rb`
- Create: `app/views/registrations/new.html.erb`
- Modify: `config/routes.rb`
- Test: `test/controllers/registrations_controller_test.rb`

**Interfaces:**
- Consumes: `User` (Task 1), `start_new_session_for` / `after_authentication_url` / `allow_unauthenticated_access` (Task 1's `Authentication` concern).
- Produces: route helpers `new_registration_path`, `registrations_path` (already referenced from `sessions/new.html.erb` in Task 1).

- [ ] **Step 1: Write the failing test**

Create `test/controllers/registrations_controller_test.rb`:

```ruby
require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "creates an account and signs in" do
    assert_difference("User.count") do
      post registrations_url, params: { user: { name: "Nova Silva", email_address: "nova@example.com", password: "password", password_confirmation: "password" } }
    end

    assert_redirected_to root_url
  end

  test "does not create an account with a duplicate email" do
    assert_no_difference("User.count") do
      post registrations_url, params: { user: { name: "Dup", email_address: users(:jane).email_address, password: "password", password_confirmation: "password" } }
    end

    assert_response :unprocessable_entity
  end

  test "does not create an account with mismatched password confirmation" do
    assert_no_difference("User.count") do
      post registrations_url, params: { user: { name: "Dup", email_address: "dup2@example.com", password: "password", password_confirmation: "different" } }
    end

    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/registrations_controller_test.rb`
Expected: FAIL (route/controller missing).

- [ ] **Step 3: Add `password_confirmation` validation and the route**

Edit `app/models/user.rb`, add `validates :password, confirmation: true, allow_nil: true` right below the existing `validates` lines:

```ruby
  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :password, confirmation: true, allow_nil: true
```

Edit `config/routes.rb`, add right after the `resources :passwords, param: :token` line:

```ruby
  resources :registrations, only: %i[ new create ]
```

- [ ] **Step 4: Write RegistrationsController and its view**

Create `app/controllers/registrations_controller.rb`:

```ruby
class RegistrationsController < ApplicationController
  allow_unauthenticated_access

  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)

    if @user.save
      start_new_session_for @user
      redirect_to after_authentication_url
    else
      render :new, status: :unprocessable_entity
    end
  end

  private
    def registration_params
      params.require(:user).permit(:name, :email_address, :password, :password_confirmation)
    end
end
```

Create `app/views/registrations/new.html.erb`:

```erb
<% content_for :title, "Criar conta" %>

<h1 class="text-2xl font-semibold mb-4">Criar conta</h1>

<%= form_with model: @user, url: registrations_path, class: "space-y-4 max-w-sm" do |form| %>
  <% if @user.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% @user.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <div>
    <%= form.label :name, "Nome", class: "block text-sm font-medium mb-1" %>
    <%= form.text_field :name, required: true, autofocus: true, class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <div>
    <%= form.label :email_address, "Email", class: "block text-sm font-medium mb-1" %>
    <%= form.email_field :email_address, required: true, class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <div>
    <%= form.label :password, "Senha", class: "block text-sm font-medium mb-1" %>
    <%= form.password_field :password, required: true, autocomplete: "new-password", class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <div>
    <%= form.label :password_confirmation, "Confirmar senha", class: "block text-sm font-medium mb-1" %>
    <%= form.password_field :password_confirmation, required: true, autocomplete: "new-password", class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <%= form.submit "Criar conta", class: "bg-indigo-600 text-white rounded px-4 py-2 font-medium" %>
<% end %>
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bin/rails test test/controllers/registrations_controller_test.rb`
Expected: PASS

- [ ] **Step 6: Run the full suite**

Run: `bin/rails test`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add app/models/user.rb config/routes.rb app/controllers/registrations_controller.rb app/views/registrations/ test/controllers/registrations_controller_test.rb
git commit -m "Add public signup (RegistrationsController)"
```

---

## Task 3: Multiusuário — schema e models

**Files:**
- Create: `db/migrate/20260904000003_add_user_to_categories.rb`
- Create: `db/migrate/20260904000004_add_user_to_shifts.rb`
- Modify: `app/models/user.rb`
- Modify: `app/models/category.rb`
- Modify: `app/models/shift.rb`
- Modify: `test/fixtures/categories.yml`
- Modify: `test/fixtures/shifts.yml`
- Modify: `test/models/category_test.rb`
- Modify: `test/models/shift_test.rb`
- Modify: `test/controllers/calendar_controller_test.rb`
- Modify: `test/controllers/categories_controller_test.rb`

**Interfaces:**
- Consumes: `User` (Task 1).
- Produces: `Category#user`/`user_id`, `Shift#user`/`user_id`, `User#categories`, `User#shifts`.

- [ ] **Step 1: Write the migrations**

Create `db/migrate/20260904000003_add_user_to_categories.rb`:

```ruby
class AddUserToCategories < ActiveRecord::Migration[8.1]
  def change
    add_reference :categories, :user, null: false, foreign_key: true
  end
end
```

Create `db/migrate/20260904000004_add_user_to_shifts.rb`:

```ruby
class AddUserToShifts < ActiveRecord::Migration[8.1]
  def change
    add_reference :shifts, :user, null: false, foreign_key: true
  end
end
```

Run: `bin/rails db:migrate`
Expected: `categories` and `shifts` gain a `user_id` column, NOT NULL, indexed, FK to `users`.

- [ ] **Step 2: Update models**

Edit `app/models/user.rb`, add two lines to the `has_many :sessions` area:

```ruby
  has_many :sessions, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :shifts, dependent: :destroy
```

Edit `app/models/category.rb`, add `belongs_to :user` as the first line of the class body:

```ruby
class Category < ApplicationRecord
  belongs_to :user
  has_many :shifts, dependent: :nullify
```

Edit `app/models/shift.rb`, add `belongs_to :user` as the first line of the class body:

```ruby
class Shift < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true
```

- [ ] **Step 3: Update fixtures to reference a user**

Edit `test/fixtures/categories.yml`:

```yaml
hospital_x:
  user: jane
  name: Hospital X
  color: "#4f46e5"
  start_time: "07:00"
  end_time: "19:00"

posto_sul:
  user: jane
  name: Posto Sul
  color: "#16a34a"
  start_time: "13:00"
  end_time: "19:00"
```

Edit `test/fixtures/shifts.yml`:

```yaml
one:
  user: jane
  date: 2026-09-10
  start_time: "08:00"
  end_time: "14:00"
  location: Hospital Central
  notes: Plantão de rotina

two:
  user: jane
  date: 2026-09-12
  start_time: "20:00"
  end_time: "23:30"
```

- [ ] **Step 4: Update model tests to satisfy the required association**

Edit `test/models/category_test.rb` — every `Category.new(...)` call gains `user: users(:jane),` as the first keyword argument. Replace the whole file:

```ruby
require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "valid with name, color, start_time, end_time" do
    category = Category.new(user: users(:jane), name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: "19:00")
    assert category.valid?
  end

  test "invalid without user" do
    category = Category.new(user: nil, name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without name" do
    category = Category.new(user: users(:jane), name: nil, color: "#4f46e5", start_time: "07:00", end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without color" do
    category = Category.new(user: users(:jane), name: "Hospital X", color: nil, start_time: "07:00", end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without start_time" do
    category = Category.new(user: users(:jane), name: "Hospital X", color: "#4f46e5", start_time: nil, end_time: "19:00")
    assert_not category.valid?
  end

  test "invalid without end_time" do
    category = Category.new(user: users(:jane), name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: nil)
    assert_not category.valid?
  end

  test "invalid when end_time is before start_time" do
    category = Category.new(user: users(:jane), name: "Hospital X", color: "#4f46e5", start_time: "19:00", end_time: "07:00")
    assert_not category.valid?
    assert_includes category.errors[:end_time], "deve ser depois do horário de início"
  end

  test "invalid when end_time equals start_time" do
    category = Category.new(user: users(:jane), name: "Hospital X", color: "#4f46e5", start_time: "07:00", end_time: "07:00")
    assert_not category.valid?
  end
end
```

Edit `test/models/shift_test.rb` — every `Shift.new`/`Shift.create!` call gains `user: users(:jane),`. Replace the whole file:

```ruby
require "test_helper"

class ShiftTest < ActiveSupport::TestCase
  test "valid with date, start_time, end_time" do
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00")
    assert shift.valid?
  end

  test "invalid without user" do
    shift = Shift.new(user: nil, date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00")
    assert_not shift.valid?
  end

  test "invalid without date" do
    shift = Shift.new(user: users(:jane), date: nil, start_time: "08:00", end_time: "14:00")
    assert_not shift.valid?
  end

  test "invalid without start_time" do
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), start_time: nil, end_time: "14:00")
    assert_not shift.valid?
  end

  test "invalid without end_time" do
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), start_time: "08:00", end_time: nil)
    assert_not shift.valid?
  end

  test "invalid when end_time is before start_time" do
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), start_time: "14:00", end_time: "08:00")
    assert_not shift.valid?
    assert_includes shift.errors[:end_time], "deve ser depois do horário de início"
  end

  test "invalid when end_time equals start_time" do
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "08:00")
    assert_not shift.valid?
  end

  test "valid without location or notes" do
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00", location: nil, notes: nil)
    assert shift.valid?
  end

  test "valid with category and no explicit start_time/end_time" do
    category = categories(:hospital_x)
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), category: category)

    assert shift.valid?
    assert_equal category.start_time, shift.start_time
    assert_equal category.end_time, shift.end_time
  end

  test "keeps explicit start_time/end_time even with category set" do
    category = categories(:hospital_x)
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), start_time: "09:00", end_time: "10:00", category: category)

    assert shift.valid?
    assert_equal "09:00", shift.start_time.strftime("%H:%M")
    assert_equal "10:00", shift.end_time.strftime("%H:%M")
  end

  test "valid without category" do
    shift = Shift.new(user: users(:jane), date: Date.new(2026, 9, 10), start_time: "08:00", end_time: "14:00")
    assert shift.valid?
    assert_nil shift.category
  end

  test "destroying category nullifies associated shift" do
    category = categories(:hospital_x)
    shift = Shift.create!(user: users(:jane), date: Date.new(2026, 9, 10), category: category)

    category.destroy

    assert_nil shift.reload.category_id
  end
end
```

- [ ] **Step 5: Fix ad-hoc `Shift.create!` calls in controller tests**

Edit `test/controllers/categories_controller_test.rb`, in the `"destroying category nullifies..."` test:

```ruby
  test "destroying category nullifies associated shifts instead of blocking" do
    shift = Shift.create!(user: users(:jane), date: Date.new(2026, 9, 10), category: @category)

    delete category_url(@category)

    assert_nil shift.reload.category_id
  end
```

Edit `test/controllers/calendar_controller_test.rb`, add `user: users(:jane),` to every `Shift.create!` call. Replace the whole file:

```ruby
require "test_helper"

class CalendarControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

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
    Shift.create!(user: users(:jane), date: Date.new(2026, 9, 20), category: category)

    get calendar_url(month: "2026-09")

    assert_response :success
    assert_match category.color, response.body
  end

  test "should get day with existing shifts" do
    category = categories(:hospital_x)
    Shift.create!(user: users(:jane), date: Date.new(2026, 9, 20), category: category)

    get calendar_day_url(date: "2026-09-20")

    assert_response :success
    assert_match category.name, response.body
  end

  test "should get day without shifts" do
    get calendar_day_url(date: "2026-09-25")

    assert_response :success
    assert_match "Nenhum plantão", response.body
  end

  test "should show empty-category guidance instead of form when no categories exist" do
    Category.delete_all

    get calendar_day_url(date: "2026-09-25")

    assert_response :success
    assert_match "Cadastre uma categoria", response.body
  end

  test "should show a colored dot for a shift on a previous-month padding day" do
    category = categories(:hospital_x)
    Shift.create!(user: users(:jane), date: Date.new(2026, 8, 31), category: category)

    get calendar_url(month: "2026-09")

    assert_response :success
    assert_match category.color, response.body
  end
end
```

- [ ] **Step 6: Run the full suite**

Run: `bin/rails test`
Expected: all pass. (Categories/shifts controller tests still pass unscoped for now — scoping to `Current.user` happens in Task 4.)

- [ ] **Step 7: Commit**

```bash
git add db/migrate/20260904000003_add_user_to_categories.rb db/migrate/20260904000004_add_user_to_shifts.rb db/schema.rb app/models/user.rb app/models/category.rb app/models/shift.rb test/fixtures/categories.yml test/fixtures/shifts.yml test/models/category_test.rb test/models/shift_test.rb test/controllers/categories_controller_test.rb test/controllers/calendar_controller_test.rb
git commit -m "Make Shift and Category belong to a User"
```

---

## Task 4: Escopar controllers por Current.user

**Files:**
- Modify: `app/controllers/shifts_controller.rb`
- Modify: `app/controllers/categories_controller.rb`
- Modify: `app/controllers/calendar_controller.rb`
- Modify: `test/controllers/shifts_controller_test.rb`
- Modify: `test/controllers/categories_controller_test.rb`
- Modify: `test/controllers/calendar_controller_test.rb`

**Interfaces:**
- Consumes: `Current.user` (Task 1), `User#shifts`/`User#categories` (Task 3).
- Produces: nothing new — closes out the multiuser scoping.

- [ ] **Step 1: Write the failing cross-user tests**

Edit `test/controllers/shifts_controller_test.rb`, add at the end of the class (before the final `end`):

```ruby

  test "cannot edit another user's shift" do
    other_shift = Shift.create!(user: users(:john), date: Date.new(2026, 9, 30), start_time: "08:00", end_time: "12:00")

    get edit_shift_url(other_shift)

    assert_response :not_found
  end

  test "cannot destroy another user's shift" do
    other_shift = Shift.create!(user: users(:john), date: Date.new(2026, 9, 30), start_time: "08:00", end_time: "12:00")

    assert_no_difference("Shift.count") do
      assert_raises(ActiveRecord::RecordNotFound) { delete shift_url(other_shift) }
    end
  end

  test "created shift belongs to the signed-in user" do
    post shifts_url, params: { shift: { date: "2026-09-15", start_time: "09:00", end_time: "17:00" } }
    assert_equal users(:jane), Shift.last.user
  end
```

Edit `test/controllers/categories_controller_test.rb`, add at the end of the class (before the final `end`):

```ruby

  test "cannot edit another user's category" do
    other_category = Category.create!(user: users(:john), name: "Clínica Y", color: "#000000", start_time: "08:00", end_time: "16:00")

    get edit_category_url(other_category)

    assert_response :not_found
  end

  test "created category belongs to the signed-in user" do
    post categories_url, params: { category: { name: "Hospital Y", color: "#f97316", start_time: "08:00", end_time: "20:00" } }
    assert_equal users(:jane), Category.last.user
  end
```

Edit `test/controllers/calendar_controller_test.rb`, add at the end of the class (before the final `end`):

```ruby

  test "does not show another user's shift on the calendar" do
    Shift.create!(user: users(:john), date: Date.new(2026, 9, 20), start_time: "08:00", end_time: "12:00", location: "Clínica de John")

    get calendar_day_url(date: "2026-09-20")

    assert_response :success
    assert_no_match "Clínica de John", response.body
  end
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bin/rails test test/controllers/shifts_controller_test.rb test/controllers/categories_controller_test.rb test/controllers/calendar_controller_test.rb`
Expected: the 5 new tests FAIL (controllers still query unscoped, so John's records are reachable/visible).

- [ ] **Step 3: Scope ShiftsController**

Edit `app/controllers/shifts_controller.rb`, replace the whole file:

```ruby
class ShiftsController < ApplicationController
  before_action :set_shift, only: [:edit, :update, :destroy]

  def index
    @shifts = Current.user.shifts.order(:date, :start_time).includes(:category)
  end

  def new
    @shift = Current.user.shifts.new
    @categories = Current.user.categories.order(:name)
  end

  def create
    @shift = Current.user.shifts.new(shift_params)

    if @shift.save
      redirect_to destination_after_save, notice: "Plantão criado."
    else
      @categories = Current.user.categories.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @categories = Current.user.categories.order(:name)
  end

  def update
    if @shift.update(shift_params)
      redirect_to destination_after_save, notice: "Plantão atualizado."
    else
      @categories = Current.user.categories.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shift.destroy
    redirect_to destination_after_save, notice: "Plantão removido."
  end

  private

  def set_shift
    @shift = Current.user.shifts.find(params[:id])
  end

  def shift_params
    params.require(:shift).permit(:date, :start_time, :end_time, :location, :notes, :category_id)
  end

  def destination_after_save
    return_to = params[:return_to]
    return_to.present? && return_to.start_with?("/") && !return_to.start_with?("//") ? return_to : root_path
  end
end
```

- [ ] **Step 4: Scope CategoriesController**

Edit `app/controllers/categories_controller.rb`, replace the whole file:

```ruby
class CategoriesController < ApplicationController
  before_action :set_category, only: [:edit, :update, :destroy]

  def index
    @categories = Current.user.categories.order(:name)
  end

  def new
    @category = Current.user.categories.new
  end

  def create
    @category = Current.user.categories.new(category_params)

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
    @category = Current.user.categories.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :color, :start_time, :end_time)
  end
end
```

- [ ] **Step 5: Scope CalendarController**

Edit `app/controllers/calendar_controller.rb`, replace the whole file:

```ruby
class CalendarController < ApplicationController
  def show
    @month = month_param
    @weeks = weeks_of_month(@month)
    @colors_by_day = colors_by_day(@weeks)
  end

  def day
    @date = Date.parse(params[:date])
    @shifts = Current.user.shifts.where(date: @date).includes(:category).order(:start_time)
    @categories = Current.user.categories.order(:name)
  rescue Date::Error, ArgumentError, TypeError
    redirect_to calendar_path
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

  def colors_by_day(weeks)
    Current.user.shifts.where(date: weeks.first.first..weeks.last.last)
         .includes(:category)
         .group_by(&:date)
         .transform_values do |shifts|
           shifts.uniq { |s| s.category_id }.map { |s| s.category&.color || "#94a3b8" }
         end
  end
end
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `bin/rails test test/controllers/shifts_controller_test.rb test/controllers/categories_controller_test.rb test/controllers/calendar_controller_test.rb`
Expected: PASS.

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add app/controllers/shifts_controller.rb app/controllers/categories_controller.rb app/controllers/calendar_controller.rb test/controllers/shifts_controller_test.rb test/controllers/categories_controller_test.rb test/controllers/calendar_controller_test.rb
git commit -m "Scope shifts, categories, and calendar to the signed-in user"
```

---

## Task 5: Login com Apple (OAuth)

**Files:**
- Modify: `Gemfile`
- Create: `db/migrate/20260904000005_add_provider_uid_to_users.rb`
- Modify: `app/models/user.rb`
- Create: `config/initializers/omniauth.rb`
- Create: `app/controllers/omniauth_controller.rb`
- Modify: `config/routes.rb`
- Modify: `config/ruby_native.yml`
- Modify: `app/views/sessions/new.html.erb`
- Modify: `test/test_helper.rb`
- Test: `test/controllers/omniauth_controller_test.rb`

**Interfaces:**
- Consumes: `User`, `start_new_session_for`, `after_authentication_url`, `allow_unauthenticated_access` (Task 1).
- Produces: `User#provider`/`User#uid`. Route `/auth/apple/callback` -> `OmniauthController#apple`, `/auth/failure` -> `OmniauthController#failure`.

- [ ] **Step 1: Add gems**

Edit `Gemfile`, add after the `ruby_native` line:

```ruby
gem "omniauth", "~> 2.1"
gem "omniauth-apple", "~> 1.2"
gem "omniauth-rails_csrf_protection", "~> 1.0"
```

Run: `bundle install`

- [ ] **Step 2: Migration for provider/uid**

Create `db/migrate/20260904000005_add_provider_uid_to_users.rb`:

```ruby
class AddProviderUidToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :provider, :string
    add_column :users, :uid, :string
    add_index :users, [:provider, :uid], unique: true
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 3: Write the failing test**

Create `test/controllers/omniauth_controller_test.rb`:

```ruby
require "test_helper"

class OmniauthControllerTest < ActionDispatch::IntegrationTest
  test "creates a new user and session from Apple auth" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.1234",
      info: { email: "new.apple.user@example.com", name: "Apple User" }
    )

    assert_difference("User.count") do
      get "/auth/apple/callback"
    end

    user = User.find_by(email_address: "new.apple.user@example.com")
    assert_equal "apple", user.provider
    assert_equal "001999.abcdef.1234", user.uid
    assert_redirected_to root_url
  end

  test "links an existing email/password account by email on first Apple sign-in" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.5678",
      info: { email: users(:jane).email_address, name: "Jane Doe" }
    )

    assert_no_difference("User.count") do
      get "/auth/apple/callback"
    end

    assert_equal "apple", users(:jane).reload.provider
  end

  test "reuses the same user on a repeat Apple sign-in" do
    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.1234",
      info: { email: "repeat@example.com", name: "Repeat User" }
    )
    get "/auth/apple/callback"

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      provider: "apple",
      uid: "001999.abcdef.1234",
      info: {}
    )
    assert_no_difference("User.count") do
      get "/auth/apple/callback"
    end
  end
end
```

- [ ] **Step 4: Run it to verify it fails**

Run: `bin/rails test test/controllers/omniauth_controller_test.rb`
Expected: FAIL (`OmniAuth` not configured / route missing / `mock_auth` unset).

- [ ] **Step 5: Add provider/uid to the User model**

Edit `app/models/user.rb`, no structural change needed beyond what Task 1/2 already added — `provider`/`uid` are plain columns, no validation required (nullable, only enforced unique together at the DB level). Confirm the file currently reads:

```ruby
class User < ApplicationRecord
  has_secure_password
  generates_token_for :password_reset, expires_in: 15.minutes do
    password_salt&.last(10)
  end

  has_many :sessions, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :shifts, dependent: :destroy

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :password, confirmation: true, allow_nil: true

  private
    def password_salt
      password_digest
    end
end
```

No edit needed if it already matches — this step just confirms no drift before wiring OmniAuth to it.

- [ ] **Step 6: Write the OmniAuth initializer**

Create `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :apple,
    Rails.application.credentials.dig(:apple, :client_id),
    "",
    {
      scope: "email name",
      team_id: Rails.application.credentials.dig(:apple, :team_id),
      key_id: Rails.application.credentials.dig(:apple, :key_id),
      pem: Rails.application.credentials.dig(:apple, :private_key)
    }
end

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true
OmniAuth.config.on_failure = proc { |env| OmniauthController.action(:failure).call(env) }
```

Note (manual, external step — not code): run `bin/rails credentials:edit` and add:

```yaml
apple:
  client_id: com.example.app.web   # your Services ID from Apple Developer
  team_id: ABCD123456
  key_id: XXXXXXXXXX
  private_key: |
    -----BEGIN PRIVATE KEY-----
    ...
    -----END PRIVATE KEY-----
```

Tests don't need real credentials — `OmniAuth.config.test_mode` bypasses the strategy entirely.

- [ ] **Step 7: Write OmniauthController**

Create `app/controllers/omniauth_controller.rb`:

```ruby
class OmniauthController < ApplicationController
  allow_unauthenticated_access only: %i[ apple failure ]

  def apple
    auth = request.env["omniauth.auth"]

    user = User.find_by(provider: auth.provider, uid: auth.uid)
    user ||= find_and_link_by_email(auth)
    user ||= create_from_apple(auth)

    start_new_session_for user
    redirect_to after_authentication_url
  end

  def failure
    redirect_to new_session_path, alert: "Não foi possível autenticar com Apple."
  end

  private
    def find_and_link_by_email(auth)
      return nil if auth.info.email.blank?

      user = User.find_by(email_address: auth.info.email)
      user&.update!(provider: auth.provider, uid: auth.uid)
      user
    end

    def create_from_apple(auth)
      User.create!(
        name: auth.info.name.presence || auth.info.email,
        email_address: auth.info.email,
        password_digest: BCrypt::Password.create(SecureRandom.hex(20)),
        provider: auth.provider,
        uid: auth.uid
      )
    end
end
```

- [ ] **Step 8: Add routes**

Edit `config/routes.rb`, add right after the `resources :registrations` line:

```ruby
  get "/auth/apple/callback", to: "omniauth#apple"
  get "/auth/failure", to: "omniauth#failure"
```

- [ ] **Step 9: Wire ruby_native.yml**

Edit `config/ruby_native.yml`, replace the commented-out `auth:` block near the bottom with an active one:

```yaml
# Enable OAuth. Each path triggers a native ASWebAuthenticationSession
# on iOS instead of an in-app web view. List only the authorize path for each
# provider, not its callback; the callback is handled automatically.
# https://rubynative.com/docs/oauth
auth:
  oauth_paths:
    - /auth/apple
```

- [ ] **Step 10: Add the "Entrar com Apple" button**

Edit `app/views/sessions/new.html.erb`, add right after the closing `<% end %>` of the form:

```erb
<%= button_to "Entrar com Apple", "/auth/apple", data: { turbo: false }, class: "mt-4 bg-black text-white rounded px-4 py-2 font-medium" %>
```

- [ ] **Step 11: Enable OmniAuth test mode**

Edit `test/test_helper.rb`, add `OmniAuth.config.test_mode = true` right after `require "rails/test_help"`:

```ruby
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

OmniAuth.config.test_mode = true

module ActiveSupport
```

- [ ] **Step 12: Run the test to verify it passes**

Run: `bin/rails test test/controllers/omniauth_controller_test.rb`
Expected: PASS.

- [ ] **Step 13: Run the full suite**

Run: `bin/rails test`
Expected: all pass.

- [ ] **Step 14: Commit**

```bash
git add Gemfile Gemfile.lock db/migrate/20260904000005_add_provider_uid_to_users.rb db/schema.rb app/models/user.rb config/initializers/omniauth.rb app/controllers/omniauth_controller.rb config/routes.rb config/ruby_native.yml app/views/sessions/new.html.erb test/test_helper.rb test/controllers/omniauth_controller_test.rb
git commit -m "Add Sign in with Apple via OmniAuth"
```

---

## Task 6: Settings (nome, email, senha)

**Files:**
- Create: `app/controllers/settings_controller.rb`
- Create: `app/views/settings/edit.html.erb`
- Modify: `config/routes.rb`
- Delete: `app/views/pages/settings.html.erb`
- Modify: `app/controllers/pages_controller.rb`
- Modify: `test/controllers/pages_controller_test.rb`
- Test: `test/controllers/settings_controller_test.rb`

**Interfaces:**
- Consumes: `Current.user` (Task 1).
- Produces: route helpers `edit_settings_path`, `settings_path` (already referenced from the navbar in Task 1).

- [ ] **Step 1: Write the failing test**

Create `test/controllers/settings_controller_test.rb`:

```ruby
require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get edit" do
    get edit_settings_url
    assert_response :success
  end

  test "updates name and email" do
    patch settings_url, params: { user: { name: "Jane Updated", email_address: "jane.updated@example.com" } }
    assert_redirected_to edit_settings_url
    assert_equal "Jane Updated", users(:jane).reload.name
    assert_equal "jane.updated@example.com", users(:jane).reload.email_address
  end

  test "updates password when current password is correct" do
    patch settings_url, params: { user: { current_password: "password", password: "newpassword", password_confirmation: "newpassword" } }
    assert_redirected_to edit_settings_url
    assert users(:jane).reload.authenticate("newpassword")
  end

  test "rejects password change when current password is wrong" do
    patch settings_url, params: { user: { current_password: "wrong", password: "newpassword", password_confirmation: "newpassword" } }
    assert_response :unprocessable_entity
    assert_not users(:jane).reload.authenticate("newpassword")
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/settings_controller_test.rb`
Expected: FAIL (route/controller missing).

- [ ] **Step 3: Replace the settings route and delete the old static page**

Edit `config/routes.rb`, remove the line `get "settings" => "pages#settings"` and add in its place:

```ruby
  resource :settings, only: %i[ edit update ]
```

Delete `app/views/pages/settings.html.erb` (its content moves to `app/views/settings/edit.html.erb`).

Edit `app/controllers/pages_controller.rb`, remove the `settings` action — replace the whole file:

```ruby
class PagesController < ApplicationController
  def profile
  end
end
```

Edit `test/controllers/pages_controller_test.rb`, remove the `"should get settings"` test — replace the whole file:

```ruby
require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get profile" do
    get profile_url
    assert_response :success
  end
end
```

- [ ] **Step 4: Write SettingsController**

Create `app/controllers/settings_controller.rb`:

```ruby
class SettingsController < ApplicationController
  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    if password_change_requested? && !@user.authenticate(settings_params[:current_password])
      @user.errors.add(:current_password, "está incorreta")
      render :edit, status: :unprocessable_entity
      return
    end

    if @user.update(update_params)
      redirect_to edit_settings_path, notice: "Configurações atualizadas."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private
    def settings_params
      params.require(:user).permit(:name, :email_address, :current_password, :password, :password_confirmation)
    end

    def password_change_requested?
      settings_params[:password].present?
    end

    def update_params
      attrs = settings_params.except(:current_password)
      attrs = attrs.except(:password, :password_confirmation) unless password_change_requested?
      attrs
    end
end
```

- [ ] **Step 5: Write the Settings view**

Create `app/views/settings/edit.html.erb`:

```erb
<% content_for :title, "Settings" %>

<h1 class="text-2xl font-semibold mb-4">Settings</h1>

<%= form_with model: @user, url: settings_path, method: :patch, class: "space-y-4 max-w-sm" do |form| %>
  <% if @user.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% @user.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <div>
    <%= form.label :name, "Nome", class: "block text-sm font-medium mb-1" %>
    <%= form.text_field :name, class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <div>
    <%= form.label :email_address, "Email", class: "block text-sm font-medium mb-1" %>
    <%= form.email_field :email_address, class: "w-full border border-slate-300 rounded px-3 py-2" %>
  </div>

  <fieldset class="border-t border-slate-200 pt-4">
    <legend class="text-sm font-medium mb-2">Trocar senha (opcional)</legend>

    <div class="mb-3">
      <%= form.label :current_password, "Senha atual", class: "block text-sm font-medium mb-1" %>
      <%= form.password_field :current_password, autocomplete: "current-password", class: "w-full border border-slate-300 rounded px-3 py-2" %>
    </div>

    <div class="mb-3">
      <%= form.label :password, "Nova senha", class: "block text-sm font-medium mb-1" %>
      <%= form.password_field :password, autocomplete: "new-password", class: "w-full border border-slate-300 rounded px-3 py-2" %>
    </div>

    <div>
      <%= form.label :password_confirmation, "Confirmar nova senha", class: "block text-sm font-medium mb-1" %>
      <%= form.password_field :password_confirmation, autocomplete: "new-password", class: "w-full border border-slate-300 rounded px-3 py-2" %>
    </div>
  </fieldset>

  <%= form.submit "Salvar", class: "bg-indigo-600 text-white rounded px-4 py-2 font-medium" %>
<% end %>
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `bin/rails test test/controllers/settings_controller_test.rb`
Expected: PASS.

- [ ] **Step 7: Run the full suite**

Run: `bin/rails test`
Expected: all pass.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/pages_controller.rb app/controllers/settings_controller.rb app/views/settings/ test/controllers/pages_controller_test.rb test/controllers/settings_controller_test.rb
git rm app/views/pages/settings.html.erb
git commit -m "Add functional Settings page (name, email, password)"
```

---

## Task 7: Avatar (Active Storage)

**Files:**
- Modify: `Gemfile`
- Modify: `config/application.rb`
- Create: `config/storage.yml`
- Modify: `config/environments/development.rb`
- Modify: `config/environments/test.rb`
- Modify: `config/environments/production.rb`
- Modify: `app/models/user.rb`
- Modify: `app/controllers/settings_controller.rb`
- Modify: `app/views/settings/edit.html.erb`
- Test: `test/controllers/settings_controller_test.rb` (append)

**Interfaces:**
- Consumes: `SettingsController` (Task 6).
- Produces: `User#avatar` (Active Storage attachment).

- [ ] **Step 1: Enable Active Storage and add image_processing**

Edit `Gemfile`, add after the `bcrypt` line:

```ruby
gem "image_processing", "~> 1.2"
```

Edit `config/application.rb`, uncomment:

```ruby
require "active_storage/engine"
```

Run: `bundle install`

- [ ] **Step 2: Install Active Storage tables**

Run: `bin/rails active_storage:install`
Expected: creates `db/migrate/*_create_active_storage_tables.active_storage.rb`.

Run: `bin/rails db:migrate`

- [ ] **Step 3: Configure the local storage service**

Create `config/storage.yml`:

```yaml
test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

Edit `config/environments/development.rb`, add right after `config.enable_reloading = true`:

```ruby
  config.active_storage.service = :local
```

Edit `config/environments/test.rb`, add right after `config.cache_store = :null_store`:

```ruby
  config.active_storage.service = :test
```

Edit `config/environments/production.rb` — check its current content first with `grep -n "active_storage\|Settings specified" config/environments/production.rb`, then add right after the `Rails.application.configure do` line:

```ruby
  config.active_storage.service = :local
```

(Local disk storage in production is a known limitation for a real deploy — moving to cloud storage, e.g. S3, is a follow-up outside this plan's scope.)

- [ ] **Step 4: Attach avatar to User**

Edit `app/models/user.rb`, add `has_one_attached :avatar` right below `has_many :shifts, dependent: :destroy`:

```ruby
  has_many :sessions, dependent: :destroy
  has_many :categories, dependent: :destroy
  has_many :shifts, dependent: :destroy
  has_one_attached :avatar
```

- [ ] **Step 5: Write the failing test**

Edit `test/controllers/settings_controller_test.rb`, add at the end of the class (before the final `end`):

```ruby

  test "updates avatar" do
    file = fixture_file_upload("avatar.png", "image/png")

    patch settings_url, params: { user: { avatar: file } }

    assert_redirected_to edit_settings_url
    assert users(:jane).reload.avatar.attached?
  end
```

Create a tiny 1x1 PNG test fixture. Run this shell command to generate it:

```bash
mkdir -p test/fixtures/files
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\x00\x01\x00\x00\x05\x00\x01\r\n-\xb4\x00\x00\x00\x00IEND\xaeB`\x82' > test/fixtures/files/avatar.png
```

- [ ] **Step 6: Run it to verify it fails**

Run: `bin/rails test test/controllers/settings_controller_test.rb`
Expected: FAIL on `assert users(:jane).reload.avatar.attached?` — `settings_params` doesn't list `:avatar` yet, so `permit` silently drops it and nothing gets attached.

- [ ] **Step 7: Permit and persist avatar**

Edit `app/controllers/settings_controller.rb`, change `settings_params` to also permit `:avatar`:

```ruby
    def settings_params
      params.require(:user).permit(:name, :email_address, :current_password, :password, :password_confirmation, :avatar)
    end
```

`update_params` already forwards everything except `current_password` (and password fields when unchanged), so `:avatar` flows through automatically — no other change needed in `update_params`.

- [ ] **Step 8: Add the avatar field to the Settings view**

Edit `app/views/settings/edit.html.erb`, add right after the closing `</div>` of the email field block:

```erb
  <div>
    <%= form.label :avatar, "Foto de perfil", class: "block text-sm font-medium mb-1" %>
    <% if @user.avatar.attached? %>
      <%= image_tag @user.avatar, class: "w-16 h-16 rounded-full object-cover mb-2" %>
    <% end %>
    <%= form.file_field :avatar, accept: "image/*", class: "w-full" %>
  </div>
```

Change the `form_with` line to accept file uploads:

```erb
<%= form_with model: @user, url: settings_path, method: :patch, multipart: true, class: "space-y-4 max-w-sm" do |form| %>
```

- [ ] **Step 9: Run the test to verify it passes**

Run: `bin/rails test test/controllers/settings_controller_test.rb`
Expected: PASS.

- [ ] **Step 10: Run the full suite**

Run: `bin/rails test`
Expected: all pass.

- [ ] **Step 11: Commit**

```bash
git add Gemfile Gemfile.lock config/application.rb config/storage.yml config/environments/development.rb config/environments/test.rb config/environments/production.rb db/migrate/*create_active_storage_tables* db/schema.rb app/models/user.rb app/controllers/settings_controller.rb app/views/settings/edit.html.erb test/controllers/settings_controller_test.rb test/fixtures/files/avatar.png
git commit -m "Add avatar upload to Settings via Active Storage"
```

---

## Task 8: Profile mostra dados reais

**Files:**
- Modify: `app/views/pages/profile.html.erb`
- Modify: `test/controllers/pages_controller_test.rb`

**Interfaces:**
- Consumes: `Current.user` (Task 1), `User#avatar` (Task 7).
- Produces: nothing further downstream.

- [ ] **Step 1: Write the failing test**

Edit `test/controllers/pages_controller_test.rb`, replace the whole file:

```ruby
require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:jane)
  end

  test "should get profile" do
    get profile_url
    assert_response :success
  end

  test "profile shows the signed-in user's name and email" do
    get profile_url
    assert_match users(:jane).name, response.body
    assert_match users(:jane).email_address, response.body
  end
end
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bin/rails test test/controllers/pages_controller_test.rb`
Expected: FAIL (the second test — placeholder view doesn't show name/email).

- [ ] **Step 3: Update the Profile view**

Edit `app/views/pages/profile.html.erb`, replace the whole file:

```erb
<% content_for :title, "Profile" %>

<h1 class="text-2xl font-semibold mb-4">Profile</h1>

<% if Current.user.avatar.attached? %>
  <%= image_tag Current.user.avatar, class: "w-20 h-20 rounded-full object-cover mb-4" %>
<% end %>

<p class="text-slate-900 font-medium"><%= Current.user.name %></p>
<p class="text-slate-600"><%= Current.user.email_address %></p>

<%= link_to "Editar em Settings", edit_settings_path, class: "inline-block mt-4 text-indigo-600 font-medium hover:underline" %>
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bin/rails test test/controllers/pages_controller_test.rb`
Expected: PASS.

- [ ] **Step 5: Run the full suite**

Run: `bin/rails test`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add app/views/pages/profile.html.erb test/controllers/pages_controller_test.rb
git commit -m "Show real user data on the Profile page"
```

---

## Final check

- [ ] Run `bin/rails test` one more time end to end — expected: all green.
- [ ] Manually verify (per `superpowers:verification-before-completion`) by starting the server (`bin/rails server`) and walking: signup -> redirected & logged in -> create a category -> create a shift -> see it on `/calendar` -> log out -> log back in with email/password -> visit `/settings`, change name and upload an avatar -> visit `/profile`, see the new name and avatar -> log out -> back on `/session/new`, click "Entrar com Apple" (will fail without real Apple credentials configured — expected until `bin/rails credentials:edit` is filled in per Task 5 Step 6's note).
