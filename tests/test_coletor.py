#!/usr/bin/env python3
"""
test_coletor.py -- verifica a logica de scripts/pull_kalshi_full.py que NAO
depende de rede. Rode com:  python tests/test_coletor.py

O alvo principal e a PAGINACAO POR CURSOR: o coletor anterior fazia uma unica
chamada a /events com limit=200 e truncava em silencio acima disso. O teste
monta um servidor falso com 3 paginas e confere que as 3 sao percorridas.
"""
import json, subprocess, sys, tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import pull_kalshi_full as M

ok = True
def checa(cond, msg):
    global ok
    print(("  ok: " if cond else "  FALHOU: ") + msg)
    if not cond: ok = False

print("=== 1. paginacao por cursor percorre TODAS as paginas ===")
class ClienteFalso(M.Cliente):
    def __init__(self, paginas):
        self.paginas, self.vistos = paginas, []
        self.chamadas, self.endpoints = 0, set()
    def get(self, path, params=None, tentativas=5):
        self.chamadas += 1
        cur = (params or {}).get("cursor")
        self.vistos.append(cur)
        return self.paginas[cur]

paginas = {
    None:  {"events": [{"event_ticker": f"E{i}"} for i in range(200)], "cursor": "c1"},
    "c1":  {"events": [{"event_ticker": f"E{i}"} for i in range(200, 400)], "cursor": "c2"},
    "c2":  {"events": [{"event_ticker": "E400"}], "cursor": ""},
}
c = ClienteFalso(paginas)
res = c.paginar("/events", {"series_ticker": "KXFED", "limit": 200}, "events")
checa(len(res) == 401, f"401 eventos recuperados (obtido: {len(res)})")
checa(c.vistos == [None, "c1", "c2"], f"seguiu os cursores na ordem: {c.vistos}")
checa(c.chamadas == 3, f"3 chamadas HTTP (obtido: {c.chamadas})")
print("  (o coletor anterior teria parado em 200 e perdido 201 eventos)")

print("\n=== 2. paginacao para em pagina vazia, sem laco infinito ===")
c2 = ClienteFalso({None: {"events": [], "cursor": "x"}, "x": {"events": [], "cursor": "y"}})
checa(len(c2.paginar("/events", {}, "events")) == 0, "retorna vazio")
checa(c2.chamadas <= 2, f"nao entra em laco (chamadas: {c2.chamadas})")

print("\n=== 3. erro da API interrompe em vez de propagar lixo ===")
class ClienteErro(ClienteFalso):
    def get(self, path, params=None, tentativas=5):
        self.chamadas += 1
        return {"_erro": 403, "_msg": "requer credencial"}
c3 = ClienteErro({})
checa(c3.paginar("/x", {}, "events") == [], "devolve lista vazia em 403")

print("\n=== 4. guarda de congelamento recusa sobrescrever snapshot ===")
with tempfile.TemporaryDirectory() as td:
    import datetime as dt
    hoje = dt.datetime.now(dt.timezone.utc).date().isoformat()
    (Path(td) / f"snapshot_{hoje}").mkdir(parents=True)
    r = subprocess.run([sys.executable, "scripts/pull_kalshi_full.py", "--out", td],
                       capture_output=True, text=True)
    checa(r.returncode == 1, f"sai com codigo 1 (obtido: {r.returncode})")
    checa("ja existe" in r.stderr, "explica o motivo no stderr")
    checa("--force" in r.stderr, "aponta a saida deliberada")

print("\n=== 5. csv + sha256 + contagem ===")
with tempfile.TemporaryDirectory() as td:
    p = Path(td) / "t.csv"
    n = M.escrever_csv(p, [{"a": 1, "b": "x"}, {"a": 2, "b": "y"}], ["a", "b"])
    checa(n == 2, "escreveu 2 linhas")
    checa(len(M.sha256(p)) == 64, "sha256 com 64 hex")
    checa(M.sha256(p) == M.sha256(p), "sha256 estavel")
    n2 = M.escrever_csv(p, [{"a": 1, "b": "x", "extra": "ignorar"}], ["a", "b"])
    checa(n2 == 1 and "extra" not in p.read_text(), "campo desconhecido e ignorado")

print("\n=== 6. credencial e OPCIONAL ===")
k, kid = M.load_key({})
checa(k is None and kid is None, "sem credencial no ambiente -> segue sem assinar")
k2, _ = M.load_key({"KALSHI_API_KEY_ID": "x"})
checa(k2 is None, "id sem chave privada -> tambem segue sem assinar")

print("\n" + "=" * 44)
print("TODOS OS TESTES PASSARAM" if ok else "HOUVE FALHAS -- ver acima")
sys.exit(0 if ok else 1)
