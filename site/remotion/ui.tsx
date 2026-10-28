import type { CSSProperties, ReactNode } from 'react';
import { Easing, interpolate, interpolateColors, spring } from 'remotion';

/** アプリの ChocoTheme（Sources/BrowserApp/DesignSystem/ChocoTheme.swift）と同じ値 */
export const C = {
  sidebar: '#5e5c5c',
  text: '#ededed',
  secondary: '#b9b8b8',
  tertiary: '#8f8e8e',
  command: '#1e1e1f',
  commandSelected: '#565655',
  commandBorder: '#4f4d4c',
  content: '#f4f4f5',
  selected: 'rgba(255,255,255,0.12)',
  tile: 'rgba(255,255,255,0.06)',
  divider: 'rgba(255,255,255,0.15)',
  choco: '#a553a7',
};

export const FONT = "Inter, -apple-system, BlinkMacSystemFont, 'Hiragino Sans', 'Hiragino Kaku Gothic ProN', system-ui, sans-serif";

/** Space ごとのページ背景（先頭がアプリの emptyContent と同じスレート→モーブ） */
export const SPACES = [
  { top: '#3a394c', mid: '#413a4c', bottom: '#49394c', accent: '#a553a7' },
  { top: '#2b4148', mid: '#2e4a49', bottom: '#33503f', accent: '#3fb68b' },
  { top: '#4a3d2f', mid: '#51402f', bottom: '#4d3a35', accent: '#e0953d' },
] as const;

export const soft = Easing.bezier(0.22, 1, 0.36, 1);

/** from〜to フレームを 0→1 にする。範囲の外は端に張り付く */
export const seg = (frame: number, from: number, to: number, easing: (t: number) => number = soft) =>
  interpolate(frame, [from, to], [0, 1], { extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing });

export const mix = (a: number, b: number, t: number) => a + (b - a) * t;

export const pop = (frame: number, fps: number, delay = 0) =>
  spring({ frame: frame - delay, fps, config: { damping: 15, stiffness: 150, mass: 0.8 } });

/** ループの継ぎ目を隠すため、先頭と末尾でコンテンツをフェードさせる */
export const loopFade = (frame: number, duration: number, edge = 12) =>
  Math.min(seg(frame, 0, edge, Easing.linear), seg(duration - frame, 0, edge, Easing.linear));

const ICON_COLORS = ['#e8704f', '#4f8fe8', '#8f6fe0', '#3fb68b', '#e0953d', '#d5578f', '#5bb4d6'];
export const iconColor = (label: string) => ICON_COLORS[[...label].reduce((n, ch) => n + ch.charCodeAt(0), 0) % ICON_COLORS.length];

export function Backdrop({ space, to, t = 0, style }: { space: number; to?: number; t?: number; style?: CSSProperties }) {
  const a = SPACES[space];
  const b = SPACES[to ?? space];
  const c = (k: 'top' | 'mid' | 'bottom') => interpolateColors(t, [0, 1], [a[k], b[k]]);
  return <div style={{ position: 'absolute', inset: 0, background: `linear-gradient(135deg, ${c('top')}, ${c('mid')}, ${c('bottom')})`, ...style }} />;
}

export function WindowShell({ children, width, height }: { children: ReactNode; width: number; height: number }) {
  return (
    <div
      style={{
        position: 'absolute',
        left: '50%',
        top: '50%',
        width,
        height,
        marginLeft: -width / 2,
        marginTop: -height / 2,
        borderRadius: 16,
        overflow: 'hidden',
        background: C.sidebar,
        border: '1px solid rgba(255,255,255,0.14)',
        boxShadow: '0 40px 90px rgba(0,0,0,0.55), 0 0 0 0.5px rgba(0,0,0,0.6)',
        fontFamily: FONT,
        color: C.text,
      }}
    >
      {children}
    </div>
  );
}

export function TrafficLights() {
  return (
    <div style={{ display: 'flex', gap: 8 }}>
      {['#ff5f57', '#febc2e', '#28c840'].map((c) => (
        <i key={c} style={{ width: 12, height: 12, borderRadius: 6, background: c, display: 'block' }} />
      ))}
    </div>
  );
}

