import { AbsoluteFill, Composition, registerRoot, staticFile, useCurrentFrame } from "raea";
import { Canvas3D } from "raea/3d";
import { Camera3d } from "raea/camera";
import { AmbientLight, DirectionalLight } from "raea/light";
import { Transform } from "raea/transform";
import { Axolotl } from "./axolotl-model";
import { css } from "./styles.gen";

type TextProps = {
  text: string;
  left: number;
  top: number;
  width: number;
  size: number;
  color: string;
  mono?: boolean;
  weight?: number;
  tracking?: string;
};

function Text({ text, left, top, width, size, color, mono = false, weight = 400, tracking = "normal" }: TextProps) {
  return (
    <div
      style={{
        position: "absolute",
        left,
        top,
        width,
        color,
        fontFamily: mono ? "var(--brand-font-mono)" : "var(--brand-font-heading)",
        fontSize: size,
        fontWeight: weight,
        lineHeight: 1.2,
        letterSpacing: tracking,
        whiteSpace: "nowrap",
      }}
    >
      {text}
    </div>
  );
}

function Line({ left, top, width, color = "var(--brand-seam)" }: { left: number; top: number; width: number; color?: string }) {
  return <div style={{ position: "absolute", left, top, width, height: 1, backgroundColor: color }} />;
}

function Hero() {
  const frame = useCurrentFrame();
  const phase = (frame / 144) * Math.PI * 2;
  return (
    <AbsoluteFill style={{ backgroundColor: "var(--brand-background)", color: "var(--brand-primary)" }}>
      <style>{css}</style>

      <div
        style={{
          position: "absolute",
          left: 620,
          top: 50,
          width: 508,
          height: 380,
          boxSizing: "border-box",
          backgroundColor: "var(--brand-canvas)",
          border: "1px solid var(--brand-seam-lit)",
        }}
      />

      <Canvas3D layered>
        <Camera3d
          transform={Transform.fromXyz(0, 0.28, 7.5).lookingAt([0, 0, 0])}
          projection={{ Perspective: { fov: (40 * Math.PI) / 180 } }}
        />
        <AmbientLight brightness={150} />
        <DirectionalLight
          transform={Transform.fromXyz(-2.8, 4.2, 5).lookingAt([0, 0, 0])}
          illuminance={9800}
        />
        <Axolotl
          phase={0.3}
          loopFrames={144}
          yaw={0.22}
          scale={1.34}
          x={2.75 + Math.sin(phase) * 0.3}
          y={-0.06 + Math.sin(phase * 2) * 0.055}
        />
      </Canvas3D>

      <Line left={72} top={42} width={1056} />
      <img src={staticFile("nodecode-axolotl.svg")} alt="" style={{ position: "absolute", left: 72, top: 48, width: 36, height: 31 }} />
      <Text text="NODECODE  /  COMMUNITY CELL" left={120} top={62} width={480} size={14} color="var(--brand-muted)" mono weight={500} tracking="0.12em" />
      <Line left={120} top={102} width={34} color="var(--brand-accent)" />

      <div style={{ position: "absolute", left: 72, top: 135, display: "flex", alignItems: "baseline", fontFamily: "var(--brand-font-heading)", fontSize: 76, fontWeight: 500, lineHeight: 0.98, letterSpacing: "-0.04em" }}>
        <span style={{ color: "var(--brand-primary)" }}>Sub</span>
        <span style={{ color: "var(--brand-accent)" }}>agents</span>
      </div>
      <Text text="Named tasks. Detached sessions." left={74} top={238} width={500} size={22} color="var(--brand-secondary)" />
      <Text text="Shared coordination through Nodecode Board." left={74} top={272} width={500} size={19} color="var(--brand-muted)" />

      <Text text="AXOLOTL / 3D SWIM CYCLE" left={646} top={67} width={450} size={13} color="var(--brand-muted)" mono weight={500} tracking="0.08em" />
      <div style={{ position: "absolute", left: 640, top: 67, width: 7, height: 7, backgroundColor: "var(--brand-accent)" }} />
      <Line left={621} top={89} width={506} />

      <Line left={72} top={344} width={470} />
      <Text text="PARENT" left={74} top={364} width={90} size={13} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />
      <Text text="TASK" left={200} top={364} width={100} size={13} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />
      <Text text="WORKERS" left={330} top={364} width={120} size={13} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />
      <Text text="BOARD" left={468} top={364} width={90} size={13} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />
      <Line left={158} top={370} width={24} color="var(--brand-seam-lit)" />
      <Line left={292} top={370} width={24} color="var(--brand-seam-lit)" />
      <Line left={444} top={370} width={16} color="var(--brand-seam-lit)" />
      <Line left={72} top={455} width={1056} />
    </AbsoluteFill>
  );
}

registerRoot(() => <Composition id="readme-hero" component={Hero} width={1200} height={480} fps={24} durationInFrames={144} />);
