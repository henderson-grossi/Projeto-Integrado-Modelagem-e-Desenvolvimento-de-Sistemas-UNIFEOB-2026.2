# Histórico de mudanças

Segue o formato do [Keep a Changelog](https://keepachangelog.com/pt-BR/1.1.0/). As versões `1.x` são as do **aplicativo**
(releases do GitHub). O site e a API ainda não têm versão própria e ficam em "Não lançado".

## Não lançado

### Site (`site/`)
- Versão para site da loja, em React: vitrine, página de cada peça, sacola, "Meus pedidos", Sobre, Contato e Privacidade.
- Rolagem suave do mouse, transição de foto entre a vitrine e a peça, e "linha de tinta" animada nas opções do cabeçalho.
- Landing page com o resumo da coleção por categoria e o guia "Antes de escolher" (tamanhos, cores, preços, atendimento).
- A vitrine vem da API, como no app: só aparece o que a administradora ativou no painel. A última lista recebida fica
  guardada no navegador para quando a API não responder; sem ela, e sem API, vale o `catalogo.json`.
- Privacidade com identificação do responsável (CNPJ) e e-mail de contato para pedidos sobre os dados (LGPD); CNPJ e e-mail
  também no rodapé. Vale para o site e para o app (tela de privacidade e rodapé iguais nos dois).
- Sem deslocamento de layout ao carregar (CLS 0 na home e na loja), nomes acessíveis dos cartões corrigidos, `robots.txt`
  e pré-carregamento do catálogo. Lighthouse no celular: acessibilidade, boas práticas e SEO em 100.
- Visual do DESIGN.md igual ao app 1.3.0: tokens de cor e raio, Manrope no texto, botões em vermelho da marca, campos com
  contorno e pílulas de escolha.
- Loja com filtros de tamanho, cor, preço e ordenação (guardados na URL) e "Limpar filtros" quando nada aparece; a barra de
  categorias fica presa sob o cabeçalho ao rolar e, ao trocar de categoria lá embaixo, a página volta ao começo da lista.
- Peça com miniaturas de frente/costas e foto em tela cheia com zoom; cartões com borda e brilho vermelhos no hover.
- Máscaras de telefone e CPF, resumo da sacola em cartão (lateral no desktop, preso embaixo no celular) e "Meus pedidos" com
  selo de status colorido e linha do tempo.
- Cartões cinzas (skeleton) no lugar da grade e da peça enquanto o catálogo carrega.

### API (`api/`)
- API em Node + MySQL na pasta própria, sem o `.env` (a chave nunca vai para o GitHub).
- **Segurança:** a consulta "Meus pedidos" não pode mais ser enganada por um pedido com o mesmo CPF e outro telefone: o nome e
  o telefone ficam gravados no próprio pedido e o cadastro da cliente nunca é reescrito por um pedido anônimo.
- Limite de requisições por IP nas rotas públicas de pedido (erro 429), `TRUST_PROXY` para uso atrás de proxy, cabeçalhos
  seguros, `Cache-Control: no-store` em `/pedidos` e `/admin`, e limites de tamanho (nome, itens, quantidade).
- `GET /saude` para monitoramento, `npm run backup` (mysqldump com rodízio, fora do git) e `npm run migrar` (migrações
  numeradas em `migracoes/`, anotadas em `schema_migracoes`).
- A senha da administradora precisa ter 10+ caracteres e não pode conter o e-mail nem palavras comuns.
- A mensagem de peça indisponível mostra o nome da peça, não o código interno.
- A migração `001` guarda nome e telefone no pedido e tira a máscara do telefone das clientes (`(35) 99999-9999` vira
  `35999999999`); sem isso os pedidos antigos não apareciam na consulta.

### Projeto
- CI no GitHub Actions: testes do site, da API (com MySQL) e do app em todo PR.
- `README` com a seção do site e do catálogo desativado; este `CHANGELOG`.
- O `.gitignore` da raiz deixou de ser versionado (os de `android/`, `api/`, `ios/`, `site/` e `windows/` continuam).

## 1.3.0 — 2026-10-16
- Visual novo seguindo o `docs/DESIGN.md` (editorial escuro): fundo quase preto, vermelho da marca só em botões, seleção e
  destaques, títulos em DM Serif Display e corpo em Manrope (embutida, licença OFL). Cores, espaços, cantos e tempos de
  animação viraram tokens (`RvColors`, `RvSpace`, `RvRadius`, `RvMotion`, `RvText`) em `lib/ui/tema.dart`.
- Componentes comuns: botão com estado "carregando", selo de status do pedido, estado vazio, bloco de carregamento com
  brilho e campo com rótulo acima e erro abaixo.
- Início: hero de tela cheia com um só botão, "Ver coleção".
- Coleção: barra de filtros que fica presa no topo ao rolar, com categoria, tamanho, cor, faixa de preço, ordem e a
  contagem de peças; sem resultado, aparece "Nenhuma peça com esses filtros" com "Limpar filtros".
- Peça: miniaturas de frente e costas e foto em tela cheia com zoom (pinça ou roda do mouse).
- Sacola: máscara de telefone `(11) 99999-9999` e CPF `000.000.000-00`, resumo fixo (à direita no desktop) e confirmação
  com o número do pedido antes de abrir o WhatsApp.
- Meus pedidos: linha do tempo do status com cores (Recebido, Em separação, Enviado; Cancelado em vermelho).
- Assistente: balões novos, indicador "digitando…" e sugestões rápidas.
- Área administrativa: busca e filtros (na loja/desativados, categoria) nos produtos, status colorido nos pedidos,
  estoque de até 2 unidades em amarelo e carregamento com blocos no lugar do círculo.
- Com "reduzir movimento" ligado no sistema, o fundo líquido deixa de reagir ao mouse e ao toque.
- Regras de negócio, chamadas à API, cálculo do total e mensagem do WhatsApp não mudaram.

## 1.2.2 — 2026-10-16
- O app de Windows conversa com o servidor da loja na internet (`https://rvlabel-api.onrender.com`, API no Render e banco no
  Aiven), em vez de procurar a API em `localhost:3000`: peças, pedidos, "Meus pedidos" e a área administrativa funcionam sem
  servidor local. No plano grátis, a primeira chamada depois de um tempo parado pode levar cerca de 50 segundos.
- Identificador definitivo do app: `br.com.rvlabel.app` (Android, iOS e Windows); nas propriedades do `.exe`, a empresa
  aparece como "RV Label".
- API: conexão TLS com o banco hospedado (`DB_SSL_CA`), `render.yaml` com o serviço e passo a passo de hospedagem em
  `api/COMO-RODAR.md`. CI: build do APK Android em todo PR.

## 1.2.1 — 2026-10-13
- O que a administradora ativou fica salvo: o app guarda uma cópia do catálogo ativo no aparelho e, sem o servidor, mostra
  essa cópia (antes abria com a vitrine vazia). A cópia é atualizada a cada abertura com o servidor ligado e a cada mudança
  no painel.
- Painel de produtos: "Selecionar vários", com "Selecionar todos", para ativar ou desativar várias peças de uma vez; o aviso
  conta quantas mudaram, quantas já estavam assim e quantas deram erro.
- Corrigido o erro "setState() callback argument returned a Future" ao recarregar as listas do painel (só aparecia em modo de
  depuração).

## 1.2.0 — 2026-10-13
- O catálogo vem todo desativado: a administradora decide o que aparece no app pelo painel.
- O app ganhou as mesmas peças de interface que o site já tinha: vitrine em lista com a foto ao passar o mouse (com
  alternância Vitrine | Grade), índice por categoria ("Tudo o que a Essence tem hoje"), guia "Antes de escolher",
  "Você também pode gostar" na página da peça e a linha de tinta animada no cabeçalho.
- Privacidade com identificação do responsável (CNPJ) e e-mail de contato, e CNPJ e e-mail no rodapé.
- Diferença conhecida em relação ao site: lá, abrir uma peça da vitrine abre um detalhe em tela cheia com a foto se
  expandindo; no app, abre a página da peça, com a foto voando do cartão (Hero) até ela.

## 1.1.1 — 2026-10-10
- Ícone novo do aplicativo: o letreiro RV·LABEL, em Windows, Android, iOS e web.
- Pacote do app para Windows (`.zip`), com as bibliotecas do Visual C++ incluídas. Ainda sem assinatura digital.

## 1.1.0 — 2026-10-10
- O catálogo ignora uma peça com categoria desconhecida em vez de quebrar.
- Painel da administradora: mostra o motivo real do erro em vez de "Sem conexão" genérico.
- Indicadores de vendas e rolagem suave no painel.
- Loja do app com Sobre, Contato, coleções, novidades e efeitos de rolagem.

## Primeira versão do app, antes da 1.1.0 — 2026-10-09
Sem tag nem release no GitHub.
- App RV Label: loja com animações, área administrativa oculta, pedidos e assistente.
- Documentação: diagrama de classes, decisões do projeto e evolução futura.
