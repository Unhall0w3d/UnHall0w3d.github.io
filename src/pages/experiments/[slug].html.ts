import type { APIRoute } from "astro";
import header from "../../components/site-header.html?raw";

export function getStaticPaths() {
  const documents = import.meta.glob<string>("../../experiments/*.html", {
    query: "?raw", import: "default", eager: true,
  });
  return Object.entries(documents).map(([path, html]) => ({
    params: { slug: path.split("/").pop()!.replace(/\.html$/, "") },
    props: { html },
  }));
}

export const GET: APIRoute = ({ props }) =>
  new Response(props.html.replace("<!-- SITE_HEADER -->", () => header), {
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