export function FavTile({ label, scale = 1, opacity = 1, height = 58 }: { label: string; scale?: number; opacity?: number; height?: number }) {
  return (
    <div
      style={{
        height,
        borderRadius: 10,
        background: C.tile,
        display: 'grid',
        placeItems: 'center',
        transform: `scale(${scale})`,
        opacity,
      }}
    >
      <div
        style={{
          width: 28,
          height: 28,
          borderRadius: 8,
          background: iconColor(label),
          display: 'grid',
          placeItems: 'center',
          fontSize: 15,
          fontWeight: 700,
          color: '#fff',
        }}
      >
        {[...label][0]}
      </div>
    </div>
  );
}

export function SectionLabel({ children, opacity = 1 }: { children: ReactNode; opacity?: number }) {
  return <div style={{ fontSize: 12, color: C.secondary, padding: '0 10px', height: 26, display: 'flex', alignItems: 'center', opacity }}>{children}</div>;
}

export const ROW_H = 38;

export function Row({
  label,
  active = false,
  indent = 0,
  folder = false,
  open = false,
  opacity = 1,
  x = 0,
  y = 0,
  style,
}: {
  label: string;
  active?: boolean;
  indent?: number;
  folder?: boolean;
  open?: boolean;
  opacity?: number;
  x?: number;
  y?: number;
  style?: CSSProperties;
}) {
  return (
    <div
      style={{
        height: ROW_H,
        borderRadius: 8,
        padding: `0 10px 0 ${10 + indent}px`,
        display: 'flex',
        alignItems: 'center',
        gap: 10,
        fontSize: 15,
        color: folder ? C.secondary : C.text,
        background: active ? C.selected : 'transparent',
        opacity,
        transform: `translate(${x}px, ${y}px)`,
        whiteSpace: 'nowrap',
        ...style,
      }}
    >
      {folder ? (
        <span style={{ width: 18, textAlign: 'center', fontSize: 11, transform: `rotate(${open ? 90 : 0}deg)`, display: 'inline-block' }}>▶</span>
      ) : (
        <span style={{ width: 18, height: 18, borderRadius: 5, background: iconColor(label), flex: 'none' }} />
      )}
      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>{label}</span>
    </div>
  );
}

export function UrlPill({ text, width = '100%' }: { text: string; width?: number | string }) {
  return (
    <div
      style={{
        width,
        height: 34,
        borderRadius: 9,
        background: 'rgba(255,255,255,0.07)',
        display: 'flex',
        alignItems: 'center',
        padding: '0 12px',
        fontSize: 14,
        color: C.secondary,
        whiteSpace: 'nowrap',
        overflow: 'hidden',
      }}
    >
      {text}
    </div>
  );
}

export function SpaceDock({ active, accentT = 0, from = 0, count = 2 }: { active: number; accentT?: number; from?: number; count?: number }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 6, height: 40 }}>
      {Array.from({ length: count }, (_, i) => {
        const on = i === active ? accentT : i === from ? 1 - accentT : 0;
        return (
          <div
            key={i}
            style={{
              width: 30,
              height: 30,
              borderRadius: 9,
              display: 'grid',
              placeItems: 'center',
              background: `rgba(255,255,255,${0.05 + on * 0.1})`,
            }}
          >
            <i style={{ width: 10 + on * 4, height: 10 + on * 4, borderRadius: '50%', background: SPACES[i].accent, display: 'block', opacity: 0.5 + on * 0.5 }} />
          </div>
        );
      })}
      <span style={{ marginLeft: 4, color: C.secondary, fontSize: 20, lineHeight: 1 }}>＋</span>
    </div>
  );
}

