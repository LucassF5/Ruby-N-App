# Posts CRUD, Profile, Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete Post CRUD (show/edit/update), add scheduling + privacy to posts, build a real singleton Profile page (avatar, description, post count), and a real singleton Settings page that controls pagination, default status filter, and private-post visibility on the home feed.

**Architecture:** Rails 8.1 app, SQLite, Minitest + fixtures, Tailwind (no JS framework). `Profile` and `Setting` are singleton ActiveRecord models (`.instance` → `first_or_create!`) since the app has no auth/users. Visibility of scheduled/private posts is resolved through `Post.visible`/`Post.for_status` scopes read by `PostsController#index`; every other action (`show`, `edit`, `update`, `destroy`) works on any post directly by id, so nothing already created ever becomes permanently unreachable.

**Tech Stack:** Rails 8.1, SQLite3, Active Storage (local disk, being enabled — currently commented out), Minitest, Tailwind CSS (`tailwindcss-rails`), Turbo (via Rails UJS defaults / `button_to` + `turbo_confirm`).

**Spec:** `docs/superpowers/specs/2026-08-18-posts-profile-settings-design.md`

## Global Constraints

- No multi-user auth — `Profile` and `Setting` are single-row singletons (`first_or_create!`), never scoped to a user.
- Scheduling (`scheduled_at` in the future) always hides a post from the **default** home view, no override — this is a hard gate.
- Privacy (`private: true`) hides a post from the **default** home view unless `Setting#show_private_posts` is true.
- Explicitly requesting `status=scheduled`, `status=private`, or `status=all` on the home feed always bypasses the gates above (see spec's "Visibility rule" section) — this is intentional, not a bug to fix later.
- No Kaminari/pagy — pagination is manual `limit`/`offset`.
- No `image_processing` gem / Active Storage variants — avatar renders at natural size, constrained by CSS only.
- Follow existing Minitest + fixtures conventions already in `test/`.

---

## Task 1: Post scheduling + privacy columns, status, and time-based scopes

**Files:**
- Create: `db/migrate/<timestamp>_add_scheduling_and_privacy_to_posts.rb`
- Modify: `app/models/post.rb`
- Test: `test/models/post_test.rb`

**Interfaces:**
- Produces: `Post#status` (returns `"scheduled"`, `"private"`, or `"published"`), `Post.scheduled_future` scope, `Post.not_scheduled_future` scope, `posts.private` column (boolean, default `false`), `posts.scheduled_at` column (datetime, nullable).

- [ ] **Step 1: Write the failing tests**

Append to `test/models/post_test.rb` (inside the `PostTest` class, after the existing tests):

```ruby
  test "status is published by default" do
    post = Post.new(title: "T", body: "B")
    assert_equal "published", post.status
  end

  test "status is scheduled when scheduled_at is in the future" do
    post = Post.new(title: "T", body: "B", scheduled_at: 1.day.from_now)
    assert_equal "scheduled", post.status
  end

  test "status is published when scheduled_at is in the past" do
    post = Post.new(title: "T", body: "B", scheduled_at: 1.day.ago)
    assert_equal "published", post.status
  end

  test "status is private when private flag is true" do
    post = Post.new(title: "T", body: "B", private: true)
    assert_equal "private", post.status
  end

  test "status is scheduled when both private and scheduled in the future" do
    post = Post.new(title: "T", body: "B", private: true, scheduled_at: 1.day.from_now)
    assert_equal "scheduled", post.status
  end

  test "not_scheduled_future excludes future scheduled posts" do
    future = Post.create!(title: "Future", body: "B", scheduled_at: 1.day.from_now)
    past = Post.create!(title: "Past", body: "B", scheduled_at: 1.day.ago)
    no_schedule = Post.create!(title: "None", body: "B")

    result = Post.not_scheduled_future
    assert_includes result, past
    assert_includes result, no_schedule
    assert_not_includes result, future
  end

  test "scheduled_future returns only future scheduled posts" do
    future = Post.create!(title: "Future", body: "B", scheduled_at: 1.day.from_now)
    past = Post.create!(title: "Past", body: "B", scheduled_at: 1.day.ago)

    result = Post.scheduled_future
    assert_includes result, future
    assert_not_includes result, past
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/post_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'status'` (and `private=`/`scheduled_at=` undefined attribute errors) since the columns and method don't exist yet.

- [ ] **Step 3: Generate and write the migration**

Run: `bin/rails generate migration AddSchedulingAndPrivacyToPosts`

Edit the generated file (`db/migrate/<timestamp>_add_scheduling_and_privacy_to_posts.rb`):

```ruby
class AddSchedulingAndPrivacyToPosts < ActiveRecord::Migration[8.1]
  def change
    add_column :posts, :private, :boolean, default: false, null: false
    add_column :posts, :scheduled_at, :datetime
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 4: Implement `Post#status` and time scopes**

Replace `app/models/post.rb`:

```ruby
class Post < ApplicationRecord
  validates :title, presence: true
  validates :body, presence: true

  scope :not_scheduled_future, -> { where("scheduled_at IS NULL OR scheduled_at <= ?", Time.current) }
  scope :scheduled_future, -> { where("scheduled_at > ?", Time.current) }

  def status
    if scheduled_at.present? && scheduled_at > Time.current
      "scheduled"
    elsif private?
      "private"
    else
      "published"
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/post_test.rb`
Expected: PASS, all tests green.

- [ ] **Step 6: Commit**

```bash
git add db/migrate app/models/post.rb test/models/post_test.rb db/schema.rb
git commit -m "feat: add scheduling and privacy to posts"
```

---

## Task 2: `Setting` singleton model

**Files:**
- Create: `db/migrate/<timestamp>_create_settings.rb`
- Create: `app/models/setting.rb`
- Test: `test/models/setting_test.rb`

**Interfaces:**
- Produces: `Setting.instance` (class method, `first_or_create!`, always returns the one row), `Setting::STATUS_FILTERS` (`%w[published scheduled private all]`), columns `posts_per_page` (integer, default 10), `default_status_filter` (string, default `"published"`), `show_private_posts` (boolean, default `false`), `filter_from_date` (date, nullable), `filter_to_date` (date, nullable).

- [ ] **Step 1: Write the failing tests**

Create `test/models/setting_test.rb`:

```ruby
require "test_helper"

class SettingTest < ActiveSupport::TestCase
  test "instance creates a record with defaults" do
    setting = Setting.instance
    assert_equal 10, setting.posts_per_page
    assert_equal "published", setting.default_status_filter
    assert_equal false, setting.show_private_posts
  end

  test "instance returns the same record on repeated calls" do
    first = Setting.instance
    second = Setting.instance
    assert_equal first.id, second.id
  end

  test "invalid with unknown default_status_filter" do
    setting = Setting.instance
    setting.default_status_filter = "bogus"
    assert_not setting.valid?
  end

  test "invalid with posts_per_page less than 1" do
    setting = Setting.instance
    setting.posts_per_page = 0
    assert_not setting.valid?
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/setting_test.rb`
Expected: FAIL — `NameError: uninitialized constant Setting` (table/model don't exist yet).

- [ ] **Step 3: Generate and write the migration**

Run: `bin/rails generate migration CreateSettings`

Edit the generated file:

```ruby
class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.integer :posts_per_page, default: 10, null: false
      t.string :default_status_filter, default: "published", null: false
      t.boolean :show_private_posts, default: false, null: false
      t.date :filter_from_date
      t.date :filter_to_date

      t.timestamps
    end
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 4: Implement `Setting`**

Create `app/models/setting.rb`:

```ruby
class Setting < ApplicationRecord
  STATUS_FILTERS = %w[published scheduled private all].freeze

  validates :posts_per_page, numericality: { greater_than: 0 }
  validates :default_status_filter, inclusion: { in: STATUS_FILTERS }

  def self.instance
    first_or_create!
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/setting_test.rb`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add db/migrate app/models/setting.rb test/models/setting_test.rb db/schema.rb
git commit -m "feat: add Setting singleton model"
```

---

## Task 3: `Post.visible` / `Post.for_status` — the visibility rule

**Files:**
- Modify: `app/models/post.rb`
- Test: `test/models/post_test.rb`

**Interfaces:**
- Consumes: `Setting.instance`, `Setting#show_private_posts` (from Task 2); `Post.not_scheduled_future`, `Post.scheduled_future` (from Task 1).
- Produces: `Post.visible(setting = Setting.instance)`, `Post.for_status(status, setting = Setting.instance)` — used by `PostsController#index` in Task 5.

- [ ] **Step 1: Write the failing tests**

Append to `test/models/post_test.rb`:

```ruby
  test "visible excludes future scheduled posts regardless of settings" do
    setting = Setting.instance
    future = Post.create!(title: "Future", body: "B", scheduled_at: 1.day.from_now)

    assert_not_includes Post.visible(setting), future
  end

  test "visible excludes private posts when show_private_posts is false" do
    setting = Setting.instance
    setting.update!(show_private_posts: false)
    priv = Post.create!(title: "Priv", body: "B", private: true)

    assert_not_includes Post.visible(setting), priv
  end

  test "visible includes private posts when show_private_posts is true" do
    setting = Setting.instance
    setting.update!(show_private_posts: true)
    priv = Post.create!(title: "Priv", body: "B", private: true)

    assert_includes Post.visible(setting), priv
  end

  test "for_status scheduled returns future scheduled posts even though visible hides them" do
    setting = Setting.instance
    future = Post.create!(title: "Future", body: "B", scheduled_at: 1.day.from_now)

    assert_includes Post.for_status("scheduled", setting), future
  end

  test "for_status private returns private posts regardless of show_private_posts" do
    setting = Setting.instance
    setting.update!(show_private_posts: false)
    priv = Post.create!(title: "Priv", body: "B", private: true)

    assert_includes Post.for_status("private", setting), priv
  end

  test "for_status all returns every post" do
    setting = Setting.instance
    future = Post.create!(title: "Future", body: "B", scheduled_at: 1.day.from_now)
    priv = Post.create!(title: "Priv", body: "B", private: true)

    result = Post.for_status("all", setting)
    assert_includes result, future
    assert_includes result, priv
  end

  test "for_status published behaves like visible" do
    setting = Setting.instance
    future = Post.create!(title: "Future", body: "B", scheduled_at: 1.day.from_now)

    assert_not_includes Post.for_status("published", setting), future
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/models/post_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'visible'` / `'for_status'`.

- [ ] **Step 3: Implement `visible` and `for_status`**

In `app/models/post.rb`, add after the two scopes from Task 1:

```ruby
  def self.visible(setting = Setting.instance)
    relation = not_scheduled_future
    relation = relation.where(private: false) unless setting.show_private_posts
    relation
  end

  def self.for_status(status, setting = Setting.instance)
    case status
    when "scheduled" then scheduled_future
    when "private" then where(private: true)
    when "all" then all
    else visible(setting)
    end
  end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/models/post_test.rb`
Expected: PASS, all tests green (17 runs).

- [ ] **Step 5: Commit**

```bash
git add app/models/post.rb test/models/post_test.rb
git commit -m "feat: add Post.visible and Post.for_status scopes"
```

---

## Task 4: Post CRUD completion — edit/update, shared form, status badge

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/posts_controller.rb`
- Create: `app/views/posts/_form.html.erb`
- Create: `app/views/posts/_status_badge.html.erb`
- Create: `app/views/posts/edit.html.erb`
- Modify: `app/views/posts/index.html.erb`
- Modify: `app/views/posts/show.html.erb`
- Create: `app/helpers/posts_helper.rb`
- Test: `test/controllers/posts_controller_test.rb`

**Interfaces:**
- Consumes: `Post#status` (Task 1).
- Produces: `edit_post_path`/`post_path` (PATCH) routes; `render "form", post:, submit_label:` partial contract; `render "status_badge", post:` partial contract; `status_badge_class(status)` helper — all reused by Task 5's index rewrite.

- [ ] **Step 1: Write the failing tests**

Append to `test/controllers/posts_controller_test.rb` (inside `PostsControllerTest`, after the `"should get show"` test):

```ruby
  test "should get edit" do
    get edit_post_url(@post)
    assert_response :success
  end

  test "should update post" do
    patch post_url(@post), params: { post: { title: "Updated title" } }
    assert_redirected_to post_url(@post)
    @post.reload
    assert_equal "Updated title", @post.title
  end

  test "should not update post with invalid params" do
    patch post_url(@post), params: { post: { title: "" } }
    assert_response :unprocessable_entity
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/posts_controller_test.rb`
Expected: FAIL — `edit_post_url`/routing error (404), since `:edit`/`:update` aren't routed yet.

- [ ] **Step 3: Add routes**

In `config/routes.rb`, change:

```ruby
  resources :posts, only: [:index, :show, :create, :destroy]
```

to:

```ruby
  resources :posts, only: [:index, :show, :edit, :update, :create, :destroy]
```

- [ ] **Step 4: Add controller actions**

Replace the full contents of `app/controllers/posts_controller.rb`:

```ruby
class PostsController < ApplicationController
  def index
    @posts = Post.order(created_at: :desc)
    @post = Post.new
  end

  def show
    @post = Post.find(params[:id])
  end

  def edit
    @post = Post.find(params[:id])
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to root_path, notice: "Post created."
    else
      @posts = Post.order(created_at: :desc)
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @post = Post.find(params[:id])
    if @post.update(post_params)
      redirect_to post_path(@post), notice: "Post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Post.find(params[:id]).destroy
    redirect_to root_path, notice: "Post deleted."
  end

  private

  def post_params
    params.require(:post).permit(:title, :body, :scheduled_at, :private)
  end
end
```

(Task 5 replaces `index`/`create`/`post_params` again to wire in `load_posts` — this is an intentional intermediate checkpoint, not wasted work: it keeps this task's tests green on their own before the visibility/filtering logic layers on top.)

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/posts_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Extract the shared form partial**

Create `app/views/posts/_form.html.erb`:

```erb
<%# locals: (post:, submit_label: "Save") %>
<%= form_with model: post, class: "bg-white border border-slate-200 rounded-lg p-4 mb-8 flex flex-col gap-3" do |f| %>
  <% if post.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% post.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <%= f.label :title, class: "text-sm font-medium" %>
  <%= f.text_field :title, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :body, class: "text-sm font-medium" %>
  <%= f.text_area :body, rows: 3, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.label :scheduled_at, "Schedule for (optional)", class: "text-sm font-medium" %>
  <%= f.datetime_field :scheduled_at, class: "border border-slate-300 rounded px-3 py-2" %>

  <div class="flex items-center gap-2">
    <%= f.check_box :private %>
    <%= f.label :private, "Private", class: "text-sm font-medium" %>
  </div>

  <%= f.submit submit_label, class: "self-start bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 cursor-pointer" %>
<% end %>
```

- [ ] **Step 7: Add the status badge partial and helper**

Create `app/helpers/posts_helper.rb`:

```ruby
module PostsHelper
  def status_badge_class(status)
    case status
    when "scheduled" then "bg-amber-100 text-amber-800"
    when "private" then "bg-slate-200 text-slate-700"
    else "bg-emerald-100 text-emerald-800"
    end
  end
end
```

Create `app/views/posts/_status_badge.html.erb`:

```erb
<%# locals: (post:) %>
<span class="text-xs px-2 py-1 rounded <%= status_badge_class(post.status) %>"><%= post.status.capitalize %></span>
```

- [ ] **Step 8: Wire the partials into index and show, add edit link**

Replace `app/views/posts/index.html.erb`:

```erb
<% content_for :title, "Home" %>

<h1 class="text-2xl font-semibold mb-4">Home</h1>

<%= render "form", post: @post, submit_label: "Post" %>

<div class="flex flex-col gap-4">
  <% @posts.each do |post| %>
    <div class="post-card bg-white border border-slate-200 rounded-lg p-4">
      <div class="flex justify-between items-start">
        <div class="flex items-center gap-2">
          <h2 class="font-semibold"><%= link_to post.title, post_path(post), class: "hover:text-indigo-600" %></h2>
          <%= render "status_badge", post: post %>
        </div>
        <div class="flex gap-3">
          <%= link_to "Edit", edit_post_path(post), class: "text-slate-500 text-sm hover:underline" %>
          <%= button_to "Delete", post_path(post), method: :delete, class: "text-red-600 text-sm hover:underline", form: { data: { turbo_confirm: "Delete this post?" } } %>
        </div>
      </div>
      <p class="text-slate-600 mt-1"><%= post.body %></p>
    </div>
  <% end %>
</div>
```

Replace `app/views/posts/show.html.erb`:

```erb
<% content_for :title, @post.title %>

<div class="bg-white border border-slate-200 rounded-lg p-4">
  <div class="flex items-center gap-2 mb-2">
    <h1 class="text-2xl font-semibold"><%= @post.title %></h1>
    <%= render "status_badge", post: @post %>
  </div>
  <p class="text-slate-600 whitespace-pre-line"><%= @post.body %></p>
</div>

<div class="mt-4 flex gap-3">
  <%= link_to "Back", root_path, class: "text-sm text-indigo-600 hover:underline" %>
  <%= link_to "Edit", edit_post_path(@post), class: "text-sm text-indigo-600 hover:underline" %>
  <%= button_to "Delete", post_path(@post), method: :delete, class: "text-red-600 text-sm hover:underline", form: { data: { turbo_confirm: "Delete this post?" } } %>
</div>
```

Create `app/views/posts/edit.html.erb`:

```erb
<% content_for :title, "Edit #{@post.title}" %>

<h1 class="text-2xl font-semibold mb-4">Edit post</h1>

<%= render "form", post: @post, submit_label: "Save" %>

<%= link_to "Back", post_path(@post), class: "text-sm text-indigo-600 hover:underline" %>
```

Note: `index`'s `create` failure path (`render :index, status: :unprocessable_entity` in the controller) still works — it re-renders `index.html.erb`, which now uses the `_form` partial with `@post` (the unsaved, errored post) exactly as it did inline before.

- [ ] **Step 9: Run the full test suite**

Run: `bin/rails test`
Expected: PASS, no failures (existing `assert_select "h1", @post.title` in the show test still matches since the title is still inside an `<h1>`, now alongside the badge span).

- [ ] **Step 10: Commit**

```bash
git add config/routes.rb app/controllers/posts_controller.rb app/views/posts app/helpers/posts_helper.rb test/controllers/posts_controller_test.rb
git commit -m "feat: complete post CRUD with edit/update, status badge, shared form"
```

---

## Task 5: Home feed visibility, filtering, and pagination

**Files:**
- Modify: `app/controllers/posts_controller.rb`
- Modify: `app/views/posts/index.html.erb`
- Test: `test/controllers/posts_controller_test.rb`

**Interfaces:**
- Consumes: `Post.for_status` (Task 3), `Setting.instance`/`Setting::STATUS_FILTERS` (Task 2), `_form`/`_status_badge` partials (Task 4).
- Produces: `PostsController#load_posts` (private, sets `@posts`, `@setting`, `@status`, `@page`, `@total_pages`) — no other task depends on this, it's the terminus of the visibility/filter/pagination chain.

- [ ] **Step 1: Write the failing tests**

Append to `test/controllers/posts_controller_test.rb`:

```ruby
  test "index excludes future scheduled posts by default" do
    future = Post.create!(title: "Future post", body: "B", scheduled_at: 1.day.from_now)
    get root_url
    assert_no_match future.title, @response.body
  end

  test "index excludes private posts by default" do
    priv = Post.create!(title: "Private post", body: "B", private: true)
    get root_url
    assert_no_match priv.title, @response.body
  end

  test "index includes private posts when show_private_posts setting is enabled" do
    Setting.instance.update!(show_private_posts: true)
    priv = Post.create!(title: "Private post", body: "B", private: true)
    get root_url
    assert_match priv.title, @response.body
  end

  test "index includes scheduled posts when status param is scheduled" do
    future = Post.create!(title: "Future post", body: "B", scheduled_at: 1.day.from_now)
    get root_url, params: { status: "scheduled" }
    assert_match future.title, @response.body
  end

  test "index includes private posts when status param is private" do
    priv = Post.create!(title: "Private post", body: "B", private: true)
    get root_url, params: { status: "private" }
    assert_match priv.title, @response.body
  end

  test "index paginates according to posts_per_page setting" do
    Setting.instance.update!(posts_per_page: 1)
    get root_url
    assert_select ".post-card", 1
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/posts_controller_test.rb`
Expected: FAIL — the current `index` (`Post.order(created_at: :desc)`) ignores scheduling/privacy/settings entirely, so the "excludes"/"paginates" tests fail (future/private posts show up; pagination test sees more than 1 `.post-card`).

- [ ] **Step 3: Rewrite `index`/`create` to use `load_posts`**

Replace the full contents of `app/controllers/posts_controller.rb`:

```ruby
class PostsController < ApplicationController
  def index
    load_posts
    @post = Post.new
  end

  def show
    @post = Post.find(params[:id])
  end

  def edit
    @post = Post.find(params[:id])
  end

  def create
    @post = Post.new(post_params)

    if @post.save
      redirect_to root_path, notice: "Post created."
    else
      load_posts
      render :index, status: :unprocessable_entity
    end
  end

  def update
    @post = Post.find(params[:id])
    if @post.update(post_params)
      redirect_to post_path(@post), notice: "Post updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    Post.find(params[:id]).destroy
    redirect_to root_path, notice: "Post deleted."
  end

  private

  def load_posts
    @setting = Setting.instance
    @status = params[:status].presence || @setting.default_status_filter
    scope = Post.for_status(@status, @setting)

    from_date = params[:from].presence || @setting.filter_from_date
    to_date = params[:to].presence || @setting.filter_to_date
    scope = scope.where("created_at >= ?", from_date.to_date.beginning_of_day) if from_date.present?
    scope = scope.where("created_at <= ?", to_date.to_date.end_of_day) if to_date.present?

    scope = scope.order(created_at: :desc)

    per_page = (params[:per_page].presence || @setting.posts_per_page).to_i
    per_page = 10 if per_page <= 0
    @page = [ params[:page].to_i, 1 ].max
    @total_count = scope.count
    @total_pages = [ (@total_count.to_f / per_page).ceil, 1 ].max
    @posts = scope.limit(per_page).offset((@page - 1) * per_page)
  end

  def post_params
    params.require(:post).permit(:title, :body, :scheduled_at, :private)
  end
end
```

- [ ] **Step 4: Add filter UI and pagination controls to the index view**

Replace `app/views/posts/index.html.erb`:

```erb
<% content_for :title, "Home" %>

<h1 class="text-2xl font-semibold mb-4">Home</h1>

<%= render "form", post: @post, submit_label: "Post" %>

<%= form_with url: root_path, method: :get, class: "bg-white border border-slate-200 rounded-lg p-4 mb-6 flex flex-wrap items-end gap-4" do |f| %>
  <div>
    <%= f.label :status, "Filter", class: "text-sm font-medium block" %>
    <%= f.select :status, Setting::STATUS_FILTERS.map { |s| [ s.capitalize, s ] }, { selected: @status }, class: "border border-slate-300 rounded px-3 py-2" %>
  </div>
  <div>
    <%= f.label :from, "From", class: "text-sm font-medium block" %>
    <%= f.date_field :from, value: params[:from], class: "border border-slate-300 rounded px-3 py-2" %>
  </div>
  <div>
    <%= f.label :to, "To", class: "text-sm font-medium block" %>
    <%= f.date_field :to, value: params[:to], class: "border border-slate-300 rounded px-3 py-2" %>
  </div>
  <%= f.submit "Apply", class: "bg-slate-800 text-white px-4 py-2 rounded hover:bg-slate-900 cursor-pointer" %>
<% end %>

<div class="flex flex-col gap-4">
  <% @posts.each do |post| %>
    <div class="post-card bg-white border border-slate-200 rounded-lg p-4">
      <div class="flex justify-between items-start">
        <div class="flex items-center gap-2">
          <h2 class="font-semibold"><%= link_to post.title, post_path(post), class: "hover:text-indigo-600" %></h2>
          <%= render "status_badge", post: post %>
        </div>
        <div class="flex gap-3">
          <%= link_to "Edit", edit_post_path(post), class: "text-slate-500 text-sm hover:underline" %>
          <%= button_to "Delete", post_path(post), method: :delete, class: "text-red-600 text-sm hover:underline", form: { data: { turbo_confirm: "Delete this post?" } } %>
        </div>
      </div>
      <p class="text-slate-600 mt-1"><%= post.body %></p>
    </div>
  <% end %>
</div>

<div class="flex justify-between items-center mt-6 text-sm">
  <%= link_to "Previous", url_for(request.query_parameters.merge(page: @page - 1)), class: "text-indigo-600 hover:underline #{'invisible' if @page <= 1}" %>
  <span class="text-slate-500">Page <%= @page %> of <%= @total_pages %></span>
  <%= link_to "Next", url_for(request.query_parameters.merge(page: @page + 1)), class: "text-indigo-600 hover:underline #{'invisible' if @page >= @total_pages}" %>
</div>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/posts_controller_test.rb`
Expected: PASS.

- [ ] **Step 6: Run the full test suite**

Run: `bin/rails test`
Expected: PASS, no failures.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/posts_controller.rb app/views/posts/index.html.erb test/controllers/posts_controller_test.rb
git commit -m "feat: filter and paginate the home feed by Setting"
```

---

## Task 6: Enable Active Storage + `Profile` singleton model with avatar

**Files:**
- Modify: `config/application.rb`
- Modify: `config/environments/development.rb`
- Modify: `config/environments/test.rb`
- Create: `config/storage.yml` (via generator)
- Create: `db/migrate/*_create_active_storage_tables.active_storage.rb` (via generator)
- Create: `db/migrate/<timestamp>_create_profiles.rb`
- Create: `app/models/profile.rb`
- Create: `test/fixtures/files/avatar.png`
- Test: `test/models/profile_test.rb`

**Interfaces:**
- Produces: `Profile.instance` (singleton, `first_or_create!`), `Profile#description`, `Profile#avatar` (Active Storage `has_one_attached`). Consumed by `ProfilesController` in Task 7.

- [ ] **Step 1: Enable the Active Storage and Active Job frameworks**

In `config/application.rb`, uncomment two lines — change:

```ruby
require "active_model/railtie"
# require "active_job/railtie"
require "active_record/railtie"
# require "active_storage/engine"
```

to:

```ruby
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
```

- [ ] **Step 2: Run the Active Storage installer**

Run: `bin/rails active_storage:install`

This creates `config/storage.yml` and a migration for the `active_storage_blobs`, `active_storage_attachments`, and `active_storage_variant_records` tables.

- [ ] **Step 3: Configure the local disk service**

In `config/environments/development.rb`, add near the top of the `Rails.application.configure` block (after `config.enable_reloading = true`):

```ruby
  config.active_storage.service = :local
```

In `config/environments/test.rb`, add near the top of the `Rails.application.configure` block (after `config.enable_reloading = false`):

```ruby
  config.active_storage.service = :local
```

- [ ] **Step 4: Run migrations**

Run: `bin/rails db:migrate`
Expected: creates the three `active_storage_*` tables.

- [ ] **Step 5: Create a test fixture image**

Run:
```bash
mkdir -p test/fixtures/files
printf '%s' "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=" | base64 -d > test/fixtures/files/avatar.png
```

This writes a valid 1x1 transparent PNG, used by the attachment test below.

- [ ] **Step 6: Write the failing tests**

Create `test/models/profile_test.rb`:

```ruby
require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test "instance returns the same record on repeated calls" do
    first = Profile.instance
    second = Profile.instance
    assert_equal first.id, second.id
  end

  test "avatar can be attached" do
    profile = Profile.instance
    profile.avatar.attach(
      io: File.open(Rails.root.join("test/fixtures/files/avatar.png")),
      filename: "avatar.png",
      content_type: "image/png"
    )
    assert profile.avatar.attached?
  end
end
```

- [ ] **Step 7: Run tests to verify they fail**

Run: `bin/rails test test/models/profile_test.rb`
Expected: FAIL — `NameError: uninitialized constant Profile` (table/model don't exist yet).

- [ ] **Step 8: Generate and write the `profiles` migration**

Run: `bin/rails generate migration CreateProfiles`

Edit the generated file:

```ruby
class CreateProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :profiles do |t|
      t.text :description

      t.timestamps
    end
  end
end
```

Run: `bin/rails db:migrate`

- [ ] **Step 9: Implement `Profile`**

Create `app/models/profile.rb`:

```ruby
class Profile < ApplicationRecord
  has_one_attached :avatar

  def self.instance
    first_or_create!
  end
end
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `bin/rails test test/models/profile_test.rb`
Expected: PASS.

- [ ] **Step 11: Run the full test suite**

Run: `bin/rails test`
Expected: PASS, no failures (Active Storage framework now loaded shouldn't affect existing tests).

- [ ] **Step 12: Commit**

```bash
git add config/application.rb config/environments/development.rb config/environments/test.rb config/storage.yml db/migrate db/schema.rb app/models/profile.rb test/models/profile_test.rb test/fixtures/files/avatar.png
git commit -m "feat: enable Active Storage and add Profile singleton model"
```

---

## Task 7: `ProfilesController` — real profile page

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/profiles_controller.rb`
- Create: `app/views/profiles/show.html.erb`
- Create: `app/views/profiles/edit.html.erb`
- Modify: `app/controllers/pages_controller.rb` (remove `profile` action)
- Delete: `app/views/pages/profile.html.erb`
- Modify: `test/controllers/pages_controller_test.rb` (remove the profile test)
- Test: `test/controllers/profiles_controller_test.rb`

**Interfaces:**
- Consumes: `Profile.instance`, `Profile#avatar`, `Profile#description` (Task 6).
- Produces: `profile_path`/`edit_profile_path` routes (same helper names the layout nav already calls, so `app/views/layouts/application.html.erb` needs no change).

- [ ] **Step 1: Write the failing tests**

Create `test/controllers/profiles_controller_test.rb`:

```ruby
require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get profile_url
    assert_response :success
  end

  test "should get edit" do
    get edit_profile_url
    assert_response :success
  end

  test "should update profile" do
    patch profile_url, params: { profile: { description: "Building demos." } }
    assert_redirected_to profile_url
    assert_equal "Building demos.", Profile.instance.description
  end

  test "show displays post count" do
    Post.create!(title: "T", body: "B")
    get profile_url
    assert_match(/#{Post.count} posts?/, @response.body)
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/profiles_controller_test.rb`
Expected: FAIL — routing error, `ProfilesController` doesn't exist yet.

- [ ] **Step 3: Update routes**

In `config/routes.rb`, remove:

```ruby
  get "profile" => "pages#profile"
```

and add (near the top, before `resources :posts`):

```ruby
  resource :profile, only: [:show, :edit, :update]
```

- [ ] **Step 4: Implement `ProfilesController`**

Create `app/controllers/profiles_controller.rb`:

```ruby
class ProfilesController < ApplicationController
  def show
    @profile = Profile.instance
    @posts_count = Post.count
  end

  def edit
    @profile = Profile.instance
  end

  def update
    @profile = Profile.instance
    if @profile.update(profile_params)
      redirect_to profile_path, notice: "Profile updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:profile).permit(:description, :avatar)
  end
end
```

- [ ] **Step 5: Create the views**

Create `app/views/profiles/show.html.erb`:

```erb
<% content_for :title, "Profile" %>

<h1 class="text-2xl font-semibold mb-4">Profile</h1>

<div class="bg-white border border-slate-200 rounded-lg p-4 flex flex-col gap-3">
  <% if @profile.avatar.attached? %>
    <%= image_tag @profile.avatar, class: "w-24 h-24 rounded-full object-cover" %>
  <% else %>
    <div class="w-24 h-24 rounded-full bg-slate-200"></div>
  <% end %>

  <p class="text-slate-600"><%= @profile.description.presence || "No description yet." %></p>
  <p class="text-sm text-slate-500"><%= pluralize(@posts_count, "post") %></p>

  <%= link_to "Edit profile", edit_profile_path, class: "self-start text-indigo-600 text-sm hover:underline" %>
</div>
```

Create `app/views/profiles/edit.html.erb`:

```erb
<% content_for :title, "Edit profile" %>

<h1 class="text-2xl font-semibold mb-4">Edit profile</h1>

<%= form_with model: @profile, url: profile_path, method: :patch, class: "bg-white border border-slate-200 rounded-lg p-4 flex flex-col gap-3" do |f| %>
  <% if @profile.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% @profile.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <%= f.label :avatar, class: "text-sm font-medium" %>
  <%= f.file_field :avatar, accept: "image/*" %>

  <%= f.label :description, class: "text-sm font-medium" %>
  <%= f.text_area :description, rows: 3, class: "border border-slate-300 rounded px-3 py-2" %>

  <%= f.submit "Save", class: "self-start bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 cursor-pointer" %>
<% end %>

<%= link_to "Back", profile_path, class: "text-sm text-indigo-600 hover:underline" %>
```

- [ ] **Step 6: Remove the old `PagesController#profile` action and view**

In `app/controllers/pages_controller.rb`, remove the `profile` method, leaving only `settings` (removed fully in Task 8):

```ruby
class PagesController < ApplicationController
  def settings
  end
end
```

Delete `app/views/pages/profile.html.erb`.

In `test/controllers/pages_controller_test.rb`, remove the `"should get profile"` test, leaving only the settings test:

```ruby
require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get settings" do
    get settings_url
    assert_response :success
  end
end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/controllers/profiles_controller_test.rb test/controllers/pages_controller_test.rb`
Expected: PASS.

- [ ] **Step 8: Run the full test suite**

Run: `bin/rails test`
Expected: PASS, no failures.

- [ ] **Step 9: Commit**

```bash
git add config/routes.rb app/controllers/profiles_controller.rb app/views/profiles app/controllers/pages_controller.rb test/controllers/profiles_controller_test.rb test/controllers/pages_controller_test.rb
git rm app/views/pages/profile.html.erb
git commit -m "feat: add real Profile page with avatar and post count"
```

---

## Task 8: `SettingsController` — real settings page, remove `PagesController`

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/settings_controller.rb`
- Create: `app/views/settings/show.html.erb`
- Delete: `app/controllers/pages_controller.rb`
- Delete: `app/views/pages/settings.html.erb`
- Delete: `test/controllers/pages_controller_test.rb`
- Test: `test/controllers/settings_controller_test.rb`

**Interfaces:**
- Consumes: `Setting.instance`, `Setting::STATUS_FILTERS` (Task 2).
- Produces: `settings_path` route (same helper name the layout nav already calls, so no layout change needed).

- [ ] **Step 1: Write the failing tests**

Create `test/controllers/settings_controller_test.rb`:

```ruby
require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get settings_url
    assert_response :success
  end

  test "should update settings" do
    patch settings_url, params: { setting: { posts_per_page: 5, default_status_filter: "all", show_private_posts: "1" } }
    assert_redirected_to settings_url
    setting = Setting.instance
    assert_equal 5, setting.posts_per_page
    assert_equal "all", setting.default_status_filter
    assert setting.show_private_posts
  end

  test "should not update settings with invalid status filter" do
    patch settings_url, params: { setting: { default_status_filter: "bogus" } }
    assert_response :unprocessable_entity
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/settings_controller_test.rb`
Expected: FAIL — `settings_url` still resolves (route exists via `pages#settings`), but response won't match new behavior; specifically the update test fails because `PATCH /settings` isn't routed yet (404).

- [ ] **Step 3: Update routes**

In `config/routes.rb`, remove:

```ruby
  get "settings" => "pages#settings"
```

and add next to the `resource :profile` line from Task 7:

```ruby
  resource :setting, path: "settings", as: "settings", only: [:show, :update]
```

- [ ] **Step 4: Implement `SettingsController`**

Create `app/controllers/settings_controller.rb`:

```ruby
class SettingsController < ApplicationController
  def show
    @setting = Setting.instance
  end

  def update
    @setting = Setting.instance
    if @setting.update(setting_params)
      redirect_to settings_path, notice: "Settings updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def setting_params
    params.require(:setting).permit(:posts_per_page, :default_status_filter, :show_private_posts, :filter_from_date, :filter_to_date)
  end
end
```

- [ ] **Step 5: Create the view**

Create `app/views/settings/show.html.erb`:

```erb
<% content_for :title, "Settings" %>

<h1 class="text-2xl font-semibold mb-4">Settings</h1>

<%= form_with model: @setting, url: settings_path, method: :patch, class: "bg-white border border-slate-200 rounded-lg p-4 flex flex-col gap-4" do |f| %>
  <% if @setting.errors.any? %>
    <ul class="text-red-600 text-sm">
      <% @setting.errors.full_messages.each do |message| %>
        <li><%= message %></li>
      <% end %>
    </ul>
  <% end %>

  <div>
    <%= f.label :posts_per_page, "Posts per page", class: "text-sm font-medium block" %>
    <%= f.number_field :posts_per_page, min: 1, class: "border border-slate-300 rounded px-3 py-2" %>
  </div>

  <div>
    <%= f.label :default_status_filter, "Default filter", class: "text-sm font-medium block" %>
    <%= f.select :default_status_filter, Setting::STATUS_FILTERS.map { |s| [ s.capitalize, s ] }, {}, class: "border border-slate-300 rounded px-3 py-2" %>
  </div>

  <div class="flex items-center gap-2">
    <%= f.check_box :show_private_posts %>
    <%= f.label :show_private_posts, "Show private posts on home", class: "text-sm font-medium" %>
  </div>

  <div class="flex gap-4">
    <div>
      <%= f.label :filter_from_date, "From date", class: "text-sm font-medium block" %>
      <%= f.date_field :filter_from_date, class: "border border-slate-300 rounded px-3 py-2" %>
    </div>
    <div>
      <%= f.label :filter_to_date, "To date", class: "text-sm font-medium block" %>
      <%= f.date_field :filter_to_date, class: "border border-slate-300 rounded px-3 py-2" %>
    </div>
  </div>

  <%= f.submit "Save", class: "self-start bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 cursor-pointer" %>
<% end %>
```

- [ ] **Step 6: Remove `PagesController` entirely**

Delete `app/controllers/pages_controller.rb`.
Delete `app/views/pages/settings.html.erb` (and the now-empty `app/views/pages/` directory).
Delete `test/controllers/pages_controller_test.rb`.

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/controllers/settings_controller_test.rb`
Expected: PASS.

- [ ] **Step 8: Run the full test suite**

Run: `bin/rails test`
Expected: PASS, no failures, no references to `PagesController` remain anywhere.

- [ ] **Step 9: Commit**

```bash
git add config/routes.rb app/controllers/settings_controller.rb app/views/settings test/controllers/settings_controller_test.rb
git rm app/controllers/pages_controller.rb app/views/pages/settings.html.erb test/controllers/pages_controller_test.rb
git commit -m "feat: add real Settings page, remove placeholder PagesController"
```
