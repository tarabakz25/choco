import { Composition, Folder } from 'remotion';
import { dictionaries } from '../src/i18n';
import { HERO, HeroShowcase } from './HeroShowcase';
import { ArchiveLoop, CommandLoop, ExtensionsLoop, LOOP, SpacesLoop, SplitLoop, TabsLoop } from './Loops';
import { withInter } from './font';
import { OG, OgImage } from './OgImage';

const Hero = withInter(HeroShowcase);

/** Remotion Studio（`bun run remotion`）と `remotion still` 用。サイトは同じコンポーネントを @remotion/player で再生する */
export function RemotionRoot() {
  const loops = [
    ['Tabs', withInter(TabsLoop)],
    ['Spaces', withInter(SpacesLoop)],
    ['Command', withInter(CommandLoop)],
    ['Split', withInter(SplitLoop)],
    ['Archive', withInter(ArchiveLoop)],
    ['Extensions', withInter(ExtensionsLoop)],
  ] as const;

  return (
    <>
      {(['ja', 'en'] as const).map((locale) => (
        <Folder key={locale} name={locale}>
          <Composition
            id={`hero-${locale}`}
            component={Hero}
            width={HERO.width}
            height={HERO.height}
            fps={HERO.fps}
            durationInFrames={HERO.durationInFrames}
            defaultProps={{ demo: dictionaries[locale].demo }}
          />
          {loops.map(([name, component]) => (
            <Composition
              key={name}
              id={`${name.toLowerCase()}-${locale}`}
              component={component}
              width={LOOP.width}
              height={LOOP.height}
              fps={LOOP.fps}
              durationInFrames={LOOP.durationInFrames}
              defaultProps={{ demo: dictionaries[locale].demo }}
            />
          ))}
        </Folder>
      ))}
      <Composition id="og" component={OgImage} width={OG.width} height={OG.height} fps={30} durationInFrames={1} />
    </>
  );
}
