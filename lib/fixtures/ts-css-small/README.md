# ts-css-small — CSS Modules bridge fixture (Spike S6)

Juba (the S6 real-project target) uses Tailwind + one global CSS file, so
the CSS-Modules bridge cannot be exercised against it. This fixture fills
that gap:

- `Button.module.css` — three class selectors: `.primary`, `.secondary`,
  `.disabled`.
- `Button.tsx` — `import styles from "./Button.module.css"`, references
  `styles.primary` and `styles.secondary` (both resolve).
- `Bad.tsx` — references `styles.doesNotExist` (stays unresolved with a
  diagnostic flag).

Expected probe outcome: 3 `CSSClass` entities, 2 resolved references, 1
unresolved. Keep small and deterministic; S6 tests the pipeline shape,
not edge cases.
