import { useCurrentFrame, useVideoConfig } from 'remotion';
import type { Dict } from '../src/i18n';
import {
  Backdrop,
  C,
  CommandBar,
  CursorArrow,
  FavTile,
  FONT,
  Key,
  loopFade,
  mix,
  PageMock,
  pop,
  ROW_H,
  Row,
  seg,
  SectionLabel,
  SpaceDock,
  SPACES,
  TrafficLights,
  UrlPill,
  WindowShell,
} from './ui';

export type DemoProps = { demo: Dict['demo'] };

export const HERO = { width: 1280, height: 800, fps: 30, durationInFrames: 390 } as const;

const WIN_W = 1200;
const WIN_H = 720;
const SIDEBAR_W = 252;
const INSET = 8;
const PAGE_W = WIN_W - SIDEBAR_W - INSET;
const PAGE_H = WIN_H - INSET * 2;
const GAP = 6;
const FAVS = ['Mail', 'Notes', 'Todo', 'Chat', 'Docs', 'Photos'];

type ListProps = {
  demo: Dict['demo'];
  pinnedTab: string;
  today: string[];
  active: string[];
  inserted?: { label: string; t: number };
  opacity?: number;
  x?: number;
};

/** Pinned / Today の一覧。新しいタブは先頭に挿入され、既存の行が押し下げられる */
function List({ demo, pinnedTab, today, active, inserted, opacity = 1, x = 0 }: ListProps) {
  const insertT = inserted?.t ?? 0;
  const rows = inserted ? [inserted.label, ...today] : today;
  return (
    <div style={{ position: 'absolute', left: 0, right: 0, top: 0, opacity, transform: `translateX(${x}px)` }}>
      <SectionLabel>{demo.pinned}</SectionLabel>
      <Row label={demo.folder} folder />
      <Row label={pinnedTab} active={active.includes(pinnedTab)} />
      <div style={{ height: 8 }} />
      <SectionLabel>{demo.today}</SectionLabel>
      <div style={{ position: 'relative', height: rows.length * ROW_H }}>
        {rows.map((label, i) => {
          const isNew = inserted !== undefined && i === 0;
          const y = inserted ? (isNew ? 0 : i * ROW_H - (1 - insertT) * ROW_H) : i * ROW_H;
          return (
            <Row
              key={label}
              label={label}
              active={active.includes(label)}
              y={y}
              x={isNew ? mix(-10, 0, insertT) : 0}
              opacity={isNew ? insertT : 1}
              style={{ position: 'absolute', left: 0, right: 0, top: 0 }}
            />
          );
        })}
      </div>
    </div>
  );
}

