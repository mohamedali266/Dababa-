## 6a. Motion

Use the `motion` package (`motion/react`) plus CSS where enough. Wrap the app in `MotionConfig reducedMotion="user"` and honor `prefers-reduced-motion` everywhere (replace movement with a simple fade or nothing).

Use motion with purpose:

- Route/page transitions and shared-element feel between list and detail.
- Staggered entrance for lists and dashboard stats.
- Card: subtle entrance, QR refresh transition, countdown bar.
- Numbers: count-up for stats and personal records.
- Progress ring/bar fill, set-complete check, bottom sheet and dialog enter/exit.
- Button press feedback.

Rules: animate `transform` and `opacity` only; 150 to 400 ms; ease-out curves; no bounce or elastic; no layout shift (CLS); directional animations must respect RTL (slide in from the correct side); lazy-load heavy animation code; never block interaction while animating; keep 60fps on a mid-range phone. Put durations and easings in shared tokens.

