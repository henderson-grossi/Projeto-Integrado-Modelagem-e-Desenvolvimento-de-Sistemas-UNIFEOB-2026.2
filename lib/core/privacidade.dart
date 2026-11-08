/// Identificação da loja: aparece no rodapé e na política de privacidade.
/// O site tem os mesmos dados em site/src/lib/formato.ts: mude os dois juntos.
const cnpjLoja = '68.647.856/0001-97';
const emailContato = 'suporte.rvlabel@gmail.com';

/// Política de privacidade (LGPD) e termos de uso, em linguagem direta.
/// Dart puro: a tela do app e o menu de terminal mostram o mesmo texto.
const blocosPrivacidade = <(String, String)>[
  ('Quem é o responsável',
      'A RV Label (CNPJ $cnpjLoja) decide como os seus dados são usados '
          'e responde por eles. Para qualquer assunto sobre seus dados, escreva para '
          '$emailContato.'),
  ('Que dados coletamos',
      'Nome e telefone para atender seu pedido. O CPF é opcional e só pedimos '
          'se você quiser nota fiscal. Não pedimos senha nem dados de cartão.'),
  ('Para que usamos',
      'Somente para registrar, separar e entregar o seu pedido e falar com você '
          'sobre ele pelo WhatsApp. Não vendemos nem compartilhamos seus dados.'),
  ('Por quanto tempo guardamos',
      'Enquanto o pedido existir ou a lei exigir (por exemplo, obrigações fiscais). '
          'Depois disso, apagamos ou tornamos os dados anônimos.'),
  ('Seus direitos (LGPD)',
      'Você pode pedir acesso, correção ou exclusão dos seus dados, e retirar o '
          'consentimento quando quiser. Escreva para $emailContato ou '
          'chame a RV Label no WhatsApp.'),
  ('Como consultar seu pedido',
      'Em "Meus pedidos" você vê o andamento informando o número do pedido e o '
          'telefone usado na compra.'),
  ('Termos de uso',
      'As peças são produzidas em pequenos lotes e as informações do app '
          '(preço, cor, tamanho) valem até o fechamento do pedido pelo WhatsApp. '
          'Trocas e devoluções seguem o Código de Defesa do Consumidor e são '
          'combinadas direto com a marca.'),
];
