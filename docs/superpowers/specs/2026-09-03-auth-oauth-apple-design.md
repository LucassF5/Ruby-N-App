# Autenticação Rails + OAuth Apple — Design

Data: 2026-09-03
Branch: `feature/auth-oauth-apple`

## Contexto

App de gestão de plantões (RubyNative gem, Rails 8). Hoje sem `User`, sem
sessão, dados de `Shift`/`Category` globais. `/profile` e `/settings` são
views estáticas (`PagesController#profile`/`#settings`).

## Objetivo

1. Autenticação nativa do Rails 8 (email/senha, gerador `has_secure_password`).
2. Cadastro público (signup aberto).
3. App vira multiusuário: `Shift` e `Category` passam a pertencer a um `User`.
4. Login com Apple (OAuth) via ruby_native `auth.oauth_paths`.
5. `/settings` funcional: editar nome, email, senha, avatar.
6. `/profile` mostra dados reais do usuário logado.

## Componentes

### 1. Auth base (gerador Rails 8)

`bin/rails generate authentication` cria:
- `User` (`email_address`, `password_digest`)
- `Session` (`belongs_to :user`)
- `Current` (CurrentAttributes: `user`, `session`)
- Concern `Authentication` incluída em `ApplicationController` — bloqueia
  toda ação por padrão; `allow_unauthenticated_access` libera ações
  específicas.
- `SessionsController` (login/logout)
- `PasswordsController` + mailer (reset de senha)

Gerador não inclui cadastro público. Adiciona-se manualmente:
- `RegistrationsController#new/#create` — cria `User`, autentica, redireciona.
  `allow_unauthenticated_access` nas duas ações.

Rotas: `/session/new`, `/session` (DELETE), `/passwords/*`,
`/registrations/new`, `/registrations` (POST).

Todas as páginas do app exigem login exceto as rotas de auth acima.

### 2. Multiusuário (scoping)

Migrations: `add_user_id_to_shifts`, `add_user_id_to_categories`
(NOT NULL, FK, index). Sem backfill — sem dados de produção ainda, banco
dev é resetado.

- `User has_many :shifts, :categories, dependent: :destroy`
- `Shift belongs_to :user`
- `Category belongs_to :user`

`ShiftsController`, `CategoriesController`, `CalendarController` trocam
consultas de `Shift.`/`Category.` (classe) por `Current.user.shifts`/
`Current.user.categories` (association) — impede acesso cross-user via
`find` (404 em vez de vazar registro de outro usuário).
`shift_params`/`category_params` não aceitam `user_id` do form.

### 3. Apple OAuth

Gems: `omniauth`, `omniauth-apple`, `omniauth-rails_csrf_protection`.

Migration `add_provider_uid_to_users`: `provider` (string, nullable),
`uid` (string, nullable), índice único `[provider, uid]`.

Credenciais Apple (Services ID, Team ID, Key ID, chave `.p8`) via
`config/credentials.yml.enc` — configuração externa no Apple Developer,
fora do código.

`OmniauthController#apple`: lê `request.env["omniauth.auth"]`, busca
`User` por `provider+uid`; se não achar, tenta linkar por email
(conta já existente com senha) ou cria novo `User` (senha:
`SecureRandom.hex` direto em `password_digest`, sem passar por
`password=`, então `has_secure_password` não exige presença). Cria
`Session`, `allow_unauthenticated_access` na ação.

`config/ruby_native.yml`:
```yaml
auth:
  oauth_paths:
    - /auth/apple
```

Rotas `/auth/apple` e `/auth/apple/callback` são montadas pelo omniauth,
nada declarado em `routes.rb` além do controller de callback.

Link "Entrar com Apple" aponta para `/auth/apple`. No app nativo iOS,
ruby_native abre `ASWebAuthenticationSession` (sheet do sistema) nesse
path em vez de navegar in-app; web/Android segue fluxo de browser
padrão. Sheet fecha sozinho ao completar ou cancelar (sem crash, sem
estado quebrado — comportamento da gem).

Guideline App Store 4.8: como app oferece login de terceiro, precisa
oferecer Sign in with Apple — já é o caso.

### 4. Settings / Profile

`bin/rails active_storage:install` (migrations Active Storage) + gem
`image_processing`.

`User has_one_attached :avatar`.

`PagesController#settings` vira `SettingsController#edit/#update`
(protegido por auth normal, opera sobre `Current.user`). Form: nome,
email, avatar (file field), senha nova + confirmação de senha atual
(via `authenticate`, só valida se campo preenchido — troca de senha
opcional).

`PagesController#profile` (ou controller próprio) passa a exibir dados
reais de `Current.user` (nome, avatar) em vez de placeholder estático.

## Fluxo de dados

```
Visitante não autenticado -> qualquer rota protegida
  -> Authentication concern barra -> redirect /session/new

Login email/senha -> SessionsController#create -> Session.create -> Current.session=
Cadastro -> RegistrationsController#create -> User.create -> autentica -> Current.session=
Login Apple -> GET /auth/apple -> Apple -> GET /auth/apple/callback
  -> OmniauthController#apple -> find_or_create User -> Session.create -> Current.session=

Toda request autenticada -> Current.user disponível em controllers/views
  -> Shift/Category sempre acessados via Current.user.shifts/.categories
```

## Tratamento de erro

- Login/senha inválidos: mensagem genérica (não revela se email existe).
- Signup com email duplicado: validação `uniqueness` em `email_address`,
  erro no form.
- Apple OAuth cancelado/falhou: sheet fecha, usuário permanece na tela
  de login (comportamento nativo da gem, sem tratamento extra no Rails
  além de rota de callback de falha padrão do omniauth redirecionando
  pra `/session/new`).
- Acesso a `Shift`/`Category` de outro usuário: `RecordNotFound` (404),
  pois consulta já é escopada por `Current.user`.

## Testes

- Model: `User` (validações email/senha, `has_secure_password`),
  `Shift`/`Category` (`belongs_to :user` presence).
- Request: login, logout, signup (sucesso/falha), reset senha,
  callback Apple (mock `omniauth.auth`) criando/linkando usuário.
- Request: `ShiftsController`/`CategoriesController` — usuário A não
  acessa/edita registro de usuário B (404).
- Request: `SettingsController#update` — troca nome/email/senha/avatar.

## Fora de escopo (YAGNI)

- Outros providers OAuth (Google etc.) — só Apple por ora.
- Notificação push, badges, toasts — planejado à parte.
- Convite/admin-only signup — cadastro é aberto.
