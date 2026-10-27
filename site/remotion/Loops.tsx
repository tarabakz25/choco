import type { ReactNode } from 'react';
import { useCurrentFrame, useVideoConfig } from 'remotion';
import {
  Backdrop,
  C,
  CommandBar,
  CursorArrow,
  FavTile,
  FONT,
  iconColor,
  Key,
  loopFade,
  mix,
  PageMock,
  pop,
  ROW_H,
  Row,
  SectionLabel,
  seg,
  SpaceDock,
  SPACES,
  TrafficLights,
  UrlPill,
  WindowShell,
} from './ui';
import type { DemoProps } from './HeroShowcase';

/** 機能カード用の短いループ。5 秒（150 フレーム）で先頭に戻る */
export const LOOP = { width: 720, height: 450, fps: 30, durationInFrames: 150 } as const;

const W = 700;
const H = 420;
const SB = 196;
const IN = 8;
const PW = W - SB - IN;
const PH = H - IN * 2;
const GAP = 6;
/** 窓の左上 → コンポジションの左上 */
const OX = (LOOP.width - W) / 2;
const OY = (LOOP.height - H) / 2;

function Stage({
  sidebar,
  children,
  overlay,
  space = 0,
  to,
  t = 0,
}: {
  sidebar: ReactNode;
  children?: ReactNode;
  overlay?: ReactNode;
  space?: number;
  to?: number;
  t?: number;
}) {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  return (
    <div style={{ position: 'absolute', inset: 0, fontFamily: FONT }}>
      <WindowShell width={W} height={H}>
        <div style={{ position: 'absolute', inset: 0, opacity: loopFade(frame, durationInFrames, 10) }}>
          <div style={{ position: 'absolute', left: 0, top: 0, bottom: 0, width: SB, padding: '14px 12px' }}>
            <TrafficLights />
            {sidebar}
          </div>
          <div style={{ position: 'absolute', left: SB, top: IN, width: PW, height: PH, borderRadius: 8, overflow: 'hidden' }}>
            <Backdrop space={space} to={to} t={t} />
            {children}
          </div>
          {overlay}
        </div>
      </WindowShell>
    </div>
  );
}

const Abs = ({ top, children }: { top: number; children: ReactNode }) => (
  <div style={{ position: 'absolute', left: 12, right: 12, top }}>{children}</div>
);

