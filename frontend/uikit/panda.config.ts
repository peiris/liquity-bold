import { defineConfig, definePreset } from "@pandacss/dev";
import { colors, lightTheme } from "./src/Theme/Theme";

const tokenColors = Object.fromEntries(
  Object.entries(colors).map(([key, value]) => [
    key,
    { value },
  ]),
);

const semanticColors = Object.fromEntries(
  Object.entries(lightTheme.colors).map(([key, value]) => [
    key,
    {
      value: `{colors.${value}}`,
      // this is where the dark theme can be added, see https://panda-css.com/docs/theming/tokens
      // _dark: `{colors.${otherValue}}`,
    },
  ]),
);

export const liquityUiKitPreset = definePreset({
  theme: {
    tokens: {
      colors: tokenColors,
      fonts: {
        body: { value: "Geist, sans-serif" },
      },
    },
    semanticTokens: {
      colors: semanticColors,
    },
  },
});

export default defineConfig({
  preflight: true, // CSS reset
  presets: [liquityUiKitPreset],
  include: ["./src/**/*.{ts,tsx}"],
  exclude: [],
  outdir: "styled-system",
});