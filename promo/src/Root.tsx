import React from "react";
import { Composition } from "remotion";
import { Promo } from "./Promo";
import { Mockup } from "./Mockup";
import { FPS, H, TOTAL_FRAMES, W } from "./timeline";

export const RemotionRoot: React.FC = () => {
  return (
    <>
    <Composition
      id="Mockup"
      component={Mockup}
      durationInFrames={1}
      fps={FPS}
      width={W}
      height={H}
      defaultProps={{ f: 26 }}
    />
    <Composition
      id="SoftNotesPromo"
      component={Promo}
      durationInFrames={TOTAL_FRAMES}
      fps={FPS}
      width={W}
      height={H}
    />
    </>
  );
};
