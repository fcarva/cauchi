#!/usr/bin/env python3
"""
pull_kalshi_full.py -- coleta completa da API da Kalshi para a Lista 01.

O QUE ESTE SCRIPT CORRIGE em relacao a scripts/pull_kalshi_trades.py:

  1. PAGINACAO DE EVENTOS. O anterior fazia UMA chamada a /events com
     limit=200 e nenhum cursor: acima de 200 eventos ele truncava em silencio.
  2. METADADOS DE LIQUIDACAO. O anterior nao gravava close_time,
     expiration_time, status, result nem settlement. Sem isso nao da para saber
     se um contrato JA RESOLVEU -- foi exatamente essa a origem do bug em que
     `expiry <- max(date)` tratava a data do snapshot como se fosse a reuniao.
     Com `markets.csv` o horizonte ate a resolucao (tau) passa a ser real.
  3. CANDLESTICKS. O anterior so puxava trades; o caminho de candlesticks vivia
     em R/00_pull_kalshi.R, com outra convencao. Aqui sai tudo junto.
  4. CREDENCIAL OPCIONAL. Leitura de dados de mercado na Kalshi e publica. O
     anterior exigia chave para tudo. Aqui a assinatura so e usada se houver
     credencial no ambiente, e o script diz o que conseguiu sem ela.
  5. SNAPSHOT DATADO E IMUTAVEL. Grava em data/raw/snapshot_AAAA-MM-DD/ e se
     RECUSA a sobrescrever. O snapshot ja entregue continua valendo.
  6. MANIFESTO. manifest.json com timestamp UTC, endpoints usados, contagem de
     linhas e sha256 de cada arquivo. E o que torna a coleta auditavel.
  7. RETOMADA. Checkpoint por mercado: uma coleta interrompida continua de onde
     parou em vez de recomecar.
  8. BACKOFF. Respeita Retry-After em 429 e recua exponencialmente em 5xx.

USO
    python scripts/pull_kalshi_full.py                    # KXFED, tudo
    python scripts/pull_kalshi_full.py --series KXFED KXFEDDECISION
    python scripts/pull_kalshi_full.py --no-trades        # so candlesticks
    python scripts/pull_kalshi_full.py --resume           # continua um snapshot

CREDENCIAL (opcional). Ponha em .env, NUNCA no repositorio:
    KALSHI_API_KEY_ID=...
    KALSHI_PRIVATE_KEY_PATH=caminho/para/chave.pem
"""
from __future__ import annotations

import argparse
import base64
import csv
import datetime as dt
import hashlib
import json
import sys
import time
from pathlib import Path

import requests

BASE_URL = "https://api.elections.kalshi.com"
API = "/trade-api/v2"
UA = "PPGEco-UFES-Econometria-II/1.0 (uso academico)"


# ----------------------------------------------------------------- credencial
def load_env(path: Path = Path(".env")) -> dict:
    env = {}
    if path.exists():
        lines = path.read_text(encoding="utf-8").splitlines()
        index = 0
        while index < len(lines):
            line = lines[index].strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                k, v = k.strip(), v.strip().strip('"').strip("'")
                if k in {"KALSHI_PRIVATE_KEY", "KALSHI_PRIVATE_KEY_PEM"} and "BEGIN " in v:
                    block = [v]
                    index += 1
                    while index < len(lines):
                        block.append(lines[index].strip())
                        if "END " in lines[index]:
                            break
                        index += 1
                    v = "\n".join(block) + "\n"
                env[k] = v
            index += 1
    return env


def load_key(env: dict):
    """Devolve (private_key, key_id) ou (None, None). Credencial e OPCIONAL."""
    key_id = env.get("KALSHI_API_KEY_ID") or env.get("KALSHI_KEYID")
    pem_path = env.get("KALSHI_PRIVATE_KEY_PATH")
    pem_inline = env.get("KALSHI_PRIVATE_KEY_PEM") or env.get("KALSHI_PRIVATE_KEY")
    if not key_id or not (pem_path or pem_inline):
        return None, None
    try:
        from cryptography.hazmat.primitives import serialization
    except ImportError:
        print("[aviso] pacote 'cryptography' ausente: seguindo sem assinatura.")
        return None, None
    data = Path(pem_path).read_bytes() if pem_path else pem_inline.encode()
    return serialization.load_pem_private_key(data, password=None), key_id


