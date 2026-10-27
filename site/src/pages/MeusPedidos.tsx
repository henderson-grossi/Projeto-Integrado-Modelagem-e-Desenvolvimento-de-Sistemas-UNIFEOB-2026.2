import { AlertCircle, Check, X } from "lucide-react";
import { useState, type FormEvent } from "react";
import { useTitulo } from "@/hooks/useTitulo";
import { API_URL, ApiErro, consultarPedido, type PedidoConsultado } from "@/lib/api";
import { formatarReais, formatarTelefone, soDigitos } from "@/lib/formato";

const ETAPAS = ["Recebido", "Em separação", "Enviado", "Entregue"];
/** Cancelado e devolvido encerram o pedido: aparecem como uma etapa só, em vermelho. */
const ENCERRADOS = ["Cancelado", "Devolvido"];

/** Cor de cada status, a mesma do RvStatusBadge do app (texto na cor, fundo da cor a 15%). */
const COR_STATUS: Record<string, string> = {
  Recebido: "text-info bg-info/15",
  "Em separação": "text-aviso bg-aviso/15",
  Enviado: "text-sucesso bg-sucesso/15",
  Entregue: "text-sucesso bg-sucesso/15",
  Devolvido: "text-perigo bg-perigo/15",
  Cancelado: "text-perigo bg-perigo/15",
};
const COR_PONTO: Record<string, string> = {
  Recebido: "bg-info",
  "Em separação": "bg-aviso",
  Enviado: "bg-sucesso",
  Entregue: "bg-sucesso",
};

