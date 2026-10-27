import { staticFile } from 'remotion';
import { useInter } from './font';
import { Backdrop, C, FONT, SPACES, TrafficLights } from './ui';

export const OG = { width: 1200, height: 630 } as const;

/** SNS 共有用の静止画。`bun run og` で public/og.png に書き出す */
export function OgImage() {
  useInter();

  return (
    <div style={{ position: 'absolute', inset: 0, fontFamily: FONT, color: C.text, overflow: 'hidden' }}>
      <Backdrop space={0} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(700px 420px at 78% 38%, ${SPACES[0].accent}55, transparent 70%)`,
        }}
      />
      <div style={{ position: 'absolute', left: 72, top: 84, display: 'flex', alignItems: 'center', gap: 18 }}>
        <img src={staticFile('icon.png')} width={72} height={72} />
        <span style={{ fontSize: 36, fontWeight: 700 }}>choco-browser</span>
      </div>
      <div style={{ position: 'absolute', left: 72, top: 230, fontSize: 76, fontWeight: 800, lineHeight: 1.12, letterSpacing: '-0.03em' }}>
        タブを、
        <br />
        気持ちよく整理する。
      </div>
      <div style={{ position: 'absolute', left: 72, bottom: 72, fontSize: 28, color: C.secondary }}>
        Open-source macOS browser · Vertical tabs & Spaces
      </div>
      {/* 窓の断片 */}
      <div
        style={{
          position: 'absolute',
          right: -150,
          top: 150,
          width: 480,
          height: 420,
          borderRadius: 18,
          background: C.sidebar,
          border: '1px solid rgba(255,255,255,0.16)',
          boxShadow: '0 40px 90px rgba(0,0,0,0.5)',
          padding: 22,
        }}
      >
        <TrafficLights />
        {[0.9, 0.7, 0.8, 0.55].map((w, i) => (
          <div key={i} style={{ marginTop: 18, height: 34, width: `${w * 100}%`, borderRadius: 9, background: i === 1 ? C.selected : 'rgba(255,255,255,0.07)' }} />
        ))}
      </div>
    </div>
  );
}
