import { defineConfig } from "astro/config";

export default defineConfig({
  site: "https://nocthoughts.com",
  output: "static",
  build: {
    format: "file"
  }
});
