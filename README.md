<p align="center">
  <img src="assets/icon/app_icon.png" alt="RV·LABEL" width="160">
</p>

# RV Label

App da loja de roupas **RV Label**, coleção **Essence**, feito em Flutter/Dart para Android, iOS, web e Windows.
Projeto Integrado de Modelagem e Desenvolvimento de Sistemas, UNIFEOB 2026.2.

O repositório tem três partes, cada uma com a sua pasta: o **app** (Flutter, na raiz), o **site** da loja ([`site/`](site/), React) e a **API** de pedidos e do painel ([`api/`](api/), Node + MySQL). Versão atual do app: **1.3.0**. O que mudou em cada versão está no [`CHANGELOG.md`](CHANGELOG.md).

## Baixar o app (Windows)

Pegue o `.zip` da versão mais recente em **[Releases](../../releases/latest)**.

1. **Descompacte a pasta inteira** (não abra o `.exe` de dentro do `.zip`).
2. Abra `rvlabel_app.exe`.

Funciona em Windows 10/11 de 64 bits (Intel/AMD); as bibliotecas do Visual C++ já vão no pacote. Como o app ainda não tem assinatura digital, o Windows pode avisar "O Windows protegeu o seu computador": clique em **Mais informações** e depois em **Executar assim mesmo**. No Windows edição "N", instale o *Media Feature Pack* da Microsoft.

