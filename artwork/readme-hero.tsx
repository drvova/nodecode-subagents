import { AbsoluteFill, Composition, registerRoot } from "raea";
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
  lineHeight?: number;
  tracking?: string;
  nowrap?: boolean;
};

function Text({ text, left, top, width, size, color, mono = false, weight = 400, lineHeight = 1.2, tracking = "normal", nowrap = true }: TextProps) {
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
        lineHeight,
        letterSpacing: tracking,
        whiteSpace: nowrap ? "nowrap" : "pre-wrap",
      }}
    >
      {text}
    </div>
  );
}

function Line({ left, top, width, height = 1, color = "var(--brand-seam)" }: { left: number; top: number; width: number; height?: number; color?: string }) {
  return <div style={{ position: "absolute", left, top, width, height, backgroundColor: color }} />;
}

function Node({ left, top, width, height, title, detail }: { left: number; top: number; width: number; height: number; title: string; detail: string }) {
  return (
    <>
      <div
        style={{
          position: "absolute",
          left,
          top,
          width,
          height,
          boxSizing: "border-box",
          backgroundColor: "var(--brand-inset)",
          border: "1px solid var(--brand-seam-lit)",
        }}
      />
      <Text text={title} left={left + 14} top={top + 10} width={width - 28} size={16} color="var(--brand-text)" mono weight={500} tracking="0.04em" />
      <Text text={detail} left={left + 14} top={top + 34} width={width - 28} size={14} color="var(--brand-muted)" mono />
    </>
  );
}

function Hero() {
  return (
    <AbsoluteFill style={{ backgroundColor: "var(--brand-background)", color: "var(--brand-primary)" }}>
      <style>{css}</style>

      <Line left={72} top={42} width={1056} />
      <Text text="NODECODE  /  COMMUNITY CELL" left={72} top={62} width={480} size={14} color="var(--brand-muted)" mono weight={500} tracking="0.12em" />
      <Line left={72} top={102} width={34} height={2} color="var(--brand-accent)" />

      <div style={{ position: "absolute", left: 72, top: 135, display: "flex", alignItems: "baseline", fontFamily: "var(--brand-font-heading)", fontSize: 76, fontWeight: 500, lineHeight: 0.98, letterSpacing: "-0.04em" }}>
        <span style={{ color: "var(--brand-primary)" }}>Sub</span>
        <span style={{ color: "var(--brand-accent)" }}>agents</span>
      </div>
      <Text text="Named tasks. Detached sessions." left={74} top={238} width={500} size={22} color="var(--brand-secondary)" weight={400} />
      <Text text="Shared coordination through Nodecode Board." left={74} top={272} width={500} size={19} color="var(--brand-muted)" weight={400} />

      <Line left={72} top={344} width={470} />
      <Text text="TASK" left={74} top={364} width={100} size={13} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />
      <Text text="WORKERS" left={200} top={364} width={128} size={13} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />
      <Text text="BOARD" left={374} top={364} width={120} size={13} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />
      <Line left={164} top={370} width={18} height={1} color="var(--brand-seam-lit)" />
      <Line left={330} top={370} width={22} height={1} color="var(--brand-seam-lit)" />

      <div style={{ position: "absolute", left: 620, top: 50, width: 508, height: 380, boxSizing: "border-box", backgroundColor: "var(--brand-canvas)", border: "1px solid var(--brand-seam-lit)" }} />
      <div style={{ position: "absolute", left: 621, top: 51, width: 506, height: 38, backgroundColor: "var(--brand-inset)" }} />
      <Line left={621} top={89} width={506} color="var(--brand-seam)" />
      <div style={{ position: "absolute", left: 640, top: 67, width: 7, height: 7, backgroundColor: "var(--brand-accent)" }} />
      <Text text="WORKFLOW / NODECODE-SUBAGENTS" left={657} top={61} width={450} size={13} color="var(--brand-muted)" mono weight={500} tracking="0.08em" />

      <Text text="PARENT" left={646} top={105} width={130} size={12} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />
      <Text text="DETACHED CHILD SESSIONS" left={822} top={105} width={276} size={12} color="var(--brand-tertiary)" mono weight={500} tracking="0.12em" />

      <Node left={646} top={126} width={135} height={60} title="TASK" detail="assignment" />
      <Node left={822} top={126} width={276} height={60} title="WORKER 01" detail="named child session" />
      <Node left={822} top={213} width={276} height={60} title="WORKER 02" detail="named child session" />
      <Node left={646} top={334} width={452} height={62} title="NODECODE BOARD" detail="durable messages · replies · roster" />

      <Line left={781} top={155} width={21} height={2} color="var(--brand-accent)" />
      <Line left={801} top={155} width={2} height={88} color="var(--brand-accent)" />
      <Line left={801} top={155} width={21} height={2} color="var(--brand-accent)" />
      <Line left={801} top={242} width={21} height={2} color="var(--brand-accent)" />

      <Line left={1098} top={155} width={15} height={1} color="var(--brand-tertiary)" />
      <Line left={1098} top={242} width={15} height={1} color="var(--brand-tertiary)" />
      <Line left={1112} top={155} width={1} height={131} color="var(--brand-tertiary)" />
      <Line left={872} top={285} width={241} height={1} color="var(--brand-tertiary)" />
      <Line left={872} top={285} width={1} height={49} color="var(--brand-tertiary)" />
    </AbsoluteFill>
  );
}

registerRoot(() => <Composition id="readme-hero" component={Hero} width={1200} height={480} fps={30} durationInFrames={1} />);
