# Doto (self-hosted)

`Doto[ROND,wght].ttf` is the official variable font from [google/fonts `ofl/doto`](https://github.com/google/fonts/tree/main/ofl/doto), licensed under the SIL Open Font License 1.1 (see `OFL.txt`).

It has two axes:
- `wght`: 100–900
- `ROND` (roundness): 0–100

The puls3 brand uses **weight 900 with ROND 100**, which gives round dots that match the C01 halftone. The Google Fonts web API only serves weight instances and **can't set the ROND axis**, so we self-host the file.

Use it for accents only: stats, status and loading labels, and event graphics. Never for the logo or for body text.

## Flutter

```yaml
# pubspec.yaml
flutter:
  fonts:
    - family: Doto
      fonts:
        - asset: assets/brand/fonts/Doto[ROND,wght].ttf
```

```dart
const dotoAccent = TextStyle(
  fontFamily: 'Doto',
  fontVariations: [
    FontVariation('ROND', 100),
    FontVariation('wght', 900),
  ],
);
```

## Web

```css
@font-face {
  font-family: "Doto ROND";
  src: url("/fonts/Doto[ROND,wght].ttf") format("truetype");
  font-weight: 100 900;
}
.stat {
  font-family: "Doto ROND", monospace;
  font-variation-settings: "ROND" 100, "wght" 900;
}
```
