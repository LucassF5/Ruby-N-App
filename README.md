# RubyNative — Gestão de Plantões

App de gestão de plantões construído em Ruby on Rails e empacotado como aplicativo
nativo (iOS/Android) através da gem [`ruby_native`](https://rubynative.com). Uma
única base de código Rails serve tanto a web quanto o app nativo.

## O que é

Aplicação para organizar plantões de trabalho: cadastro de plantões com data,
horário, local e anotações; categorias reutilizáveis (com cor e faixa de horário)
para classificar cada plantão; e uma visão de calendário para consultar a agenda
por mês e por dia. Suporta plantões que atravessam a meia-noite (turnos noturnos).

## Intuito

Servir de veículo para demonstrar a gem `ruby_native`: transformar uma aplicação
Rails convencional em um app nativo com navegação, abas, tema e autenticação
nativos — sem reescrever a interface em Swift/Kotlin. O domínio de plantões dá um
caso de uso real (autenticação, CRUD, calendário, push) para exercitar a gem.

## Tecnologias

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

## Módulos

- **Autenticação** (`sessions`, `registrations`, `passwords`, `omniauth`) — login por
  email/senha, recuperação de senha e Sign in with Apple. Sessões persistidas na
  tabela `sessions`.
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

### Modelos

`User` → tem muitos `Shift`, `Category` e `Session`. `Shift` pertence a `User` e
opcionalmente a `Category`. `Category` pertence a `User`.

## Instalação

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

### Credenciais

Login com Apple e push (APNs) leem `Rails.application.credentials`. Configure com:

```bash
bin/rails credentials:edit
```

Chaves esperadas: `apple` (`client_id`, `team_id`, `key_id`, `private_key`) e
`apns` (`key_id`, `team_id`, `bundle_id`, `encryption_key`).

## Rodando

Web + Tailwind watcher juntos (via `Procfile.dev`):

```bash
bin/dev
```

Ou só o servidor Rails:

```bash
bin/rails server
```

Acesse http://localhost:3000.

### App nativo

Com o servidor no ar, abra o app RubyNative apontando para a URL do servidor.
A configuração nativa (abas, tema, OAuth) fica em `config/ruby_native.yml` — edite
e relance o app para ver as mudanças. Detalhes: https://rubynative.com/docs.

## Testes

```bash
bin/rails test
```

CI completa (lint + testes), como no pipeline:

```bash
bin/ci
```
