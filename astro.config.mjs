import { defineConfig } from "astro/config";
import expressiveCode from "astro-expressive-code";

export default defineConfig({
  site: "https://nocthoughts.com",
  output: "static",
  build: {
    format: "file"
  },
  integrations: [
    expressiveCode({
      themes: ["github-dark", "github-light"],
      useDarkModeMediaQuery: false,
      minSyntaxHighlightingColorContrast: 5.5,
      themeCssSelector: (theme) =>
        theme.type === "light"
          ? '[data-theme="paper"]'
          : ':is([data-theme="aftertone"], [data-theme="polar"], [data-theme="cyberpunk"], [data-theme="moss-brass"])',
      styleOverrides: {
        borderRadius: "8px",
        borderWidth: "1px",
        codeFontFamily: '"JetBrains Mono", ui-monospace, SFMono-Regular, Consolas, monospace',
        codeFontSize: "0.875rem",
        codeLineHeight: "1.6",
        uiFontFamily: '"JetBrains Mono", ui-monospace, SFMono-Regular, Consolas, monospace',
        uiFontSize: "0.75rem",
        codeBackground: ({ theme }) => (theme.type === "light" ? "#FFFFFF" : "#0B0D10"),
        borderColor: ({ theme }) =>
          theme.type === "light" ? "rgba(23, 25, 28, 0.16)" : "rgba(255, 255, 255, 0.10)",
        frames: {
          editorTabBarBackground: ({ theme }) => (theme.type === "light" ? "#EBE7DF" : "#15181D"),
          editorActiveTabBackground: ({ theme }) => (theme.type === "light" ? "#FFFFFF" : "#0B0D10"),
          editorActiveTabForeground: ({ theme }) => (theme.type === "light" ? "#17191C" : "#ECEEF2"),
          terminalTitlebarBackground: ({ theme }) => (theme.type === "light" ? "#EBE7DF" : "#15181D"),
          terminalTitlebarForeground: ({ theme }) => (theme.type === "light" ? "#4B525C" : "#9CA3AF"),
          terminalBackground: ({ theme }) => (theme.type === "light" ? "#FFFFFF" : "#0B0D10"),
          shadowColor: "transparent"
        }
      }
    })
  ]
});
