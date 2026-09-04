# Redesign de UI (design system + navegação) — Design

Data: 2026-09-04
Branch: `feature/auth-oauth-apple`

## Contexto

App de gestão de plantões (RubyNative gem, Rails 8). UI atual funcional
mas visualmente "protótipo": classes Tailwind soltas e repetidas em
cada view, botão sem padrão (`indigo-600` no app vs `tint_color:
#007AFF` do `ruby_native.yml`, usado na tab bar nativa e ignorado no
resto do app), páginas de auth com form solto no topo da página,
`/settings` e `/profile` são páginas separadas mostrando/editando os
mesmos dados, calendário (`/calendar`) existe mas não é uma tab —
acessível só por link a partir da Home.

## Objetivo

1. Design system mínimo: cor primária única (`tint_color`), 3 variantes
   de botão, partial de campo de formulário padrão.
2. Tab bar: `Home`, `Calendário`, `Profile` — remove tab `Settings`.
3. Páginas de auth (login, cadastro, esqueci senha) em card centralizado
   com componentes padronizados.
4. Home mantém estrutura atual, só aplica componentes padronizados.
5. Calendário vira página de tab (view já existe, só entra na tab bar
   e perde o link redundante "Ver lista").
6. `/profile` absorve `/settings`: uma página só, mostra dados do
   usuário e permite editar (nome, email, avatar, senha) sem navegar
   para outra rota. `/settings` é removido.

## Fora de escopo (YAGNI)

- Dark mode — `tint_color`/cores continuam hex fixo, sem `{light:,
  dark:}`. Preparar para isso é trabalho futuro à parte.
- Feedback visual colorido em mensagens de sucesso (`notice`) — fica
  neutro (texto simples), como já é hoje.
- Novos tamanhos de botão (sm/lg) — um tamanho só, app pequeno não
  precisa.
- Mudança de estrutura/dados da Home ou do Calendário — só restyle.

## Design system

### Cor

`config/ruby_native.yml` já declara `appearance.tint_color: "#007AFF"`
(usado pela tab bar nativa). Essa cor vira a única fonte da cor
primária do app. Como Tailwind (via CDN/importmap, sem `tailwind.config.js`
customizado neste projeto) não lê esse YAML, a cor entra via classes
arbitrárias Tailwind (`bg-[#007AFF]`, `text-[#007AFF]`, `border-[#007AFF]`,
`hover:bg-[#0066CC]` — um tom ~15% mais escuro calculado à mão para
hover, já que não há `theme.extend.colors` neste setup) nos partials de
botão/link, em vez de `indigo-600`/`indigo-700` espalhado nas views.
Fica um único texto-fonte (o partial), então se a cor mudar no YAML no
futuro, edita-se um lugar.

Vermelho de perigo (`red-600`/`red-700`, já usado hoje) e neutros
(`slate-*`, já usado hoje) continuam como estão — só formalizados como
uso exclusivo dos partials abaixo, não mais escritos à mão nas views.

### Botões

Três partials em `app/views/shared/`:

- `_button_primary.html.erb` — recebe `text:`, `url:`, `method:`
  (default `:get`), `html: {}`. Renderiza `link_to`/`button_to` sólido
  com a cor primária, texto branco, `px-4 py-2 rounded font-medium`.
  Usos: Salvar, Criar conta, Entrar, Novo plantão, Adicionar plantão.
- `_button_danger.html.erb` — mesma interface, vermelho sólido. Uso:
  Remover (shift).
- `_link_action.html.erb` — texto sublinhado cor primária (ou
  `slate-500` para ações neutras tipo "Fechar"), sem fundo. Usos:
  Editar, Ver calendário, Esqueci minha senha, Criar conta (link),
  Gerenciar categorias, Mês anterior/próximo, Fechar.

Botão "Entrar com Apple" é caso especial (marca, preto) — mantém botão
próprio, não usa os partials, mas ganha o mesmo `px-4 py-2 rounded
font-medium` de base para consistência de tamanho/raio.

### Campo de formulário

