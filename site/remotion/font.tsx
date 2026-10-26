import { useEffect, useState, type ComponentType } from 'react';
import { continueRender, delayRender, staticFile } from 'remotion';

/** Studio / `remotion still` / `remotion render` 用。サイト側は global.css の @font-face が Inter を読み込む */
export function useInter() {
  const [handle] = useState(() => delayRender('Inter'));
  useEffect(() => {
    const face = new FontFace('Inter', `url(${staticFile('fonts/Inter.ttf')})`, { weight: '100 900' });
    face
      .load()
      .then((f) => document.fonts.add(f))
      .finally(() => continueRender(handle));
  }, [handle]);
}

export function withInter<P extends object>(Component: ComponentType<P>): ComponentType<P> {
  return function WithInter(props: P) {
    useInter();
    return <Component {...props} />;
  };
}
