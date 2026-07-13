import { defineConfig } from "astro/config";
import sitemap from "@astrojs/sitemap";

export default defineConfig({
  site: "https://nocthoughts.com",
  output: "static",
  integrations: [sitemap()],
  build: {
    format: "file"
  }
});