Partial `_field.html.erb` recebe `form:`, `attribute:`, `label:`,
`type:` (`:text`/`:email`/`:password`/`:file`, default `:text`),
options extras (`required:`, `autofocus:`, `autocomplete:`). Encapsula
o par `label` + input com classes padrão já usadas hoje
(`block text-sm font-medium mb-1` / `w-full border border-slate-300
rounded px-3 py-2`). Usado em registrations, sessions, passwords,
profile (form de edição). `collection_select` do form de shift/dia não
entra nesse partial (é um select com opções dinâmicas, fora do escopo
deste redesign).

## Navegação

`config/ruby_native.yml`, seção `tabs`:

```yaml
tabs:
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

Tab `Settings` (`gear`, `/settings/edit`) é removida.

`app/views/layouts/_navbar.html.erb` (fallback web quando `native_app?`
é falso) espelha a mesma lista de 3 links, removendo o link "Settings".

## Páginas de auth

`registrations/new`, `sessions/new`, `passwords/new`, `passwords/edit`
passam a usar um wrapper comum: card centralizado
(`max-w-sm mx-auto mt-8 bg-white border border-slate-200 rounded-lg
p-6`), título (`content_for :title`) acima do card, campos via
`_field`, submit via `_button_primary`, links secundários via
`_link_action`. Sem mudança de campos/validações — só de casca visual.

## Home (`shifts#index`)

Sem mudança estrutural. "Novo plantão" vira `_button_primary`, "Ver
calendário" vira `_link_action`, "Editar"/"Remover" de cada shift viram
`_link_action`/`_button_danger`.

## Calendário

Entra na tab bar (seção Navegação acima). Remove o link "Ver lista"
(`root_path`) do fim de `calendar/show.html.erb` — redundante agora
que Home e Calendário são tabs irmãs. "Gerenciar categorias" e
"Mês anterior"/"Próximo mês" viram `_link_action`. Modal de dia
(`calendar/day.html.erb`): "Fechar" e "Nova categoria" viram
`_link_action`, "Adicionar plantão" vira `_button_primary`, "Remover"
vira `_button_danger`.

## Profile (absorve Settings)

Uma página, uma rota (`GET /profile`, `PATCH /profile`).

`SettingsController` é removido. `PagesController` (renomeado
`ProfilesController` — só ela sobra depois que `#profile` for o único
método relevante) ganha `#show` (era `#profile`) e `#update` (lógica
migrada de `SettingsController#update` sem mudança de comportamento:
mesma validação de senha atual, mesmo `password_change_requested?`,
mesmo destroy de outras sessões ao trocar senha).

Rotas: `get "profile" => "profiles#show"` e
`patch "profile" => "profiles#update"` no lugar de
`resource :settings` e `get "profile" => "pages#profile"`.

View `app/views/profiles/show.html.erb` concatena o que hoje é
`pages/profile.html.erb` (avatar, nome, email — topo, somente leitura)
com o form que hoje é `settings/edit.html.erb` (nome, email, avatar,
trocar senha — usando `_field` e `_button_primary`), sem toggle, sem
segunda navegação. Erros de validação renderizam a mesma página
(`render :show, status: :unprocessable_entity`).

## Testes

- `test/controllers/settings_controller_test.rb` vira
  `test/controllers/profiles_controller_test.rb`, ajustando path
  (`/settings` -> `/profile`, `PATCH`) e nome de controller/classe
  testada. Mesmos casos (update válido/inválido, troca de senha,
  destroy de outras sessões).
- `test/controllers/sessions_controller_test.rb` — checar referências a
  `edit_settings_path`/rota antiga e atualizar para `profile_path`.
- Sem teste de estilo/CSS — verificação visual manual (rodar app,
  conferir cada página) cobre a parte de design.

## Migração / ordem de execução

1. Design system: partials de botão/campo, sem tocar views ainda.
2. `ruby_native.yml` (tabs) + `_navbar.html.erb`.
3. Auth (registrations, sessions, passwords) — usa os partials.
4. Home + Calendário — usa os partials, remove link "Ver lista".
5. Profile/Settings merge: rotas, controller, view, testes.

Cada fase é independentemente testável (app continua funcional entre
fases).