/* ------------------------------------------------------------------ 縦タブ・Favorites・フォルダ */
export function TabsLoop({ demo }: DemoProps) {
  const frame = useCurrentFrame();
  const fps = LOOP.fps;
  const [t0, t1, t2] = demo.tabs;

  const cursorT = seg(frame, 12, 20) * (1 - seg(frame, 92, 104));
  const grab = seg(frame, 40, 42);
  const dragT = seg(frame, 42, 70);
  const dropT = seg(frame, 72, 88);
  // リスト座標（Pinned 見出しが y=0）
  const top = 140;
  const row0Y = 98; // Today の先頭行（元の位置）
  const folderY = 26;
  const ghostY = frame < 72 ? mix(row0Y, folderY, dragT) : folderY;
  const cx = frame < 40 ? mix(OX + 280, OX + 12 + 70, seg(frame, 14, 38)) : OX + 12 + 70;
  const cy = frame < 40 ? mix(OY + 120, OY + top + row0Y + 19, seg(frame, 14, 38)) : OY + top + ghostY + 19;

  return (
    <Stage
      sidebar={
        <>
          <div style={{ marginTop: 12 }}>
            <UrlPill text="notes.example.com" />
          </div>
          <div style={{ marginTop: 12, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
            {['Mail', 'Notes', 'Todo'].map((l, i) => (
              <FavTile key={l} label={l} height={44} scale={mix(0.6, 1, pop(frame, fps, 4 + i * 4))} opacity={seg(frame, 4 + i * 4, 12 + i * 4)} />
            ))}
          </div>
          <div style={{ position: 'absolute', left: 12, right: 12, top }}>
            <div style={{ opacity: seg(frame, 14, 26) }}>
              <SectionLabel>{demo.pinned}</SectionLabel>
              <div style={{ position: 'absolute', top: folderY, left: 0, right: 0 }}>
                <Row label={demo.folder} folder open={dropT > 0.5} />
              </div>
              <div style={{ position: 'absolute', top: 64, left: 0, right: 0, opacity: dropT, transform: `translateX(${mix(-10, 0, dropT)}px)` }}>
                <Row label={t0} indent={20} active />
              </div>
              <div style={{ position: 'absolute', top: 72 + 38 * dropT, left: 0, right: 0 }}>
                <SectionLabel>{demo.today}</SectionLabel>
              </div>
              {[t1, t2].map((l, i) => (
                <div key={l} style={{ position: 'absolute', top: row0Y + ROW_H * (i + 1), left: 0, right: 0 }}>
                  <Row label={l} />
                </div>
              ))}
              {frame < 72 && (
                <div style={{ position: 'absolute', top: ghostY, left: 0, right: 0, transform: `scale(${mix(1, 1.04, grab)})`, filter: grab ? 'drop-shadow(0 10px 14px rgba(0,0,0,0.35))' : 'none' }}>
                  <Row label={t0} active style={{ background: grab ? 'rgba(255,255,255,0.22)' : C.selected }} />
                </div>
              )}
            </div>
          </div>
        </>
      }
      overlay={
        <div style={{ position: 'absolute', inset: 0, opacity: cursorT }}>
          <CursorArrow x={cx - OX} y={cy - OY} down={frame >= 40 && frame < 72} />
        </div>
      }
    >
      <PageMock title={t0} accent={SPACES[0].accent} />
    </Stage>
  );
}

/* ------------------------------------------------------------------ Space と Profile */
export function SpacesLoop({ demo }: DemoProps) {
  const frame = useCurrentFrame();
  const there = seg(frame, 52, 74);
  const back = seg(frame, 108, 126);
  const t = there * (1 - back);
  const space = t > 0.5 ? 1 : 0;
  const dockX = (i: number) => OX + 12 + 15 + i * 36;
  const dockY = OY + H - 14 - 20;
  const cursorT = seg(frame, 24, 32) * (1 - seg(frame, 128, 138));
  const cx = frame < 90 ? mix(OX + 340, dockX(1), seg(frame, 28, 50)) : mix(dockX(1), dockX(0), seg(frame, 94, 106));
  const cy = frame < 90 ? mix(OY + 220, dockY, seg(frame, 28, 50)) : dockY;
  const down = (frame >= 50 && frame < 58) || (frame >= 106 && frame < 114);

  const list = (idx: number, opacity: number, x: number) => {
    const names = idx === 0 ? demo.spaceTabs[0] : demo.spaceTabs[1];
    return (
      <div style={{ position: 'absolute', left: 0, right: 0, top: 0, opacity, transform: `translateX(${x}px)` }}>
        <SectionLabel>{demo.today}</SectionLabel>
        {names.map((l, i) => (
          <Row key={l} label={l} active={i === 0} />
        ))}
      </div>
    );
  };

  return (
    <Stage
      space={0}
      to={1}
      t={t}
      sidebar={
        <>
          <div style={{ marginTop: 14, display: 'flex', alignItems: 'center', gap: 8, fontSize: 16, fontWeight: 600 }}>
            <i style={{ width: 10, height: 10, borderRadius: 5, background: space === 0 ? SPACES[0].accent : SPACES[1].accent, display: 'block' }} />
            {demo.spaces[space]}
          </div>
          <div
            style={{
              marginTop: 8,
              display: 'inline-block',
              padding: '3px 10px',
              borderRadius: 999,
              fontSize: 12,
              color: C.secondary,
              background: C.tile,
            }}
          >
            {demo.profile}: {demo.spaces[space]}
          </div>
          <div style={{ position: 'absolute', left: 12, right: 12, top: 112 }}>
            {list(0, 1 - t, -12 * t)}
            {list(1, t, 12 * (1 - t))}
          </div>
          <div style={{ position: 'absolute', left: 12, right: 12, bottom: 14 }}>
            <SpaceDock active={space} from={space === 0 ? 1 : 0} accentT={space === 1 ? seg(frame, 56, 70) : frame > 90 ? seg(frame, 112, 126) : 1} />
          </div>
        </>
      }
      overlay={
        <div style={{ position: 'absolute', inset: 0, opacity: cursorT }}>
          <CursorArrow x={cx - OX} y={cy - OY} down={down} />
        </div>
      }
    >
      <div style={{ position: 'absolute', inset: 22, borderRadius: 12, overflow: 'hidden', boxShadow: '0 18px 40px rgba(0,0,0,0.35)' }}>
        <PageMock title={demo.spaceTabs[space][0]} accent={SPACES[space].accent} dark={space === 1} />
      </div>
    </Stage>
  );
}

/* ------------------------------------------------------------------ コマンドバー */
export function CommandLoop({ demo }: DemoProps) {
  const frame = useCurrentFrame();
  const open = seg(frame, 14, 24) * (1 - seg(frame, 108, 116));
  const chars = Math.min(demo.typed.length, Math.floor(Math.max(0, frame - 30) / 4));
  const selected = frame < 70 ? 0 : frame < 86 ? 1 : frame < 100 ? 2 : 0;
  const insertT = seg(frame, 112, 126);
  const keyA = seg(frame, 4, 8) * (1 - seg(frame, 26, 32));
  const downFlash = (f: number) => seg(frame, f, f + 3) * (1 - seg(frame, f + 5, f + 9));
  const enter = seg(frame, 100, 103) * (1 - seg(frame, 108, 116));

  return (
    <Stage
      sidebar={
        <>
          <div style={{ marginTop: 12 }}>
            <UrlPill text={insertT > 0.5 ? demo.urls[1] : demo.urls[0]} />
          </div>
          <div style={{ position: 'absolute', left: 12, right: 12, top: 96 }}>
            <SectionLabel>{demo.today}</SectionLabel>
            <div style={{ position: 'relative', height: ROW_H * 4 }}>
              <div style={{ position: 'absolute', left: 0, right: 0, top: 0, opacity: insertT, transform: `translateX(${mix(-10, 0, insertT)}px)` }}>
                <Row label="choco-browser" active />
              </div>
              {[demo.tabs[1], demo.tabs[2]].map((l, i) => (
                <div key={l} style={{ position: 'absolute', left: 0, right: 0, top: ROW_H * (i + insertT) }}>
                  <Row label={l} active={i === 0 && insertT < 0.5} />
                </div>
              ))}
            </div>
          </div>
        </>
      }
    >
      <PageMock title={insertT > 0.5 ? 'choco-browser' : demo.tabs[1]} accent={SPACES[0].accent} dark={insertT > 0.5} />
      <div style={{ position: 'absolute', inset: 0, background: '#000', opacity: 0.55 * open }} />
      <div style={{ position: 'absolute', top: 42, left: (PW - 440) / 2 }}>
        <CommandBar
          width={440}
          progress={open}
          typed={demo.typed.slice(0, chars)}
          placeholder={demo.commandPlaceholder}
          results={demo.results}
          selected={selected}
        />
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 24, display: 'flex', justifyContent: 'center', gap: 8 }}>
        <div style={{ display: 'flex', gap: 8, opacity: keyA }}>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }}>⌘</Key>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }}>T</Key>
        </div>
        <div style={{ position: 'absolute', display: 'flex', gap: 8, opacity: Math.max(downFlash(70), downFlash(86)) }}>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }} press={1}>↓</Key>
        </div>
        <div style={{ position: 'absolute', opacity: enter }}>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }} press={1}>⏎</Key>
        </div>
      </div>
    </Stage>
  );
}

