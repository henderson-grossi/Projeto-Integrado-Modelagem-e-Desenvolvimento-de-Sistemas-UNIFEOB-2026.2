# Diagrama de classes

Este diagrama mostra as classes do app que ficam na pasta `lib/models` e `lib/services`: o que a loja vende, o que o cliente escolhe e como o catálogo chega às telas. O GitHub desenha o bloco abaixo sozinho. Se o seu visualizador não desenhar, cole o código em [mermaid.live](https://mermaid.live).

```mermaid
classDiagram
    direction TB

    class Produto {
        <<abstract>>
        +String id
        +Categoria categoria
        +String descricao
        -String _nome
        -double? _preco
        -List~String~ _fotos
        -List~VarianteCor~ _cores
        +String nome
        +double? preco
        +List~String~ fotos
        +List~VarianteCor~ cores
        +String precoFormatado
        +List~String~ tamanhos*
        +String rotuloTipo*
        +String resumo
        +Produto.fromJson(json)$ Produto
    }

    class Peca {
        -List~String~ _tamanhos
        +String? fotoCostas
        +List~String~ tamanhos
        +String rotuloTipo
    }

    class Acessorio {
        +String? material
        +List~String~ tamanhos
        +String rotuloTipo
        +String resumo
    }

    class VarianteCor {
        +String nome
        +double hue
        +int? tom
        +bool ehOriginal
        +VarianteCor.fromJson(json)$ VarianteCor
    }

    class Categoria {
        <<enumeration>>
        blusas
        vestidos
        tops
        bodys
        shorts
        acessorios
        +String rotulo
    }

    class ItemSacola {
        +Produto peca
        +String cor
        +String tamanho
        -int _quantidade
        +int quantidade
        +String chave
        +double? subtotal
        +String linhaPedido
    }

    class SacolaBase {
        -Map~String, ItemSacola~ _itens
        +List~ItemSacola~ itens
        +int quantidadeTotal
        +bool vazia
        +double total
        +bool temPrecoPendente
        +aoMudar()
        +adicionar(produto, cor, tamanho, quantidade)
        +alterarQuantidade(item, delta)
        +limpar()
        +mensagemPedido(numeroPedido) String
    }

    class Sacola {
        +aoMudar()
    }

    class ChangeNotifier {
        <<mixin do Flutter>>
    }

    class CatalogoRepository {
        <<interface>>
        +todas() List~Produto~
        +porCategoria(categoria) List~Produto~
        +buscarPorId(id) Produto?
        +fotos() List~String~
        +carregar()$ Future~CatalogoRepository~
        +obterDados(api, cache, guardar, embutido)$ Future~Map~
        +atualizarCopiaLocal()$ Future~void~
        +deJson(dados)$ CatalogoRepository
    }

    class CatalogoJson["_CatalogoJson"] {
        <<privada à biblioteca>>
        -List~Produto~ _produtos
        -Set~String~ _fotos
    }

    class WhatsAppService {
        +String numero
        +enviar(mensagem) Future~bool~
    }

    Produto <|-- Peca : herda
    Produto <|-- Acessorio : herda
    Produto "1" *-- "1..*" VarianteCor : cores
    Produto --> Categoria
    ItemSacola --> Produto : peca
    SacolaBase "1" o-- "*" ItemSacola : _itens
    SacolaBase <|-- Sacola : herda
    Sacola ..> ChangeNotifier : with
    CatalogoJson ..|> CatalogoRepository : implementa
    CatalogoRepository ..> Produto : entrega
```

`SacolaBase.mensagemPedido` monta o texto do pedido, e quem o entrega ao WhatsApp é a tela, por meio de `WhatsAppService.enviar`. Por isso as duas classes não aparecem ligadas no diagrama.

`SacolaBase` guarda as regras da sacola em Dart puro, e `Sacola` só acrescenta o aviso à tela. O filtro que recolore a foto fica na extensão `_FotoNaCor`, em `lib/ui/componentes.dart`, para que `VarianteCor` também continue em Dart puro.

## Como ler

Os sinais seguem a notação UML. `+` é público, `-` é privado e `*` marca um membro abstrato. A seta com triângulo vazio é herança, a seta tracejada com triângulo é implementação de interface, a seta tracejada simples indica uso, e o losango cheio indica que as partes só existem junto com o todo.

## Onde cada requisito de POO aparece

- Herança: `Peca` e `Acessorio` herdam de `Produto`, que é abstrata e não pode ser criada sozinha. Cada subclasse define seus `tamanhos` e seu `rotuloTipo`, e `Acessorio` ainda amplia o `resumo`. `Sacola` herda de `SacolaBase`, recebe `ChangeNotifier` com `with` e sobrescreve `aoMudar` para avisar a tela.
- Polimorfismo: as telas lidam com `Produto` e chamam `tamanhos`, `rotuloTipo` e `resumo` sem saber se o objeto é uma peça ou um acessório.
- Get e set: `nome` e `preco` só mudam pelos setters, que recusam nome vazio e preço negativo. `ItemSacola.quantidade` recusa valor menor que 1.
- Encapsulamento: os dados de `Produto` (`_nome`, `_preco`, `_fotos`, `_cores`) e o mapa de itens da `SacolaBase` (`_itens`) são privados. Quem está de fora vê só getters e listas que não podem ser alteradas.
- Ocultação de classe: `_CatalogoJson` é privada à biblioteca. As telas só enxergam a interface `CatalogoRepository` e recebem o objeto pronto por `carregar`.
- Fábrica: `Produto.fromJson` lê uma entrada do catálogo e devolve a subclasse certa.
- Composição: um `Produto` tem uma ou mais `VarianteCor`. A foto é a mesma, e cada cor é um filtro aplicado em cima dela, então uma cor nova não exige foto nova.