Desde a 1.2.2, o pacote das Releases já conversa com o servidor da loja na internet (`https://rvlabel-api.onrender.com`). Ele fica no plano grátis do Render e "dorme" quando ninguém usa: a primeira abertura depois de um tempo pode levar cerca de 50 segundos para trazer as peças. Sem o servidor (veja [Servidor e banco](#servidor-e-banco)) o app mostra a última cópia do catálogo que guardou (o que a administradora tinha ativado), não registra pedidos e a área administrativa não abre. Só se nunca falou com o servidor é que a vitrine abre vazia, porque o catálogo embutido vem desativado.

## O que o app faz

- **Vitrine** com a coleção Essence em duas visões, que se alternam em **Vitrine | Grade**: a lista de nomes com a foto da peça ao passar o mouse, e a grade de cartões. Barra de filtros presa no topo (categoria, tamanho, cor, faixa de preço e ordem) e página de cada peça (cor, tamanho, miniaturas de frente e de costas, foto com zoom), que termina em "Você também pode gostar".
- **Visual** definido em [`docs/DESIGN.md`](docs/DESIGN.md) (editorial escuro, vermelho só em ações e destaques, DM Serif Display nos títulos e Manrope no texto), com os tokens em `lib/ui/tema.dart`.
- **Página inicial** com o índice por categoria ("Tudo o que a Essence tem hoje") e o guia "Antes de escolher" (tamanhos, cores, preços e atendimento), os mesmos do site.
- **Coleções**, páginas **Sobre** e **Contato** e a faixa **Novidades RV**, com navegação Loja / Sobre / Contato e uma linha animada sob a opção do cabeçalho em que o mouse está.
- **Sacola** e fechamento do pedido pelo **WhatsApp**. O formulário de Contato e as Novidades também seguem pelo WhatsApp.
- **Meus pedidos:** o cliente acompanha o andamento com o número do pedido e o telefone.
- **Área administrativa** com login: pedidos (com indicadores de vendas), preços, estoque, o que aparece na loja (um produto por vez ou vários de uma vez, com "Selecionar vários" e "Selecionar todos") e cadastro de produtos.
- **Assistente de estilo com IA** (GenUI + Firebase AI Logic).
- **Animações ligadas à rolagem** (scroll-linked, parallax nas fotos), **rolagem suave** com a roda do mouse e fundo líquido animado (shader).
- Tela de **privacidade e termos** (LGPD), com a identificação da loja (CNPJ 68.647.856/0001-97) e o e-mail de contato `suporte.rvlabel@gmail.com`, que também aparecem no rodapé. O site mostra os mesmos dados.
- O catálogo fica em `assets/catalogo.json` e as fotos em `assets/fotos/`. **Todas as peças vêm desativadas no app** (`"ativo": false`): quem decide o que aparece na loja do app é a administradora, pelo painel (veja [Catálogo desativado](#catálogo-desativado)).

## Como rodar (desenvolvimento)

Requisitos: [Flutter](https://docs.flutter.dev/get-started/install) estável recente (testado com 3.47) e, para Windows, o Visual Studio com a carga "Desenvolvimento para desktop com C++".

```bash
flutter pub get
flutter run -d windows     # ou: -d chrome, ou o id de um emulador/celular
```

As pastas `android`, `ios`, `web` e `windows` já estão no repositório; não é preciso rodar `flutter create`. Use `flutter devices` para ver os dispositivos disponíveis.

Só com isso o app já abre. O Assistente de IA e a parte do servidor são opcionais e estão descritos abaixo.

## Servidor e banco

Pedidos, "Meus pedidos", o login e o painel administrativo conversam com uma API Node.js + MySQL (banco `Rv_Label`). O código dessa API está na pasta [`api/`](api/), mas **as credenciais e o `.env` nunca são versionados**: copie `api/.env.example` para `api/.env` e preencha `DB_USER`, `DB_PASSWORD` e `JWT_SECRET` (um texto aleatório com 48+ caracteres). O passo a passo (criar o banco, popular o catálogo e definir a senha da administradora) está em [`api/COMO-RODAR.md`](api/COMO-RODAR.md).

Para pôr a API no ar de graça (Render + banco no Aiven), siga a seção "Hospedar" de [`api/COMO-RODAR.md`](api/COMO-RODAR.md); o `render.yaml` da raiz já descreve o serviço.

O app procura a API em `http://localhost:3000`. Para outro endereço (por exemplo, o do Render na hora de gerar a versão para os clientes):

```bash
flutter run -d windows --dart-define=API_URL=http://192.168.0.10:3000
# emulador Android: --dart-define=API_URL=http://10.0.2.2:3000
```

Rotas que o app usa:

| Rota | Quem usa | Para quê |
|---|---|---|
| `GET /produtos` | público | só as peças que a administradora ativou (o app guarda uma cópia; se a API falhar, usa a cópia) |
| `POST /pedidos` | público | registrar o pedido |
| `GET /pedidos/:id?telefone=` | público | consultar o andamento (exige os dois dados) |
| `GET /saude` | monitor | 200 se a API alcança o banco, 503 se não |
| `POST /admin/login` | admin | entrar e receber o token |
| `GET/POST /admin/produtos`, `PATCH /admin/produtos/:codigo` | admin | listar, cadastrar e alterar produtos |
| `PUT /admin/estoque` | admin | ajustar o estoque de uma variação |
| `GET /admin/pedidos`, `PATCH /admin/pedidos/:id` | admin | listar pedidos e mudar o status |

**Operação da API** (em `api/`, detalhes em `api/COMO-RODAR.md`): `npm run migrar` aplica as mudanças de banco pendentes, `npm run backup` gera o backup (fora do git), e as rotas públicas de pedido têm limite de requisições por IP. Os testes são `npm run test:unit`, `npm run test:migrar` e `npm test`, e rodam sozinhos no GitHub em todo PR.

**Acesso ao painel:** não há link para clientes. Segure o clique (ou o dedo) sobre a logo **RV·LABEL** na tela inicial. Não existe cadastro público de administrador: a conta é criada direto no banco pela equipe e a senha é guardada criptografada.

## Catálogo desativado

O catálogo de peças (`assets/catalogo.json`, 15 peças da coleção Essence) está no repositório, mas **todo desativado no app**, para que a administradora tenha o controle total da loja do app.

- **Banco:** `npm run seed` (em `api/`) importa as peças com `ativo = 0`. Importar de novo nunca liga nem desliga o que já existe, então a escolha dela fica preservada.
- **No app:** a loja só mostra o que a administradora ativou no painel (o interruptor de cada produto, ou "Selecionar vários" para ativar ou desativar várias de uma vez, com "Selecionar todos"). Depois de ativar uma peça, reabra o app para ela aparecer.
- **Fica salvo:** o que ela ativou continua aparecendo até ela desativar, mesmo fechando e abrindo o app. A cada mudança no painel, e a cada abertura com o servidor ligado, o app guarda uma cópia do catálogo ativo no aparelho.
- **Sem a API** (fora do ar ou sem servidor), o app usa essa cópia. Só se nunca falou com o servidor abre com a vitrine vazia, porque o `catalogo.json` embutido vem desativado.
- **Fotos:** o caminho de cada foto (`assets/fotos/...`) fica no banco e precisa ser igual ao nome de um arquivo que vai dentro do app. Peça que sobrou no banco com foto que não existe mais (por exemplo, as de testes antigos) aparece como "Foto em breve" até alguém corrigir a foto ou desativar a peça.
- **Ligar uma peça direto no arquivo** (app sem API): troque `"ativo": false` por `true` (ou apague o campo) nessa peça.
- **No site:** com a API ligada (`VITE_API_URL`), a vitrine é a mesma do app: só o que a administradora ativou. O site guarda no navegador a última lista que recebeu e a usa se a API não responder. Sem API, ou se nunca recebeu uma lista, mostra o `catalogo.json` inteiro, ignorando o campo `ativo`.
- Produtos cadastrados pelo painel já nascem ativos. As fotos das peças desativadas continuam disponíveis no formulário de novo produto.

## Assistente de IA (Firebase)

O Assistente usa o Firebase AI Logic. Sem configurar, o resto do app funciona normalmente e só o Assistente fica indisponível.

1. No [console do Firebase](https://console.firebase.google.com), crie um projeto e ative o **Firebase AI Logic**.
2. Instale as ferramentas e gere a configuração:
   ```bash
   npm install -g firebase-tools
   firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=android,ios,web,windows
   ```
   Isso cria o `lib/firebase_options.dart` com as suas chaves, no lugar do arquivo de exemplo.
3. No Android, baixe o `google-services.json` do console e coloque em `android/app/`, no lugar do de exemplo.
4. **App Check (debug):** gere um token qualquer (por exemplo, um GUID), cadastre-o em *App Check → Apps → cada app → Gerenciar tokens de debug* e rode com:
   ```bash
   flutter run -d windows --dart-define=APP_CHECK_DEBUG_TOKEN=<seu-token>
   ```
   Se guardar o token num arquivo, use `.appcheck-token`, que o git ignora.

As chaves do Firebase e o número real do WhatsApp **não ficam no repositório**: em `lib/firebase_options.dart` e `android/app/google-services.json` os valores estão como `COLE_SUA_...`.

## Número do WhatsApp

Em `lib/main.dart`, troque o número fictício (`5511999990000`) pelo da loja: DDI + DDD + número, só dígitos. Enquanto isso não for feito, o fechamento de pedido, o Contato e as Novidades abrem uma conversa com um número que não existe. No site o número vem de `VITE_WHATSAPP`.

## Gerar o app de Windows

```bash
flutter build windows --release --dart-define=API_URL=https://rvlabel-api.onrender.com
```

Sem o `--dart-define`, o `.exe` procura a API em `http://localhost:3000` (serve para testar com a API local).

O executável sai em `build/windows/x64/runner/Release/`. Para distribuir, leve a pasta inteira (o `.exe`, as DLLs e a pasta `data`) mais as DLLs do Visual C++ (`msvcp140.dll`, `vcruntime140.dll` e `vcruntime140_1.dll`) no mesmo diretório. O pacote `.zip` pronto de cada versão (com as DLLs e o `LEIA-ME.txt`) fica nas [Releases](../../releases); a pasta [`release/`](release/) só guarda o da 1.1.1, e os pacotes novos que você gerar ali não são versionados.

## Gerar o app de Android

O identificador do app é `br.com.rvlabel.app` (Android, iOS e Windows). Para a Play Store, a versão precisa da chave da loja:

1. Gere a chave uma vez (o `keytool` vem com o JDK do Android Studio) e guarde-a **fora do repositório**, com backup:
   ```bash
   keytool -genkey -v -keystore C:/chaves/rvlabel.jks -keyalg RSA -keysize 2048 -validity 10000 -alias rvlabel
   ```
2. Crie `android/key.properties` (o git ignora) com `storeFile=C:/chaves/rvlabel.jks`, `storePassword=...`,
   `keyAlias=rvlabel` e `keyPassword=...`.
3. `flutter build appbundle --release --dart-define=API_URL=https://SEU-SERVICO.onrender.com`

Sem o `key.properties`, a release sai assinada com a chave de debug: instala no celular para teste, mas a Play Store recusa.
Perder a chave impede atualizar o app já publicado.

## Ícone do app

O ícone é o letreiro RV·LABEL. As imagens-base ficam em `assets/icon/`; para trocar, substitua-as e rode:

```bash
flutter pub run flutter_launcher_icons
```

## Versão para site

Além do app, o repositório tem uma **versão para site** da loja, na pasta [`site/`](site/). É um projeto separado do app: tem o próprio `package.json` e não interfere em nada no `flutter run`, no `flutter build` nem nas pastas `lib/`, `android/`, `ios/`, `web/` e `windows/`. (A pasta `web/` é o alvo web do Flutter; o site em React vive só em `site/`.)

- **React 18 + Vite + TypeScript + Tailwind**, com poucas dependências.
- Mesmo catálogo, mesmas fotos, mesma fonte e mesmas cores do app. `npm run sync` copia `assets/catalogo.json`, as fotos, as fontes e os ícones do app para `site/public/`.
- **Páginas:** Início (com o resumo da coleção por categoria e o guia "Antes de escolher"), Loja, Peça, Sacola, Coleções, Sobre, Contato, Novidades, Meus pedidos e Privacidade/termos (com CNPJ e e-mail de contato). A **área administrativa fica só no app**.
- **Vitrine igual à do app:** com a API, mostra só o que a administradora ativou; sem ela, o `catalogo.json` inteiro (veja [Catálogo desativado](#catálogo-desativado)).
- **Loja** com filtro por categoria e duas visões: a **vitrine** (lista de nomes com a prévia da foto e uma transição que abre a peça em tela cheia) e a **grade**.
- **Fechamento de pedido** pelo WhatsApp, com a mesma mensagem do app. Se houver a API (a mesma das rotas `POST /pedidos` e `GET /pedidos/:id`), o pedido também é gravado no banco.
- **Animações ligadas à rolagem** (scroll-linked, parallax nas fotos), que respeitam "reduzir movimento" do sistema.

```bash
cd site
npm install
npm run dev        # http://localhost:5173
```

Outros comandos: `npm test` (testes), `npm run build` (gera `site/dist/`, um site estático) e `npm run sync` (traz do app o catálogo e as fotos de novo, sempre que mudarem).

Configuração em `site/.env` (modelo em `site/.env.example`): `VITE_WHATSAPP` (número da loja, só dígitos; sem ele o site usa o número fictício `5511999990000`), `VITE_API_URL` (endereço da API; sem ele o site é estático e o pedido segue só pelo WhatsApp) e `VITE_BASE` (subpasta de hospedagem). Nunca coloque senhas ou chaves secretas nesse arquivo: tudo o que está nele vai para o navegador.

O resultado do build pode ser publicado de graça em Cloudflare Pages, Netlify ou GitHub Pages. Hoje o site está no Netlify, com acesso protegido por senha (ainda não é público), e já mostra a vitrine vinda da API. A publicação é manual: `npm run build` com um `site/.env.production` local, que o git ignora, e depois o deploy da pasta `site/dist/`. Detalhes, estrutura e limites conhecidos estão em [`site/README.md`](site/README.md).

## Orientação a objetos

- **Herança e polimorfismo:** `Produto` é abstrata; `Peca` e `Acessorio` herdam dela e definem `tamanhos` e `rotuloTipo`.
- **Encapsulamento:** os atributos são privados (`_nome`, `_preco`) e só mudam por get/set com validação.
- **Ocultação:** a sacola guarda os itens num mapa privado e a tela só enxerga getters e métodos.

### Demonstração no terminal

Mostra tudo isso no console (cmd, PowerShell ou terminal do VS Code), sem abrir o app: cria peças, lê os getters, tenta setters inválidos e exibe a mensagem da validação, monta uma sacola, calcula subtotais, total e itens a combinar, e imprime a mensagem do pedido. Usa as classes reais do app, que são Dart puro. Na raiz do projeto:

```bash
dart run tool/demo_terminal.dart
```

Para tirar as cores, acrescente `--sem-cor` (ou defina a variável `NO_COLOR`).

## Estrutura do código

```
lib/
  main.dart            ponto de entrada e número do WhatsApp
  core/                moeda, indicadores de vendas, resumo do catálogo, ativação em lote, App Check
  models/              Produto, Peca, Acessorio, Categoria, VarianteCor...
  services/            API, catálogo (com a cópia local), sacola, WhatsApp, dados da loja
  ui/                  telas, componentes, efeitos e rolagem suave
  ia/                  Assistente de IA
assets/                catálogo, fotos, fontes e ícone
api/                   API Node + MySQL (pedidos e painel), migrações e backup
site/                  versão para site (React)
docs/                  documentação do projeto
release/               pacote da 1.1.1 (os novos saem nas Releases)
test/                  testes automatizados do app
tool/                  demonstração no terminal (Dart puro)
.github/workflows/     CI: testes do site, da API e do app em todo PR
```

## Documentação

- [Diagrama de classes](docs/diagrama-de-classes.md): as classes do app e onde aparece cada requisito de orientação a objetos.
- [Decisões do projeto](docs/decisoes.md): o que foi escolhido e por quê.
- [Evolução futura](docs/evolucao-futura.md): o que pode vir depois.
- [Histórico de mudanças](CHANGELOG.md): o que mudou em cada versão do app e o que ainda não foi lançado no site e na API.

## Testes

```bash
flutter test                              # app (na raiz)
cd site && npm test                       # site
cd api && npm run test:unit && npm run test:migrar   # API, só com o MySQL; `npm test` exige a API no ar (veja api/COMO-RODAR.md)
```

Os três conjuntos rodam sozinhos no GitHub Actions em todo PR e em todo envio para a `main` (`.github/workflows/ci.yml`).