/* ------------------------------------------------------------------ Split */
export function SplitLoop({ demo }: DemoProps) {
  const frame = useCurrentFrame();
  const [, a, b] = [0, demo.tabs[1], demo.tabs[2]];
  const split = seg(frame, 52, 76) * (1 - seg(frame, 128, 144));
  const swap = seg(frame, 96, 118);
  const paneW = mix(PW, (PW - GAP) / 2, split);
  const half = (PW - GAP) / 2;
  const pressed = frame >= 44 && frame < 52;
  const cursorT = seg(frame, 16, 24) * (1 - seg(frame, 78, 90));
  const btnX = OX + SB + PW - 22;
  const btnY = OY + IN + 22;
  const cx = mix(OX + SB + 120, btnX, seg(frame, 18, 42));
  const cy = mix(OY + 300, btnY, seg(frame, 18, 42));

  return (
    <Stage
      sidebar={
        <>
          <div style={{ marginTop: 12 }}>
            <UrlPill text="notes.example.com" />
          </div>
          <div style={{ position: 'absolute', left: 12, right: 12, top: 96 }}>
            <SectionLabel>{demo.today}</SectionLabel>
            <Row label={a} active />
            <Row label={b} active={split > 0.5} />
            <Row label={demo.tabs[0]} />
          </div>
        </>
      }
      overlay={
        <div style={{ position: 'absolute', inset: 0, opacity: cursorT }}>
          <CursorArrow x={cx - OX} y={cy - OY} down={pressed} />
        </div>
      }
    >
      <div style={{ position: 'absolute', top: 0, bottom: 0, left: swap * (half + GAP) * split, width: paneW, borderRadius: 8, overflow: 'hidden' }}>
        <PageMock title={a} accent={SPACES[0].accent} />
      </div>
      <div
        style={{
          position: 'absolute',
          top: 0,
          bottom: 0,
          left: mix(PW, half + GAP, split) - swap * (half + GAP) * split,
          width: half,
          borderRadius: 8,
          overflow: 'hidden',
          opacity: split,
        }}
      >
        <PageMock title={b} accent="#4f8fe8" dark />
      </div>
      <div
        style={{
          position: 'absolute',
          top: 12,
          right: 12,
          height: 32,
          padding: '0 14px',
          borderRadius: 9,
          display: 'flex',
          alignItems: 'center',
          fontSize: 14,
          fontWeight: 600,
          background: pressed || split > 0.1 ? 'rgba(30,30,31,0.92)' : 'rgba(30,30,31,0.7)',
          border: `1px solid ${C.commandBorder}`,
          color: C.text,
          fontFamily: FONT,
        }}
      >
        {demo.split}
      </div>
    </Stage>
  );
}

