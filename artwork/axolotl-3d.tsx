import { AbsoluteFill, Composition, registerRoot, useCurrentFrame } from "raea";
import { AmbientLight, DirectionalLight } from "raea/light";
import { Camera3d } from "raea/camera";
import { Transform } from "raea/transform";
import { Axolotl } from "./axolotl-model";

const WIDTH = 240;
const HEIGHT = 160;
const FRAMES = 96;
const FPS = 24;

type SwimProps = {
  phase: number;
  yaw: number;
  direction: number;
  tint: string;
};

function Swim({ phase, yaw, direction, tint }: SwimProps) {
  const frame = useCurrentFrame();
  const cycle = (frame / FRAMES) * Math.PI * 2;
  const drift = Math.sin(cycle + phase) * 0.32 * direction;
  return (
    <AbsoluteFill style={{ background: tint }}>
      <Camera3d
        transform={Transform.fromXyz(0.62, 0.72, 3.8).lookingAt([0, 0, 0])}
        projection={{ Perspective: { fov: (44 * Math.PI) / 180 } }}
      />
      <AmbientLight brightness={150} />
      <DirectionalLight
        transform={Transform.fromXyz(-2.8, 4.2, 5).lookingAt([0, 0, 0])}
        illuminance={9800}
      />
      <Axolotl phase={phase} loopFrames={FRAMES} yaw={yaw} scale={0.9} x={drift} y={0.02 + Math.sin(cycle * 2 + phase) * 0.04} />
    </AbsoluteFill>
  );
}

function Setup() { return <Swim phase={0} yaw={0.18} direction={1} tint="#000000" />; }
function Configure() { return <Swim phase={1.5} yaw={-0.35} direction={-1} tint="#000000" />; }
function EvalApis() { return <Swim phase={3.1} yaw={0.42} direction={1} tint="#000000" />; }
function Sessions() { return <Swim phase={4.7} yaw={-0.16} direction={-1} tint="#000000" />; }

registerRoot(() => (
  <>
    <Composition id="axolotl-setup" component={Setup} width={WIDTH} height={HEIGHT} fps={FPS} durationInFrames={FRAMES} />
    <Composition id="axolotl-configure" component={Configure} width={WIDTH} height={HEIGHT} fps={FPS} durationInFrames={FRAMES} />
    <Composition id="axolotl-eval-apis" component={EvalApis} width={WIDTH} height={HEIGHT} fps={FPS} durationInFrames={FRAMES} />
    <Composition id="axolotl-sessions" component={Sessions} width={WIDTH} height={HEIGHT} fps={FPS} durationInFrames={FRAMES} />
  </>
));
