import { LATEST_API } from '../config';

const root = document.documentElement;

/* ---- スクロールで要素を表示（動きを減らす設定では即時表示） ---- */
const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
const targets = document.querySelectorAll<HTMLElement>('.reveal');
if (reduced || !('IntersectionObserver' in window)) {
  targets.forEach((el) => el.classList.add('is-in'));
} else {
  const io = new IntersectionObserver(
    (entries) => {
      for (const e of entries) {
        if (!e.isIntersecting) continue;
        e.target.classList.add('is-in');
        io.unobserve(e.target);
      }
    },
    { rootMargin: '0px 0px -8% 0px' },
  );
  targets.forEach((el) => io.observe(el));
}

/* ---- ダウンロード: クリックで DMG が直接ダウンロードされる。完了後の案内に表示を切り替える ---- */
const isMac = /Macintosh|Mac OS X/.test(navigator.userAgent);
if (!isMac) root.classList.add('not-mac');

document.querySelectorAll<HTMLAnchorElement>('[data-download]').forEach((a) => {
  let timer: number | undefined;
  a.addEventListener('click', () => {
    a.dataset.state = 'started';
    document.querySelectorAll<HTMLElement>('[data-download-hint]').forEach((el) => (el.hidden = false));
    window.clearTimeout(timer);
    timer = window.setTimeout(() => (a.dataset.state = 'idle'), 6000);
  });
});

/* ---- 最新バージョンとサイズを表示（取得できなければ何も出さない） ---- */
type Release = { tag_name: string; assets: { name: string; size: number }[] };
const versionEls = document.querySelectorAll<HTMLElement>('[data-latest-version]');
if (versionEls.length) {
  fetch(LATEST_API, { headers: { Accept: 'application/vnd.github+json' } })
    .then(async (res) => {
      if (res.status === 404) {
        document.querySelectorAll<HTMLElement>('[data-no-release]').forEach((el) => (el.hidden = false));
        return;
      }
      if (!res.ok) return;
      const release = (await res.json()) as Release;
      const dmg = release.assets.find((a) => a.name === 'choco-browser.dmg');
      const size = dmg ? ` (${(dmg.size / 1024 / 1024).toFixed(1)} MB)` : '';
      versionEls.forEach((el) => (el.textContent = `${release.tag_name}${size} · `));
    })
    .catch(() => {});
}

/* ---- コピー ---- */
document.querySelectorAll<HTMLButtonElement>('[data-copy]').forEach((btn) => {
  const label = btn.querySelector<HTMLElement>('[data-copy-label]');
  const original = label?.textContent ?? '';
  btn.addEventListener('click', async () => {
    const text = btn.dataset.copy ?? '';
    try {
      await navigator.clipboard.writeText(text);
    } catch {
      const area = document.createElement('textarea');
      area.value = text;
      document.body.append(area);
      area.select();
      document.execCommand('copy');
      area.remove();
    }
    if (label) label.textContent = btn.dataset.copied ?? original;
    btn.dataset.state = 'copied';
    window.setTimeout(() => {
      if (label) label.textContent = original;
      btn.dataset.state = 'idle';
    }, 1800);
  });
});
