import { Player, type PlayerRef } from '@remotion/player';
import { useEffect, useRef, useState, type ComponentType } from 'react';
import { dictionaries, type Locale } from '../i18n';
import { HERO, HeroShowcase } from '../../remotion/HeroShowcase';
import { ArchiveLoop, CommandLoop, ExtensionsLoop, LOOP, SpacesLoop, SplitLoop, TabsLoop } from '../../remotion/Loops';

type DemoComponent = ComponentType<{ demo: (typeof dictionaries)['ja']['demo'] }>;

const SCENES: Record<string, { component: DemoComponent; size: { width: number; height: number; fps: number; durationInFrames: number }; poster: number }> = {
  hero: { component: HeroShowcase, size: HERO, poster: 200 },
  tabs: { component: TabsLoop, size: LOOP, poster: 88 },
  spaces: { component: SpacesLoop, size: LOOP, poster: 80 },
  command: { component: CommandLoop, size: LOOP, poster: 60 },
  split: { component: SplitLoop, size: LOOP, poster: 84 },
  archive: { component: ArchiveLoop, size: LOOP, poster: 70 },
  extensions: { component: ExtensionsLoop, size: LOOP, poster: 104 },
};

export type SceneName = keyof typeof SCENES;

/**
 * Remotion のコンポジションをページ内で再生する。
 * - 画面外では停止し、「動きを減らす」設定のときは代表フレームで止める。
 * - 親の aspect-ratio で高さを確保しているので、水和前後でレイアウトは動かない。
 */
export default function RemotionPlayer({ scene, locale, label }: { scene: SceneName; locale: Locale; label: string }) {
  const { component, size, poster } = SCENES[scene as string];
  const ref = useRef<PlayerRef>(null);
  const box = useRef<HTMLDivElement>(null);
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const mq = window.matchMedia('(prefers-reduced-motion: reduce)');
    setReduced(mq.matches);
    const onChange = () => setReduced(mq.matches);
    mq.addEventListener('change', onChange);
    return () => mq.removeEventListener('change', onChange);
  }, []);

  useEffect(() => {
    const el = box.current;
    if (!el || reduced) return;
    const io = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) ref.current?.play();
      else ref.current?.pause();
    });
    io.observe(el);
    return () => io.disconnect();
  }, [reduced]);

  return (
    <div ref={box} role="img" aria-label={label} style={{ width: '100%', height: '100%' }}>
      <Player
        ref={ref}
        component={component}
        inputProps={{ demo: dictionaries[locale].demo }}
        compositionWidth={size.width}
        compositionHeight={size.height}
        fps={size.fps}
        durationInFrames={size.durationInFrames}
        initialFrame={reduced ? poster : 0}
        autoPlay={!reduced}
        initiallyMuted
        loop
        controls={false}
        clickToPlay={false}
        doubleClickToFullscreen={false}
        spaceKeyToPlayOrPause={false}
        acknowledgeRemotionLicense
        style={{ width: '100%', height: '100%' }}
      />
    </div>
  );
}
