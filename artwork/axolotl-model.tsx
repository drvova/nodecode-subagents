import { useCurrentFrame } from "raea";
import { Entity, crossSection, type Solid } from "raea/3d";
import { Mesh3d } from "raea/mesh";
import { StandardMaterial } from "raea/pbr";
import { Quat, Transform } from "raea/transform";
import axolotl from "./axo-pixels.json";

type AxolotlProps = {
  phase?: number;
  yaw?: number;
  scale?: number;
  x?: number;
  y?: number;
  z?: number;
  loopFrames?: number;
};

type Rectangle = [number, number, number, number];
type PixelLayer = { fill: string; rectangles: Rectangle[] };
type PartId =
  | "body"
  | "gill-left-upper"
  | "gill-left-side"
  | "gill-left-inner"
  | "gill-right-upper"
  | "gill-right-side"
  | "limb-left"
  | "limb-right"
  | "eyes";
type PartDefinition = {
  id: PartId;
  pivot: [number, number];
  amplitude: number;
  depthAmplitude: number;
  frequency: number;
  phase: number;
  direction: number;
};
type LayerShapes = { fill: string; shapes: Record<PartId, Solid | null> };

const [WIDTH, HEIGHT] = axolotl.viewBox;
const DEPTH = 0.32;
const LAYER_STEP = 0.04;
const SVG_SCALE = 0.01;
const TAU = Math.PI * 2;
const EYE_FILL = axolotl.layers[axolotl.layers.length - 1].fill;

const LEFT_LIMB_PIVOT: [number, number] = [84, 181];
const RIGHT_LIMB_PIVOT: [number, number] = [252, 181];

const PARTS: PartDefinition[] = [
  { id: "body", pivot: [156, 133], amplitude: 0, depthAmplitude: 0, frequency: 0, phase: 0, direction: 0 },
  { id: "gill-left-upper", pivot: [80, 94], amplitude: 0.25, depthAmplitude: 0.08, frequency: 2, phase: 0.1, direction: 1 },
  { id: "gill-left-side", pivot: [78, 109], amplitude: 0.21, depthAmplitude: 0.07, frequency: 2, phase: 0.8, direction: -1 },
  { id: "gill-left-inner", pivot: [99, 72], amplitude: 0.14, depthAmplitude: 0.05, frequency: 2, phase: 1.3, direction: 1 },
  { id: "gill-right-upper", pivot: [264, 92], amplitude: 0.23, depthAmplitude: 0.08, frequency: 2, phase: 0.55, direction: -1 },
  { id: "gill-right-side", pivot: [270, 107], amplitude: 0.19, depthAmplitude: 0.07, frequency: 2, phase: 1.1, direction: 1 },
  { id: "limb-left", pivot: LEFT_LIMB_PIVOT, amplitude: 0.36, depthAmplitude: 0.08, frequency: 1, phase: 0, direction: 1 },
  { id: "limb-right", pivot: RIGHT_LIMB_PIVOT, amplitude: 0.36, depthAmplitude: 0.08, frequency: 1, phase: Math.PI, direction: 1 },
  { id: "eyes", pivot: [184, 76], amplitude: 0, depthAmplitude: 0, frequency: 0, phase: 0, direction: 0 },
];

function partFor(rectangle: Rectangle, fill: string): PartId {
  const [x, y, width, height] = rectangle;
  const centerX = x + width / 2;
  const centerY = y + height / 2;

  if (fill === EYE_FILL) return "eyes";
  if (centerY < 96 && centerX < 82) return "gill-left-upper";
  if (centerY >= 96 && centerY < 137 && centerX < 82) return "gill-left-side";
  if (centerY < 76 && centerX >= 82 && centerX < 120) return "gill-left-inner";
  if (centerY < 96 && centerX > 264) return "gill-right-upper";
  if (centerY >= 96 && centerY < 137 && centerX > 276) return "gill-right-side";
  if (centerY >= LEFT_LIMB_PIVOT[1] && centerX < 104) return "limb-left";
  if (centerY >= RIGHT_LIMB_PIVOT[1] && centerX > 218) return "limb-right";
  return "body";
}

