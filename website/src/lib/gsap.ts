import gsap from "gsap";
import { ScrollTrigger } from "gsap/ScrollTrigger";
import { Observer } from "gsap/Observer";
import { SplitText } from "gsap/SplitText";
import { Flip } from "gsap/Flip";
import { MotionPathPlugin } from "gsap/MotionPathPlugin";
import { DrawSVGPlugin } from "gsap/DrawSVGPlugin";
import { useGSAP } from "@gsap/react";

gsap.registerPlugin(useGSAP, ScrollTrigger, Observer, SplitText, Flip, MotionPathPlugin, DrawSVGPlugin);

export { gsap, ScrollTrigger, Observer, SplitText, Flip, MotionPathPlugin, DrawSVGPlugin, useGSAP };