/* ------------------------------------------------------------------ Archive と復元 */
export function ArchiveLoop({ demo }: DemoProps) {
  const frame = useCurrentFrame();
  const [z, x, y] = demo.tabs;
  const closeT = seg(frame, 24, 42);
  const restoreT = seg(frame, 112, 130);
  const gone = closeT * (1 - restoreT);
  const panel = seg(frame, 44, 62) * (1 - seg(frame, 104, 120));
  const keyA = seg(frame, 14, 18) * (1 - seg(frame, 34, 40));
  const keyB = seg(frame, 96, 100) * (1 - seg(frame, 116, 122));
  const item = seg(frame, 60, 72) * (1 - seg(frame, 108, 114));

  return (
    <Stage
      sidebar={
        <>
          <div style={{ marginTop: 12 }}>
            <UrlPill text={gone > 0.5 ? demo.urls[0] : demo.urls[1]} />
          </div>
          <div style={{ position: 'absolute', left: 12, right: 12, top: 96 }}>
            <SectionLabel>{demo.today}</SectionLabel>
            <div style={{ position: 'relative', height: ROW_H * 3 }}>
              <div style={{ position: 'absolute', left: 0, right: 0, top: 0, opacity: 1 - gone, transform: `translateX(${-24 * gone}px)` }}>
                <Row label={x} active />
              </div>
              {[y, z].map((l, i) => (
                <div key={l} style={{ position: 'absolute', left: 0, right: 0, top: ROW_H * (i + 1 - gone) }}>
                  <Row label={l} active={i === 0 && gone > 0.5} />
                </div>
              ))}
            </div>
          </div>
        </>
      }
    >
      <PageMock title={gone > 0.5 ? y : x} accent={SPACES[0].accent} dark={gone > 0.5} />
      <div
        style={{
          position: 'absolute',
          top: 10,
          bottom: 10,
          right: 10,
          width: 230,
          borderRadius: 12,
          background: 'rgba(30,30,31,0.94)',
          border: `1px solid ${C.commandBorder}`,
          padding: 14,
          opacity: panel,
          transform: `translateX(${(1 - panel) * 40}px)`,
          boxShadow: '0 20px 50px rgba(0,0,0,0.45)',
          color: C.text,
        }}
      >
        <div style={{ fontSize: 16, fontWeight: 700 }}>{demo.archive}</div>
        <div style={{ marginTop: 10, height: 30, borderRadius: 8, background: C.tile }} />
        <div style={{ marginTop: 14, fontSize: 12, color: C.secondary }}>{demo.archiveToday}</div>
        <div
          style={{
            marginTop: 6,
            height: 40,
            borderRadius: 9,
            background: restoreT > 0.01 && frame > 100 ? 'rgba(165,83,167,0.35)' : C.selected,
            display: 'flex',
            alignItems: 'center',
            gap: 10,
            padding: '0 10px',
            fontSize: 14,
            opacity: item,
          }}
        >
          <span style={{ width: 18, height: 18, borderRadius: 5, background: iconColor(x) }} />
          <span style={{ flex: 1 }}>{x}</span>
          <span style={{ fontSize: 12, color: C.secondary }}>{demo.restore}</span>
        </div>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 22, display: 'flex', justifyContent: 'center' }}>
        <div style={{ display: 'flex', gap: 8, opacity: keyA }}>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }} press={1}>⌘</Key>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }} press={1}>W</Key>
        </div>
        <div style={{ position: 'absolute', display: 'flex', gap: 8, opacity: keyB }}>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }} press={1}>⇧</Key>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }} press={1}>⌘</Key>
          <Key style={{ minWidth: 38, height: 38, fontSize: 17 }} press={1}>T</Key>
        </div>
      </div>
    </Stage>
  );
}

