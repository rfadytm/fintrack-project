import { useEffect, useState } from "react";
import { api } from "../utils/api";

// B12: in-memory cache TTL 30 detik (tanpa library). Mencegah re-fetch tiap navigate.
const cache = new Map();
const TTL = 30_000;

function cached(key, loader) {
  const hit = cache.get(key);
  const now = Date.now();
  if (hit && now - hit.t < TTL) return Promise.resolve(hit.v);
  return loader().then((v) => {
    cache.set(key, { v, t: now });
    return v;
  });
}

export function invalidateCache() {
  cache.clear();
}

export function useTransactions(qs = "") {
  const [data, setData] = useState({ loading: true, transactions: [], total: 0, error: null });

  useEffect(() => {
    let alive = true;
    cached(`tx:${qs}`, () => api.transactions(qs))
      .then((r) => alive && setData({ loading: false, ...r, error: null }))
      .catch((e) => alive && setData({ loading: false, transactions: [], total: 0, error: e.message }));
    return () => {
      alive = false;
    };
  }, [qs]);

  return data;
}

export { cached };