def sign_headers(key, key_id, method: str, path: str) -> dict:
    from cryptography.hazmat.primitives import hashes
    from cryptography.hazmat.primitives.asymmetric import padding

    ts = str(int(time.time() * 1000))
    msg = (ts + method + path).encode()
    sig = key.sign(
        msg,
        padding.PSS(mgf=padding.MGF1(hashes.SHA256()),
                    salt_length=padding.PSS.DIGEST_LENGTH),
        hashes.SHA256(),
    )
    return {
        "KALSHI-ACCESS-KEY": key_id,
        "KALSHI-ACCESS-SIGNATURE": base64.b64encode(sig).decode(),
        "KALSHI-ACCESS-TIMESTAMP": ts,
    }


# ------------------------------------------------------------------- transporte
class Cliente:
    def __init__(self, key=None, key_id=None, pausa: float = 0.15):
        self.s = requests.Session()
        self.s.headers.update({"User-Agent": UA, "Accept": "application/json"})
        self.key, self.key_id, self.pausa = key, key_id, pausa
        self.chamadas = 0
        self.endpoints = set()

    def get(self, path: str, params: dict | None = None, tentativas: int = 5):
        headers = {}
        if self.key:
            headers = sign_headers(self.key, self.key_id, "GET", path)
        for t in range(tentativas):
            try:
                r = self.s.get(BASE_URL + path, headers=headers, params=params, timeout=60)
            except requests.RequestException as e:
                if t == tentativas - 1:
                    raise
                time.sleep(2 ** t)
                continue
            self.chamadas += 1
            if r.status_code == 200:
                self.endpoints.add(path.split("?")[0])
                time.sleep(self.pausa)
                return r.json()
            if r.status_code == 429:                    # respeita Retry-After
                espera = float(r.headers.get("Retry-After", 2 ** t))
                print(f"    [429] aguardando {espera:.0f}s")
                time.sleep(espera)
                continue
            if r.status_code in (401, 403):
                return {"_erro": r.status_code, "_msg": "requer credencial"}
            if 500 <= r.status_code < 600:
                time.sleep(2 ** t)
                continue
            return {"_erro": r.status_code, "_msg": r.text[:200]}
        return {"_erro": "esgotou_tentativas"}

    def paginar(self, path: str, params: dict, chave: str, teto: int = 100000):
        """Percorre TODAS as paginas via cursor. O coletor anterior nao fazia isto."""
        saida, cursor, paginas = [], None, 0
        while True:
            p = dict(params)
            if cursor:
                p["cursor"] = cursor
            data = self.get(path, p)
            if not isinstance(data, dict) or "_erro" in data:
                break
            lote = data.get(chave) or []
            saida.extend(lote)
            paginas += 1
            cursor = data.get("cursor")
            if not cursor or not lote or len(saida) >= teto:
                break
        return saida


# ------------------------------------------------------------------- utilidades
# Cobertura por coluna de cada arquivo escrito, para entrar no manifesto.
COBERTURA: dict[str, dict[str, int]] = {}


def escrever_csv(caminho: Path, linhas: list[dict], campos: list[str]) -> int:
    caminho.parent.mkdir(parents=True, exist_ok=True)
    with caminho.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=campos, extrasaction="ignore")
        w.writeheader()
        for l in linhas:
            w.writerow(l)
    COBERTURA[caminho.name] = {
        c: sum(1 for l in linhas if l.get(c) not in (None, "")) for c in campos
    }
    return len(linhas)


def conferir_cobertura(nome: str, essenciais: list[str], total: int) -> None:
    """Avisa quando um arquivo sai sintaticamente valido mas sem conteudo util.

    A API ja devolveu candlesticks cujos sub-objetos price/yes_bid/yes_ask vinham
    ausentes: 32.120 linhas gravadas com ticker e timestamp e absolutamente mais
    nada. O CSV passava em qualquer checagem de formato, o sha256 batia, e o
    problema so aparecia horas depois, no R, como um painel vazio. Contar o
    preenchimento aqui e o que transforma isso em erro visivel na coleta.
    """
    cob = COBERTURA.get(nome, {})
    presentes = {c: cob.get(c, 0) for c in essenciais if cob.get(c, 0) > 0}
    if total and not presentes:
        print(f"  !! ATENCAO: {nome} tem {total} linhas e NENHUMA das colunas "
              f"essenciais preenchida ({', '.join(essenciais)}).")
        print("     O arquivo e inutilizavel como fonte de preco. A cobertura por "
              "coluna esta registrada no manifesto.")
    elif total:
        pior = min(presentes.values())
        print(f"  cobertura: {len(presentes)}/{len(essenciais)} colunas essenciais "
              f"preenchidas; a menos preenchida cobre {pior}/{total} linhas "
              f"({100 * pior / total:.1f}%).")


