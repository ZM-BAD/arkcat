// 宿主 UT 桩：@kit.NetworkKit（GitHttpClient 级联依赖；纯测不打真网络）
export const http = {
  createHttp: () => ({ request: () => Promise.resolve({ result: '', responseCode: 200, header: {} }) }),
  RequestMethod: { GET: 'GET', POST: 'POST', PATCH: 'PATCH', PUT: 'PUT', DELETE: 'DELETE' },
  HttpDataType: { STRING: 0, OBJECT: 1, ARRAY_BUFFER: 2 }
};
