# RubyNative — Shift Management / Gestão de Plantões

**English** | [Português](#português)

---

## English

Shift management app built with Ruby on Rails and packaged as a native app
(iOS/Android) through the [`ruby_native`](https://rubynative.com) gem. A single
Rails codebase serves both the web and the native app.

### What it is

An application to organize work shifts: create shifts with date, time, location
and notes; reusable categories (with color and time range) to classify each
shift; and a calendar view to browse the schedule by month and by day. Supports
shifts that cross midnight (overnight shifts).

### Purpose

Serve as a vehicle to showcase the `ruby_native` gem: turning a conventional
Rails application into a native app with native navigation, tabs, theme and
authentication — without rewriting the interface in Swift/Kotlin. The shift
domain provides a real use case (auth, CRUD, calendar, push) to exercise the gem.

### Technologies

- **Ruby** 4.0.5
- **Rails** 8.1
- **SQLite** (Active Record) — database
- **Puma** — web server
- **Propshaft** — asset pipeline
- **Tailwind CSS** (`tailwindcss-rails`) — styling
- **Hotwire** (`turbo-rails`) + **Importmap** — front-end without a bundler
- **Herb** — HTML+ERB templates
- **ruby_native** — native packaging (navigation, tabs, theme, OAuth, push)
- **OmniAuth** + **omniauth-apple** — "Sign in with Apple" login
- **bcrypt** — password hashing
- **image_processing** + **Active Storage** — image upload/variants
- **APNs** — push notifications on iOS

### Modules

- **Authentication** (`sessions`, `registrations`, `passwords`, `omniauth`) —
  email/password login, password recovery and Sign in with Apple. Sessions
  persisted in the `sessions` table.
- **Shifts** (`shifts`) — shift CRUD (date, start/end time, location, notes,
  category). Overnight shifts supported. Root route.
- **Categories** (`categories`) — category CRUD with name, color and time range;
  used to classify shifts.
- **Calendar** (`calendar`) — monthly (`/calendar`) and daily (`/calendar/:date`)
  view of shifts.
- **Profile** (`profiles`) — view and edit the user profile, with avatar via
  Active Storage.
- **Native configuration** (`config/ruby_native.yml`) — tabs (Home, Calendar,
  Categories, Profile), theme, colors, native navigation and OAuth.

**Models:** `User` → has many `Shift`, `Category` and `Session`. `Shift` belongs
to `User` and optionally to `Category`. `Category` belongs to `User`.

### Installation

Prerequisites: Ruby 4.0.5 (see `.ruby-version`).

```bash
# clone and enter the directory
git clone <repo-url>
cd RubyNative

# install dependencies and prepare the database
bin/setup
```

`bin/setup` installs the gems, creates and migrates the database (SQLite) and
prepares the environment. To prepare the database manually:

```bash
bin/rails db:prepare
```

**Credentials.** Sign in with Apple and push (APNs) read
`Rails.application.credentials`. Configure with:

```bash
bin/rails credentials:edit
```

Expected keys: `apple` (`client_id`, `team_id`, `key_id`, `private_key`) and
`apns` (`key_id`, `team_id`, `bundle_id`, `encryption_key`).

### Running

Web + Tailwind watcher together (via `Procfile.dev`):

```bash
bin/dev
```

Or just the Rails server:

```bash
bin/rails server
```

Open http://localhost:3000.

**Native app.** With the server running, open the RubyNative app pointing at the
server URL. Native configuration (tabs, theme, OAuth) lives in
`config/ruby_native.yml` — edit and relaunch the app to see changes. Details:
https://rubynative.com/docs.

### Tests

```bash
bin/rails test
```

Full CI (lint + tests), as in the pipeline:

```bash
bin/ci
```

---

## Português

App de gestão de plantões construído em Ruby on Rails e empacotado como
aplicativo nativo (iOS/Android) através da gem
[`ruby_native`](https://rubynative.com). Uma única base de código Rails serve
tanto a web quanto o app nativo.

### O que é

Aplicação para organizar plantões de trabalho: cadastro de plantões com data,
horário, local e anotações; categorias reutilizáveis (com cor e faixa de horário)
para classificar cada plantão; e uma visão de calendário para consultar a agenda
por mês e por dia. Suporta plantões que atravessam a meia-noite (turnos noturnos).

### Intuito

Servir de veículo para demonstrar a gem `ruby_native`: transformar uma aplicação
Rails convencional em um app nativo com navegação, abas, tema e autenticação
nativos — sem reescrever a interface em Swift/Kotlin. O domínio de plantões dá um
caso de uso real (autenticação, CRUD, calendário, push) para exercitar a gem.

### Tecnologias

- **Ruby** 4.0.5
- **Rails** 8.1
- **SQLite** (Active Record) — banco de dados
- **Puma** — servidor web
- **Propshaft** — pipeline de assets
- **Tailwind CSS** (`tailwindcss-rails`) — estilos
- **Hotwire** (`turbo-rails`) + **Importmap** — front-end sem bundler
- **Herb** — templates HTML+ERB
- **ruby_native** — empacotamento nativo (navegação, abas, tema, OAuth, push)
- **OmniAuth** + **omniauth-apple** — login "Sign in with Apple"
- **bcrypt** — hash de senha
- **image_processing** + **Active Storage** — upload/variação de imagens
- **APNs** — push notifications no iOS

### Módulos

- **Autenticação** (`sessions`, `registrations`, `passwords`, `omniauth`) — login
  por email/senha, recuperação de senha e Sign in with Apple. Sessões persistidas
  na tabela `sessions`.
- **Plantões** (`shifts`) — CRUD de plantões (data, horário início/fim, local,
  anotações, categoria). Turnos que cruzam a meia-noite suportados. Rota raiz.
- **Categorias** (`categories`) — CRUD de categorias com nome, cor e faixa de
  horário; usadas para classificar plantões.
- **Calendário** (`calendar`) — visão mensal (`/calendar`) e diária
  (`/calendar/:date`) dos plantões.
- **Perfil** (`profiles`) — visualização e edição do perfil do usuário, com avatar
  via Active Storage.
- **Configuração nativa** (`config/ruby_native.yml`) — abas (Home, Calendário,
  Categorias, Profile), tema, cores, navegação nativa e OAuth.

**Modelos:** `User` → tem muitos `Shift`, `Category` e `Session`. `Shift` pertence
a `User` e opcionalmente a `Category`. `Category` pertence a `User`.

### Instalação

Pré-requisitos: Ruby 4.0.5 (ver `.ruby-version`).

```bash
# clonar e entrar no diretório
git clone <repo-url>
cd RubyNative

# instalar dependências e preparar o banco
bin/setup
```

`bin/setup` instala as gems, cria e migra o banco (SQLite) e prepara o ambiente.
Para preparar o banco manualmente:

```bash
bin/rails db:prepare
```

**Credenciais.** Login com Apple e push (APNs) leem
`Rails.application.credentials`. Configure com:

```bash
bin/rails credentials:edit
```

Chaves esperadas: `apple` (`client_id`, `team_id`, `key_id`, `private_key`) e
`apns` (`key_id`, `team_id`, `bundle_id`, `encryption_key`).

### Rodando

Web + Tailwind watcher juntos (via `Procfile.dev`):

```bash
bin/dev
```

Ou só o servidor Rails:

```bash
bin/rails server
```

Acesse http://localhost:3000.

**App nativo.** Com o servidor no ar, abra o app RubyNative apontando para a URL
do servidor. A configuração nativa (abas, tema, OAuth) fica em
`config/ruby_native.yml` — edite e relance o app para ver as mudanças. Detalhes:
https://rubynative.com/docs.

### Testes

```bash
bin/rails test
```

CI completa (lint + testes), como no pipeline:

```bash
bin/ci
```