export function Key({ children, press = 0, style }: { children: ReactNode; press?: number; style?: CSSProperties }) {
  return (
    <div
      style={{
        minWidth: 46,
        height: 44,
        padding: '0 14px',
        borderRadius: 11,
        display: 'inline-grid',
        placeItems: 'center',
        fontSize: 20,
        fontWeight: 600,
        color: C.text,
        background: 'rgba(30,30,31,0.88)',
        border: `1px solid ${C.commandBorder}`,
        boxShadow: `0 ${4 - press * 3}px 0 rgba(0,0,0,0.45), 0 12px 30px rgba(0,0,0,0.35)`,
        transform: `translateY(${press * 3}px)`,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

export function CursorArrow({ x, y, down = false }: { x: number; y: number; down?: boolean }) {
  return (
    <svg
      width="26"
      height="30"
      viewBox="0 0 26 30"
      style={{ position: 'absolute', left: 0, top: 0, transform: `translate(${x}px, ${y}px) scale(${down ? 0.9 : 1})`, filter: 'drop-shadow(0 3px 5px rgba(0,0,0,0.4))', zIndex: 50 }}
    >
      <path d="M3 2 L3 22 L8.2 17.6 L11.6 25.2 L15 23.7 L11.7 16.3 L18.6 16 Z" fill="#fff" stroke="#111" strokeWidth="1.6" strokeLinejoin="round" />
    </svg>
  );
}

/** 実ページの代わりに描く簡易モック（実際のスクリーンショットではない） */
export function PageMock({ title, accent = C.choco, dark = false }: { title: string; accent?: string; dark?: boolean }) {
  const ink = dark ? '#f0eef2' : '#2b2630';
  const skel = dark ? 'rgba(255,255,255,0.1)' : 'rgba(0,0,0,0.075)';
  return (
    <div style={{ position: 'absolute', inset: 0, background: dark ? '#1f1d24' : C.content, padding: '22px 36px', overflow: 'hidden' }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 34 }}>
        <i style={{ width: 22, height: 22, borderRadius: 7, background: accent, display: 'block' }} />
        <i style={{ width: 70, height: 9, borderRadius: 5, background: skel, display: 'block' }} />
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 14 }}>
          {[44, 54, 40].map((w, i) => (
            <i key={i} style={{ width: w, height: 8, borderRadius: 4, background: skel, display: 'block' }} />
          ))}
        </div>
      </div>
      <div style={{ fontSize: 40, fontWeight: 800, letterSpacing: '-0.02em', color: ink, lineHeight: 1.1, whiteSpace: 'nowrap' }}>{title}</div>
      <div style={{ marginTop: 16, display: 'grid', gap: 9 }}>
        {['72%', '58%', '44%'].map((w) => (
          <i key={w} style={{ width: w, height: 10, borderRadius: 5, background: skel, display: 'block' }} />
        ))}
      </div>
      <div style={{ marginTop: 28, display: 'flex', gap: 14 }}>
        <i style={{ width: 110, height: 36, borderRadius: 10, background: accent, display: 'block' }} />
        <i style={{ width: 90, height: 36, borderRadius: 10, background: skel, display: 'block' }} />
      </div>
      <div style={{ marginTop: 34, display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 14 }}>
        {[0, 1, 2].map((i) => (
          <i key={i} style={{ height: 96, borderRadius: 12, background: skel, display: 'block' }} />
        ))}
      </div>
    </div>
  );
}

export function CommandBar({
  progress,
  typed,
  placeholder,
  results,
  selected,
  width = 668,
}: {
  progress: number;
  typed: string;
  placeholder: string;
  results: string[];
  selected: number;
  width?: number;
}) {
  const show = typed.length > 0;
  return (
    <div
      style={{
        width,
        borderRadius: 14,
        background: C.command,
        border: `1px solid ${C.commandBorder}`,
        boxShadow: '0 30px 70px rgba(0,0,0,0.5)',
        opacity: progress,
        transform: `scale(${mix(0.96, 1, progress)})`,
        overflow: 'hidden',
        fontFamily: FONT,
      }}
    >
      <div style={{ height: 56, padding: '0 20px', display: 'flex', alignItems: 'center', fontSize: 19, color: show ? C.text : C.tertiary }}>
        {show ? typed : placeholder}
        {show && <i style={{ width: 2, height: 24, background: C.choco, marginLeft: 2, display: 'block' }} />}
      </div>
      {show && (
        <div style={{ borderTop: `1px solid ${C.commandBorder}`, padding: 8 }}>
          {results.map((r, i) => (
            <div
              key={r}
              style={{
                height: 46,
                borderRadius: 9,
                padding: '0 12px',
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                fontSize: 17,
                background: i === selected ? C.commandSelected : 'transparent',
                color: C.text,
              }}
            >
              <span style={{ width: 20, height: 20, borderRadius: 6, background: iconColor(r), flex: 'none' }} />
              {r}
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
