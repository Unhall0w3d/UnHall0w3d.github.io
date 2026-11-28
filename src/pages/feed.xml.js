import rss from "@astrojs/rss";
import { getCollection } from "astro:content";
import { site } from "../config/site";
import { postExcerpt, postUrl, sortPosts } from "../lib/posts";

export async function GET(context) {
  const posts = sortPosts(await getCollection("posts", ({ data }) => !data.draft));

  return rss({
    title: site.title,
    description: site.description,
    site: context.site,
    items: posts.map((post) => {
      const rawCategories = [post.data.pillar, ...post.data.tags];
      const seen = new Set();
      const categories = [];
      for (const label of rawCategories) {
        const normalized = label.trim().toLowerCase();
        if (seen.has(normalized)) {
          throw new Error(
            `Duplicate RSS category/tag label "${label}" on post "${post.id}"`
          );
        }
        seen.add(normalized);
        categories.push(label);
      }

      return {
        title: post.data.title,
        description: postExcerpt(post),
        pubDate: post.data.pubDate,
        link: postUrl(post),
        categories
      };
    }),
    customData: `<language>en-us</language>`
  });
}
