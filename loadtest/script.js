import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  vus: 10,
  duration: '30s'
};

const API_KEY = __ENV.API_KEY || '';
const BASE = __ENV.BASE_URL || 'http://localhost:8080';

export default function () {
  const params = { headers: {} };
  if (API_KEY) { params.headers['X-API-Key'] = API_KEY; }
  const res = http.get(`${BASE}/run`, params);
  check(res, { 'status 200': r => r.status === 200 || r.status === 401 });
  sleep(0.5);
}
