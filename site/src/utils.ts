const base = import.meta.env.BASE_URL.replace(/\/$/, '');

/** base（/choco）付きの絶対パスにする。外部 URL はそのまま */
export const url = (path = '') => (/^https?:/.test(path) ? path : `${base}/${path.replace(/^\//, '')}`);