/* ------------------------------------------------------------------ Chrome 拡張機能 */
export function ExtensionsLoop({ demo }: DemoProps) {
  const frame = useCurrentFrame();
  const sheet = seg(frame, 4, 16) * (1 - seg(frame, 136, 146));
  const typedLen = Math.floor(seg(frame, 20, 62, (v) => v) * demo.extTyped.length);
  const press = seg(frame, 66, 69) * (1 - seg(frame, 70, 74));
  const progress = seg(frame, 72, 98, (v) => v);
  const card = seg(frame, 100, 114);
  const badge = seg(frame, 112, 124);

  return (
    <Stage
      sidebar={
        <>
          <div style={{ marginTop: 12 }}>
            <UrlPill text={demo.urls[0]} />
          </div>
          <div style={{ position: 'absolute', left: 12, right: 12, top: 96 }}>
            <SectionLabel>{demo.today}</SectionLabel>
            <Row label={demo.tabs[1]} active />
            <Row label={demo.tabs[2]} />
          </div>
        </>
      }
    >
      <PageMock title={demo.tabs[1]} accent={SPACES[0].accent} />
      <div style={{ position: 'absolute', inset: 0, background: '#000', opacity: 0.5 * sheet }} />
      <div
        style={{
          position: 'absolute',
          left: 36,
          right: 36,
          top: 44,
          borderRadius: 14,
          background: '#2a2a2c',
          border: `1px solid ${C.commandBorder}`,
          padding: 20,
          opacity: sheet,
          transform: `translateY(${(1 - sheet) * 16}px) scale(${mix(0.97, 1, sheet)})`,
          boxShadow: '0 30px 70px rgba(0,0,0,0.5)',
          color: C.text,
          fontFamily: FONT,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 18, fontWeight: 700 }}>
          <span style={{ width: 22, height: 22, borderRadius: 7, background: C.choco, display: 'grid', placeItems: 'center', fontSize: 13 }}>✦</span>
          {demo.extTitle}
        </div>
        <div style={{ marginTop: 16, display: 'flex', gap: 10 }}>
          <div
            style={{
              flex: 1,
              height: 40,
              borderRadius: 9,
              background: C.command,
              border: `1px solid ${frame >= 20 && frame < 70 ? C.choco : C.commandBorder}`,
              padding: '0 12px',
              display: 'flex',
              alignItems: 'center',
              fontSize: 14,
              color: typedLen ? C.text : C.tertiary,
              whiteSpace: 'nowrap',
              overflow: 'hidden',
            }}
          >
            {typedLen ? demo.extTyped.slice(0, typedLen) : demo.extPlaceholder}
          </div>
          <div
            style={{
              height: 40,
              padding: '0 20px',
              borderRadius: 9,
              background: C.choco,
              display: 'grid',
              placeItems: 'center',
              fontWeight: 600,
              fontSize: 14,
              transform: `scale(${1 - press * 0.05})`,
              filter: `brightness(${1 + press * 0.15})`,
            }}
          >
            {demo.extAdd}
          </div>
        </div>
        <div style={{ marginTop: 14, height: 4, borderRadius: 2, background: 'rgba(255,255,255,0.08)', overflow: 'hidden', opacity: progress > 0 && card < 1 ? 1 : 0 }}>
          <div style={{ width: `${progress * 100}%`, height: '100%', background: C.choco }} />
        </div>
        <div
          style={{
            marginTop: 14,
            height: 56,
            borderRadius: 11,
            background: C.tile,
            display: 'flex',
            alignItems: 'center',
            gap: 12,
            padding: '0 14px',
            opacity: card,
            transform: `translateY(${(1 - card) * 10}px)`,
          }}
        >
          <span style={{ width: 28, height: 28, borderRadius: 8, background: '#3fb68b', display: 'grid', placeItems: 'center', fontSize: 15 }}>✓</span>
          <div style={{ flex: 1 }}>
            <div style={{ fontSize: 15, fontWeight: 600 }}>{demo.extName}</div>
            <div style={{ fontSize: 12, color: C.secondary }}>{demo.extInstalled}</div>
          </div>
          <div style={{ width: 38, height: 22, borderRadius: 11, background: C.choco, position: 'relative' }}>
            <i style={{ position: 'absolute', right: 3, top: 3, width: 16, height: 16, borderRadius: 8, background: '#fff', display: 'block' }} />
          </div>
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          top: 12,
          right: 12,
          width: 32,
          height: 32,
          borderRadius: 9,
          background: 'rgba(30,30,31,0.85)',
          border: `1px solid ${C.commandBorder}`,
          display: 'grid',
          placeItems: 'center',
          opacity: badge,
          transform: `scale(${mix(0.5, 1, badge)})`,
          fontSize: 14,
          color: '#3fb68b',
        }}
      >
        ✦
      </div>
    </Stage>
  );
}