def sha256(caminho: Path) -> str:
    h = hashlib.sha256()
    with caminho.open("rb") as f:
        for bloco in iter(lambda: f.read(1 << 20), b""):
            h.update(bloco)
    return h.hexdigest()


# ------------------------------------------------------------------------ main
def main() -> int:
    ap = argparse.ArgumentParser(description="Coleta completa da API da Kalshi.")
    ap.add_argument("--series", nargs="+", default=["KXFED"])
    ap.add_argument("--out", default="data/raw")
    ap.add_argument("--days-back", type=int, default=400)
    ap.add_argument("--no-trades", action="store_true")
    ap.add_argument("--no-candles", action="store_true")
    ap.add_argument("--resume", action="store_true")
    ap.add_argument("--force", action="store_true")
    a = ap.parse_args()

    hoje = dt.datetime.now(dt.timezone.utc).date().isoformat()
    destino = Path(a.out) / f"snapshot_{hoje}"
    if destino.exists() and not (a.resume or a.force):
        print(f"ERRO: '{destino}' ja existe.\n"
              f"  Os dados da Kalshi sao VIVOS: re-puxar muda os numeros do relatorio.\n"
              f"  Use --resume para continuar uma coleta interrompida, ou --force\n"
              f"  para descongelar de proposito (e entao recommite TUDO).", file=sys.stderr)
        return 1
    destino.mkdir(parents=True, exist_ok=True)
    ckpt = destino / "_checkpoint.json"
    feitos = set(json.loads(ckpt.read_text())) if (a.resume and ckpt.exists()) else set()

    key, key_id = load_key(load_env())
    cli = Cliente(key, key_id)
    print(f"Snapshot: {destino}")
    print(f"Assinatura: {'ativa' if key else 'AUSENTE (leitura publica apenas)'}")

    # --- mercados e metadados (o que faltava) --------------------------------
    mercados: list[dict] = []
    for s in a.series:
        eventos = cli.paginar(f"{API}/events",
                              {"series_ticker": s, "with_nested_markets": "true", "limit": 200},
                              "events")
        print(f"[{s}] {len(eventos)} eventos")
        for ev in eventos:
            for mk in ev.get("markets", []) or []:
                mk["_series_ticker"] = s
                mk["_event_ticker"] = ev.get("event_ticker")
                mercados.append(mk)
        # /markets tambem, para apanhar mercados nao aninhados
        for mk in cli.paginar(f"{API}/markets", {"series_ticker": s, "limit": 1000}, "markets"):
            mk["_series_ticker"] = s
            mk["_event_ticker"] = mk.get("event_ticker")
            mercados.append(mk)

    vistos, unicos = set(), []
    for mk in mercados:
        t = mk.get("ticker")
        if t and t not in vistos:
            vistos.add(t)
            unicos.append(mk)
    campos_mk = ["ticker", "_event_ticker", "_series_ticker", "title", "yes_sub_title",
                 "subtitle", "status", "open_time", "close_time", "expiration_time",
                 "expected_expiration_time", "result", "settlement_value",
                 "last_price", "previous_price", "volume", "open_interest",
                 "yes_bid", "yes_ask", "liquidity", "strike_type", "floor_strike", "cap_strike"]
    n_mk = escrever_csv(destino / "markets.csv", unicos, campos_mk)
    print(f"markets.csv: {n_mk} mercados (com close_time, result e settlement)")
    if not n_mk:
        print("ERRO: nenhum mercado. Confira o series_ticker.", file=sys.stderr)
        return 1

    tickers = sorted(vistos)
    fim = int(time.time())
    ini = fim - a.days_back * 86400

    # --- candlesticks ---------------------------------------------------------
    if not a.no_candles:
        linhas, campos = [], ["ticker", "end_period_ts", "open_ts", "price_open", "price_high",
                              "price_low", "price_close", "price_mean", "yes_bid_close",
                              "yes_ask_close", "volume", "open_interest"]
        for i, tk in enumerate(tickers, 1):
            chave = f"candles::{tk}"
            if chave in feitos:
                continue
            serie = next((m["_series_ticker"] for m in unicos if m["ticker"] == tk), a.series[0])
            q = {"start_ts": ini, "end_ts": fim, "period_interval": 1440}
            d = cli.get(f"{API}/series/{serie}/markets/{tk}/candlesticks", q)
            cs = d.get("candlesticks") if isinstance(d, dict) else None
            if not cs:                                    # fallback historico
                d = cli.get(f"{API}/historical/markets/{tk}/candlesticks", q)
                cs = d.get("candlesticks") if isinstance(d, dict) else None
            for c in (cs or []):
                pr, yb, ya = c.get("price") or {}, c.get("yes_bid") or {}, c.get("yes_ask") or {}
                linhas.append({
                    "ticker": tk, "end_period_ts": c.get("end_period_ts"),
                    "open_ts": c.get("open_ts"),
                    "price_open": pr.get("open"), "price_high": pr.get("high"),
                    "price_low": pr.get("low"), "price_close": pr.get("close"),
                    "price_mean": pr.get("mean"),
                    "yes_bid_close": yb.get("close"), "yes_ask_close": ya.get("close"),
                    "volume": c.get("volume"), "open_interest": c.get("open_interest")})
            feitos.add(chave)
            if i % 10 == 0:
                ckpt.write_text(json.dumps(sorted(feitos)))
                print(f"  candles {i}/{len(tickers)} -- {len(linhas)} linhas")
        n_cd = escrever_csv(destino / "candlesticks.csv", linhas, campos)
        print(f"candlesticks.csv: {n_cd} linhas")
        conferir_cobertura("candlesticks.csv",
                           ["price_close", "price_mean", "yes_bid_close", "yes_ask_close"], n_cd)

    # --- trades ---------------------------------------------------------------
    if not a.no_trades:
        linhas, ids = [], set()
        campos = ["trade_id", "ticker", "created_time", "count", "count_fp",
                  "yes_price", "no_price", "yes_price_dollars", "no_price_dollars", "taker_side"]
        for i, tk in enumerate(tickers, 1):
            chave = f"trades::{tk}"
            if chave in feitos:
                continue
            for ep in (f"{API}/markets/trades", f"{API}/historical/trades"):
                for tr in cli.paginar(ep, {"ticker": tk, "limit": 1000}, "trades"):
                    tid = tr.get("trade_id")
                    if tid and tid not in ids:
                        ids.add(tid)
                        tr.setdefault("ticker", tk)
                        linhas.append(tr)
            feitos.add(chave)
            if i % 10 == 0:
                ckpt.write_text(json.dumps(sorted(feitos)))
                print(f"  trades {i}/{len(tickers)} -- {len(linhas)} negocios")
        n_tr = escrever_csv(destino / "trades.csv", linhas, campos)
        print(f"trades.csv: {n_tr} negocios")
        conferir_cobertura("trades.csv",
                           ["yes_price_dollars", "yes_price", "count_fp", "count"], n_tr)

    # --- manifesto ------------------------------------------------------------
    arquivos = {}
    for p in sorted(destino.glob("*.csv")):
        with p.open(encoding="utf-8") as f:
            n = sum(1 for _ in f) - 1
        arquivos[p.name] = {"linhas": n, "bytes": p.stat().st_size, "sha256": sha256(p)}
        if p.name in COBERTURA:
            # Quantas linhas trazem cada coluna preenchida. Sem isto, um CSV com
            # colunas inteiramente vazias e indistinguivel de um CSV integro:
            # linhas, bytes e sha256 batem nos dois casos.
            arquivos[p.name]["cobertura_colunas"] = COBERTURA[p.name]
    (destino / "manifest.json").write_text(json.dumps({
        "coletado_em_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
        "series": a.series, "days_back": a.days_back,
        "assinatura_usada": bool(key),
        "chamadas_http": cli.chamadas,
        "endpoints": sorted(cli.endpoints),
        "arquivos": arquivos,
    }, indent=2, ensure_ascii=False), encoding="utf-8")
    if ckpt.exists():
        ckpt.unlink()

    print(f"\nOK. {cli.chamadas} chamadas HTTP. Manifesto em {destino/'manifest.json'}")
    print("Commite o snapshot INTEIRO, manifesto incluso, como um novo snapshot datado.")
    print("NAO apague o anterior: o relatorio ja entregue depende dele.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
