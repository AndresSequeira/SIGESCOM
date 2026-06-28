import axios from 'axios';

export const API_BASE_URL =
  'https://g6444ba724080c1-sigescom.adb.mx-queretaro-1.oraclecloudapps.com/ords/adminbd';

export const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Content-Type': 'application/json',
  },
});

export function getRows(payload) {
  if (Array.isArray(payload)) return payload;
  if (Array.isArray(payload?.items)) return payload.items;
  if (Array.isArray(payload?.rows)) return payload.rows;
  if (payload && typeof payload === 'object') return [payload];
  return [];
}

export function getErrorMessage(error) {
  const data = error?.response?.data;
  if (typeof data === 'string') return data;
  return data?.message || data?.error || error?.message || 'No se pudo completar la operacion';
}

