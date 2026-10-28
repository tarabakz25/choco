// リポジトリ名を変えたらここと astro.config.mjs、public/install.sh を更新する（docs/release.md 参照）
export const REPO = 'tarabakz25/choco';
export const REPO_URL = `https://github.com/${REPO}`;
export const RELEASES_URL = `${REPO_URL}/releases/latest`;
/** リリース添付の固定名 DMG。リダイレクトされるが Content-Disposition: attachment なので、クリックするとそのままダウンロードされる。 */
export const DMG_URL = `${REPO_URL}/releases/latest/download/choco-browser.dmg`;
export const LATEST_API = `https://api.github.com/repos/${REPO}/releases/latest`;
export const SITE_URL = 'https://tarabakz25.github.io/choco';
export const INSTALL_COMMAND = `curl -fsSL ${SITE_URL}/install.sh | bash`;