export function HeroShowcase({ demo }: DemoProps) {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();

  const win = pop(frame, fps, 0);
  const fade = loopFade(frame, durationInFrames, 14);

  // ---- 時間割 ----
  const cmd = seg(frame, 104, 114) * (1 - seg(frame, 160, 168));
  const typedChars = Math.min(demo.typed.length, Math.floor(Math.max(0, frame - 120) / 4));
  const newTabT = seg(frame, 162, 178);
  const spaceT = seg(frame, 238, 262);
  const space = frame < 238 ? 0 : 1;
  const splitT = seg(frame, 312, 338);

  const p1 = seg(frame, 36, 54) * (1 - seg(frame, 164, 176));
  const p2 = seg(frame, 164, 176) * (1 - seg(frame, 232, 244));
  const p3 = seg(frame, 280, 296);
  const emptyLabel = seg(frame, 240, 252) * (1 - seg(frame, 274, 284));

  const url = frame < 168 ? demo.urls[0] : frame < 238 ? demo.urls[1] : 'www.example.com';

  const keyT = seg(frame, 96, 102) * (1 - seg(frame, 124, 132));
  const keyPress = seg(frame, 100, 104) * (1 - seg(frame, 106, 110));
  const enterT = seg(frame, 154, 158) * (1 - seg(frame, 168, 176));
  const enterPress = seg(frame, 158, 161) * (1 - seg(frame, 162, 166));

  const cursorT = seg(frame, 200, 208) * (1 - seg(frame, 288, 298));
  const cx = frame < 262 ? mix(520, 62, seg(frame, 206, 232)) : mix(62, 120, seg(frame, 262, 274));
  const cy = frame < 262 ? mix(590, 684, seg(frame, 206, 232)) : mix(684, 384, seg(frame, 262, 274));
  const cursorDown = (frame >= 234 && frame < 242) || (frame >= 276 && frame < 284);

  const paneAWidth = mix(PAGE_W, (PAGE_W - GAP) / 2, splitT);
  const paneBWidth = (PAGE_W - GAP) / 2;

  const spaceTabs = demo.spaceTabs[1];
  const oldList = (
    <List
      demo={demo}
      pinnedTab={demo.tabs[0]}
      today={[demo.tabs[1], demo.tabs[2]]}
      active={frame < 162 ? [demo.tabs[1]] : ['choco-browser']}
      inserted={frame >= 162 ? { label: 'choco-browser', t: newTabT } : undefined}
      opacity={1 - spaceT}
      x={-14 * spaceT}
    />
  );
  const newList = (
    <List
      demo={demo}
      pinnedTab={spaceTabs[0]}
      today={[spaceTabs[1], spaceTabs[2]]}
      active={frame < 280 ? [] : frame < 312 ? [spaceTabs[1]] : [spaceTabs[1], spaceTabs[2]]}
      opacity={spaceT}
      x={14 * (1 - spaceT)}
    />
  );

  return (
    <div style={{ position: 'absolute', inset: 0, fontFamily: FONT }}>
      <div style={{ position: 'absolute', inset: 0, transform: `scale(${mix(0.94, 1, win)})`, opacity: seg(frame, 0, 12) }}>
        <WindowShell width={WIN_W} height={WIN_H}>
          <div style={{ position: 'absolute', inset: 0, opacity: fade }}>
            {/* ---- サイドバー ---- */}
            <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: SIDEBAR_W, padding: '18px 12px 12px' }}>
              <TrafficLights />
              <div style={{ marginTop: 16 }}>
                <UrlPill text={url} />
              </div>
              <div style={{ marginTop: 14, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                {FAVS.map((label, i) => {
                  const p = pop(frame, fps, 10 + i * 3);
                  return <FavTile key={label} label={label} scale={mix(0.6, 1, p)} opacity={seg(frame, 10 + i * 3, 20 + i * 3)} />;
                })}
              </div>
              <div style={{ position: 'relative', marginTop: 12, height: 360 }}>
                <div style={{ opacity: seg(frame, 22, 40) }}>
                  {oldList}
                  {newList}
                </div>
              </div>
              <div style={{ position: 'absolute', left: 12, right: 12, bottom: 12, opacity: seg(frame, 30, 44) }}>
                <SpaceDock active={space} from={0} accentT={space === 0 ? 1 : seg(frame, 238, 252)} />
              </div>
            </div>

            {/* ---- ページ領域 ---- */}
            <div
              style={{
                position: 'absolute',
                left: SIDEBAR_W,
                top: INSET,
                width: PAGE_W,
                height: PAGE_H,
                borderRadius: 8,
                overflow: 'hidden',
              }}
            >
              <Backdrop space={0} to={1} t={spaceT} />
              <div
                style={{
                  position: 'absolute',
                  inset: 0,
                  display: 'grid',
                  placeItems: 'center',
                  fontSize: 26,
                  fontWeight: 600,
                  color: 'rgba(255,255,255,0.85)',
                  opacity: emptyLabel,
                }}
              >
                {demo.spaces[1]}
              </div>

              {/* paneA: 通常ページ / Split の左 */}
              <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: paneAWidth, borderRadius: 8, overflow: 'hidden' }}>
                <div style={{ position: 'absolute', inset: 0, opacity: p1 }}>
                  <PageMock title={demo.tabs[1]} accent={SPACES[0].accent} />
                </div>
                <div style={{ position: 'absolute', inset: 0, opacity: p2 }}>
                  <PageMock title="choco-browser" accent={SPACES[0].accent} dark />
                </div>
                <div style={{ position: 'absolute', inset: 0, opacity: p3 }}>
                  <PageMock title={spaceTabs[1]} accent={SPACES[1].accent} />
                </div>
              </div>
              {/* paneB: Split の右 */}
              <div
                style={{
                  position: 'absolute',
                  top: 0,
                  bottom: 0,
                  left: paneAWidth + GAP,
                  width: paneBWidth,
                  borderRadius: 8,
                  overflow: 'hidden',
                  opacity: splitT,
                  transform: `translateX(${(1 - splitT) * 90}px)`,
                }}
              >
                <div style={{ position: 'absolute', inset: 0 }}>
                  <PageMock title={spaceTabs[2]} accent={SPACES[1].accent} dark />
                </div>
              </div>
              {splitT > 0 && (
                <div
                  style={{
                    position: 'absolute',
                    bottom: 20,
                    left: '50%',
                    transform: `translateX(-50%) translateY(${(1 - splitT) * 8}px)`,
                    opacity: splitT,
                    padding: '6px 14px',
                    borderRadius: 999,
                    background: 'rgba(30,30,31,0.85)',
                    border: `1px solid ${C.commandBorder}`,
                    fontSize: 14,
                    fontWeight: 600,
                  }}
                >
                  {demo.split}
                </div>
              )}

              {/* 暗転 + コマンドバー（サイドバーは暗くしない） */}
              <div style={{ position: 'absolute', inset: 0, background: '#000', opacity: 0.55 * cmd }} />
              {cmd > 0 && (
                <div style={{ position: 'absolute', top: 96, left: (PAGE_W - 668) / 2 }}>
                  <CommandBar
                    progress={cmd}
                    typed={demo.typed.slice(0, typedChars)}
                    placeholder={demo.commandPlaceholder}
                    results={demo.results}
                    selected={0}
                  />
                </div>
              )}
            </div>

            {/* ---- キー表示・カーソル ---- */}
            <div style={{ position: 'absolute', left: SIDEBAR_W, width: PAGE_W, bottom: 44, display: 'flex', justifyContent: 'center', gap: 10 }}>
              <div style={{ display: 'flex', gap: 10, opacity: keyT, transform: `translateY(${(1 - keyT) * 14}px)` }}>
                <Key press={keyPress}>⌘</Key>
                <Key press={keyPress}>T</Key>
              </div>
            </div>
            <div style={{ position: 'absolute', left: SIDEBAR_W, width: PAGE_W, bottom: 44, display: 'flex', justifyContent: 'center' }}>
              <div style={{ opacity: enterT, transform: `translateY(${(1 - enterT) * 14}px)` }}>
                <Key press={enterPress}>⏎</Key>
              </div>
            </div>
            <div style={{ position: 'absolute', inset: 0, opacity: cursorT }}>
              <CursorArrow x={cx} y={cy} down={cursorDown} />
            </div>
          </div>
        </WindowShell>
      </div>
    </div>
  );
}
