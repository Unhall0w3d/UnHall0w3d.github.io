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
    items: posts.map((post) => ({
      title: post.data.title,
      description: postExcerpt(post),
      pubDate: post.data.date,
      link: postUrl(post),
      categories: [...post.data.categories, ...post.data.tags]
    })),
    customData: `<language>en-us</language>`
  });
}