/** O cliente acompanha o andamento com o número do pedido e o telefone usado na compra. */
export default function MeusPedidos() {
  useTitulo("Meus pedidos");
  const [carregando, setCarregando] = useState(false);
  const [erro, setErro] = useState<string | null>(null);
  const [pedido, setPedido] = useState<PedidoConsultado | null>(null);

  async function buscar(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const f = new FormData(e.currentTarget);
    const id = Number(soDigitos(String(f.get("numero") ?? "")));
    const telefone = soDigitos(String(f.get("telefone") ?? ""));
    setPedido(null);
    if (!id || telefone.length < 10) return setErro("Informe o número do pedido e o telefone com DDD.");
    setErro(null);
    setCarregando(true);
    try {
      setPedido(await consultarPedido(id, telefone));
    } catch (err) {
      setErro(err instanceof ApiErro ? err.message : "Sem conexão com o servidor. Tente de novo.");
    } finally {
      setCarregando(false);
    }
  }

  const atual = pedido ? ETAPAS.indexOf(pedido.status) : -1;
  const data = pedido?.data ? new Date(pedido.data) : null;
  const dataTexto = data && !Number.isNaN(data.getTime()) ? data.toLocaleDateString("pt-BR") : null;

  return (
    <div className="mx-auto max-w-[520px] px-6 pb-8 pt-36">
      <h1 className="text-[40px]">Meus pedidos</h1>
      {!API_URL ? (
        <p className="mt-6 leading-relaxed text-suave">
          A consulta de pedidos fica disponível quando o servidor da loja estiver conectado ao site. Enquanto isso, fale com a
          RV Label pelo WhatsApp.
        </p>
      ) : (
        <>
          <p className="mt-4 text-suave">Use o número do pedido (enviado no WhatsApp) e o telefone que você informou na compra.</p>
          <form onSubmit={buscar} noValidate className="mt-6 space-y-4">
            <label className="block">
              <span className="rotulo">Número do pedido</span>
              <input
                name="numero"
                inputMode="numeric"
                placeholder="Ex.: 128"
                className="campo"
                onInput={(e) => (e.currentTarget.value = soDigitos(e.currentTarget.value))}
              />
            </label>
            <label className="block">
              <span className="rotulo">Telefone (com DDD)</span>
              <input
                name="telefone"
                inputMode="tel"
                autoComplete="tel"
                placeholder="(11) 99999-9999"
                className="campo"
                // shortcut: o cursor vai para o fim a cada dígito (como no app); calcular a posição se incomodar.
                onInput={(e) => (e.currentTarget.value = formatarTelefone(e.currentTarget.value))}
              />
            </label>
            <button type="submit" disabled={carregando} className="btn-cheio w-full">
              {carregando && <span aria-hidden className="h-4 w-4 animate-spin rounded-full border-2 border-white/40 border-t-white" />}
              {carregando ? "Consultando…" : "Consultar"}
            </button>
          </form>
          {erro && (
            <p role="alert" className="mt-5 flex items-start gap-2 text-perigo">
              <AlertCircle className="mt-0.5 h-[18px] w-[18px] shrink-0" aria-hidden />
              {erro}
            </p>
          )}

          {pedido && (
            <section className="cartao mt-8 p-6" aria-live="polite">
              <div className="flex items-center justify-between gap-3">
                <h2 className="text-[28px]">Pedido nº {pedido.id}</h2>
                <span className={`rounded-full px-3 py-1 text-xs font-semibold ${COR_STATUS[pedido.status] ?? "bg-elevado text-suave"}`}>
                  {pedido.status}
                </span>
              </div>

              <ol className="mt-6">
                {ENCERRADOS.includes(pedido.status) ? (
                  <Etapa rotulo={pedido.status} feita atual ultima cor="bg-perigo" icone={<X className="h-3.5 w-3.5" />} />
                ) : (
                  ETAPAS.map((etapa, i) => (
                    <Etapa
                      key={etapa}
                      rotulo={etapa}
                      data={i === 0 ? dataTexto : null}
                      feita={i <= atual}
                      atual={i === atual}
                      ultima={i === ETAPAS.length - 1}
                      cor={COR_PONTO[etapa]}
                    />
                  ))
                )}
              </ol>

              <hr className="my-6 border-linha" />
              <ul className="space-y-2">
                {pedido.itens.map((i, k) => (
                  <li key={k} className="flex items-start justify-between gap-3">
                    <span>
                      {i.quantidade}× {i.nome}
                      <span className="block text-sm text-suave">{i.cor} · {i.tamanho}</span>
                    </span>
                    <span className="shrink-0 whitespace-nowrap tabular-nums">{i.subtotal == null ? "a combinar" : formatarReais(i.subtotal)}</span>
                  </li>
                ))}
              </ul>
              <p className="mt-4 flex items-baseline justify-between gap-3">
                Total
                <span className="preco text-right text-xl">
                  {formatarReais(pedido.total)}
                  {pedido.precoPendente && <span className="text-sm font-normal text-suave"> + itens a combinar</span>}
                </span>
              </p>
            </section>
          )}
        </>
      )}
    </div>
  );
}

/** Uma etapa da linha do tempo: ponto (cheio se já passou), linha até a próxima, nome e data. */
function Etapa(props: {
  rotulo: string;
  cor: string;
  feita?: boolean;
  atual?: boolean;
  ultima?: boolean;
  data?: string | null;
  icone?: React.ReactNode;
}) {
  const { rotulo, cor, feita, atual, ultima, data, icone = <Check className="h-3.5 w-3.5" /> } = props;
  return (
    <li className="flex gap-3" aria-current={atual ? "step" : undefined}>
      <div className="flex w-6 flex-col items-center">
        <span
          aria-hidden
          className={`grid h-6 w-6 shrink-0 place-items-center rounded-full border-2 text-preto ${feita ? `${cor} border-transparent` : "border-linha"}`}
        >
          {feita && icone}
        </span>
        {!ultima && <span aria-hidden className={`w-0.5 flex-1 ${feita ? `${cor} opacity-50` : "bg-linha"}`} />}
      </div>
      <div className={ultima ? "" : "pb-6"}>
        <p className={`${atual ? "font-bold" : "font-medium"} ${feita ? "text-texto" : "text-mudo"}`}>
          {rotulo}
          {!feita && <span className="sr-only"> (ainda não)</span>}
        </p>
        {data && <p className="text-sm text-suave">{data}</p>}
      </div>
    </li>
  );
}
