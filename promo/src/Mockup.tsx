import React from "react";
import { AbsoluteFill } from "remotion";
import { FlowScreen } from "./Flow";
import { Backdrop, PhoneWorld } from "./ui/Stage";

/** Still-only composition: the app on the soft backdrop at one logical frame `f`
 *  of the promo timeline (no captions, no finger). Used for README mockups. */
export const Mockup: React.FC<{ f: number }> = ({ f }) => (
  <AbsoluteFill>
    <Backdrop frame={f} />
    <PhoneWorld cam={{ s: 2.0, fx: 196.5, fy: 426, cy: 960 }}>
      <FlowScreen f={f} noFinger />
    </PhoneWorld>
  </AbsoluteFill>
);