function makeSolid(rectangles: Rectangle[], pivot: [number, number], layerIndex: number): Solid | null {
  if (rectangles.length === 0) return null;

  const [pivotX, pivotY] = pivot;
  const sections = rectangles.map(([x, y, width, height]) =>
    crossSection
      .rect(width * SVG_SCALE, height * SVG_SCALE)
      .move((x + width / 2 - pivotX) * SVG_SCALE, (pivotY - y - height / 2) * SVG_SCALE),
  );
  const section = sections.length === 1 ? sections[0] : sections[0].union(...sections.slice(1));
  const z = -DEPTH / 2 + layerIndex * LAYER_STEP;
  return section.extrude(DEPTH).move(0, 0, z);
}

const LAYER_SHAPES: LayerShapes[] = (axolotl.layers as PixelLayer[]).map((layer, layerIndex) => {
  const grouped = Object.fromEntries(PARTS.map((part) => [part.id, []])) as Record<PartId, Rectangle[]>;
  for (const rectangle of layer.rectangles) grouped[partFor(rectangle, layer.fill)].push(rectangle);

  const shapes = {} as Record<PartId, Solid | null>;
  for (const part of PARTS) shapes[part.id] = makeSolid(grouped[part.id], part.pivot, layerIndex);
  return { fill: layer.fill, shapes };
});

function LayerMeshes({ part }: { part: PartId }) {
  return (
    <>
      {LAYER_SHAPES.map(({ fill, shapes }, layerIndex) => {
        const shape = shapes[part];
        if (!shape) return null;
        return (
          <Mesh3d
            key={`axolotl-${part}-${layerIndex}`}
            name={`axolotl-${part}-${layerIndex}`}
            allowOverlap
            transform={Transform.IDENTITY}
            shape={shape}
          >
            <StandardMaterial base_color={fill} perceptual_roughness={0.48} clearcoat={0.18} />
          </Mesh3d>
        );
      })}
    </>
  );
}

export function Axolotl({ phase = 0, yaw = 0.18, scale = 1, x = 0, y = 0, z = 0, loopFrames = 144 }: AxolotlProps) {
  const frame = useCurrentFrame();
  const cycle = (frame / loopFrames) * TAU + phase;
  const bob = Math.sin(cycle) * 0.065;
  const pitch = Math.sin(cycle + 0.55) * 0.11;
  const yawSway = yaw + Math.sin(cycle - 0.7) * 0.19;
  const roll = Math.sin(cycle + 0.25) * 0.08;
  const breath = Math.sin(cycle * 2 + 0.3) * 0.028;
  const loopProgress = ((frame / loopFrames + phase / TAU) % 1 + 1) % 1;
  const blink = Math.max(0, 1 - Math.abs(loopProgress - 0.63) / 0.018);
  const eyeScaleY = 1 - blink * 0.92;
  return (
    <Entity
      transform={Transform.fromXyz(x, y + bob, z)
        .withRotation(Quat.fromEuler("XYZ", pitch, yawSway, roll))
        .withScale([scale * (1 - breath * 0.25), scale * (1 + breath), scale])}
    >
      <Entity transform={Transform.IDENTITY}>
        <LayerMeshes part="body" />
      </Entity>
      {PARTS.filter((part) => part.id !== "body").map((part) => {
        const partCycle = cycle * part.frequency + part.phase;
        const angle = Math.sin(partCycle) * part.amplitude * part.direction;
        const depthAngle = Math.sin(partCycle - 0.65) * part.depthAmplitude * part.direction;
        const pivotX = (part.pivot[0] - WIDTH / 2) * SVG_SCALE;
        const pivotY = (HEIGHT / 2 - part.pivot[1]) * SVG_SCALE;
        const scaleY = part.id === "eyes" ? eyeScaleY : 1;
        return (
          <Entity
            key={part.id}
            transform={Transform.fromXyz(pivotX, pivotY, 0)
              .withRotation(Quat.fromEuler("XYZ", depthAngle, depthAngle * 0.35, angle))
              .withScale([1, scaleY, 1])}
          >
            <LayerMeshes part={part.id} />
          </Entity>
        );
      })}
    </Entity>
  );
}
