"""Download complete KXFED trade history from Kalshi."""

import base64
import os
import re
import time
from pathlib import Path

import requests
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

BASE_URL = "https://api.elections.kalshi.com"
API_PREFIX = "/trade-api/v2"
SERIES_TICKER = "KXFED"
OUTPUT = Path("data/raw/kalshi_fed_trades.csv")


def load_env_file(path=Path(".env")):
    lines = path.read_text(encoding="utf-8").splitlines()
    values = {}
    index = 0
    while index < len(lines):
        line = lines[index].strip()
        if not line or line.startswith("#") or "=" not in line:
            index += 1
            continue
        name, value = line.split("=", 1)
        name = name.strip()
        value = value.strip().strip('"').strip("'")
        if name == "KALSHI_PRIVATE_KEY" and "BEGIN " in value:
            block = [value]
            index += 1
            while index < len(lines):
                block.append(lines[index].strip())
                if "END " in lines[index]:
                    break
                index += 1
            value = "\n".join(block) + "\n"
        values[name] = value
        index += 1
    return values


def sign_request(private_key, method, path):
    timestamp = str(int(time.time() * 1000))
    message = (timestamp + method + path.split("?", 1)[0]).encode("utf-8")
    signature = private_key.sign(
        message,
        padding.PSS(
            mgf=padding.MGF1(hashes.SHA256()),
            salt_length=padding.PSS.DIGEST_LENGTH,
        ),
        hashes.SHA256(),
    )
    return timestamp, base64.b64encode(signature).decode("ascii")


def request_json(session, private_key, key_id, path, params=None):
    timestamp, signature = sign_request(private_key, "GET", path)
    headers = {
        "Content-Type": "application/json",
        "KALSHI-ACCESS-KEY": key_id,
        "KALSHI-ACCESS-SIGNATURE": signature,
        "KALSHI-ACCESS-TIMESTAMP": timestamp,
    }
    response = session.get(BASE_URL + path, headers=headers, params=params, timeout=60)
    response.raise_for_status()
    return response.json()


def paginate_trades(session, private_key, key_id, path, ticker):
    rows = []
    cursor = None
    while True:
        params = {"ticker": ticker, "limit": 1000}
        if cursor:
            params["cursor"] = cursor
        payload = request_json(session, private_key, key_id, path, params)
        rows.extend(payload.get("trades", []))
        cursor = payload.get("cursor")
        if not cursor:
            return rows
        time.sleep(0.1)


def main():
    env = load_env_file()
    key_id = env.get("KALSHI_KEYID") or env.get("KALSHI_API_KEY_ID")
    private_key_text = env.get("KALSHI_PRIVATE_KEY", "")
    if not key_id or not private_key_text:
        raise RuntimeError(".env precisa de KALSHI_KEYID e KALSHI_PRIVATE_KEY")
    private_key = serialization.load_pem_private_key(
        private_key_text.encode("utf-8"), password=None
    )

    session = requests.Session()
    events = request_json(
        session,
        private_key,
        key_id,
        f"{API_PREFIX}/events",
        {"series_ticker": SERIES_TICKER, "with_nested_markets": "true", "limit": 200},
    ).get("events", [])
    markets = {
        market.get("ticker")
        for event in events
        for market in event.get("markets", [])
        if market.get("ticker")
    }
    if not markets:
        raise RuntimeError(f"Nenhum mercado encontrado para {SERIES_TICKER}")

    rows = []
    for number, ticker in enumerate(sorted(markets), 1):
        print(f"[{number}/{len(markets)}] {ticker}")
        for endpoint in (f"{API_PREFIX}/historical/trades", f"{API_PREFIX}/markets/trades"):
            rows.extend(paginate_trades(session, private_key, key_id, endpoint, ticker))
        time.sleep(0.1)

    unique = {}
    for row in rows:
        trade_id = row.get("trade_id")
        if trade_id:
            unique[trade_id] = row
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    import csv

    fields = [
        "trade_id",
        "ticker",
        "created_time",
        "count_fp",
        "yes_price_dollars",
        "no_price_dollars",
        "taker_side",
    ]
    with OUTPUT.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields)
        writer.writeheader()
        writer.writerows({field: row.get(field) for field in fields} for row in unique.values())
    print(f"OK: {len(unique)} trades em {OUTPUT}")


if __name__ == "__main__":
    main()
