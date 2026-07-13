import type { CollectionEntry } from "astro:content";

export type Post = CollectionEntry<"posts">;

const dateParts = new Intl.DateTimeFormat("en-US", {
  timeZone: "America/New_York",
  year: "numeric",
  month: "2-digit",
  day: "2-digit"
});

export function postSlug(post: Post) {
  return post.id
    .replace(/\.(md|mdx)$/i, "")
    .replace(/^\d{4}-\d{2}-\d{2}-/, "");
}

export function postDateParts(post: Post) {
  const parts = Object.fromEntries(
    dateParts.formatToParts(post.data.date).map(({ type, value }) => [type, value])
  );

  return {
    year: parts.year,
    month: parts.month,
    day: parts.day
  };
}

export function postUrl(post: Post) {
  const { year, month, day } = postDateParts(post);
  return `/${year}/${month}/${day}/${postSlug(post)}.html`;
}

export function formatPostDate(date: Date) {
  return new Intl.DateTimeFormat("en-US", {
    timeZone: "America/New_York",
    year: "numeric",
    month: "long",
    day: "numeric"
  }).format(date);
}

export function postExcerpt(post: Post, maxLength = 220) {
  if (post.data.description) return post.data.description;

  const excerpt = (post.body ?? "")
    .split("<!--more-->")[0]
    .replace(/```[\s\S]*?```/g, " ")
    .replace(/<[^>]+>/g, " ")
    .replace(/!\[[^\]]*\]\([^)]*\)/g, " ")
    .replace(/\[([^\]]+)\]\([^)]*\)/g, "$1")
    .replace(/[#>*_`~-]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (excerpt.length <= maxLength) return excerpt;
  return `${excerpt.slice(0, maxLength).replace(/\s+\S*$/, "")}…`;
}

export function readingTime(post: Post) {
  const words = (post.body ?? "")
    .replace(/<[^>]+>/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean).length;
  return Math.max(1, Math.ceil(words / 220));
}

export function sortPosts(posts: Post[]) {
  return [...posts].sort((a, b) => b.data.date.valueOf() - a.data.date.valueOf());
}

export function termSlug(term: string) {
  return term
    .normalize("NFKD")
    .replace(/[\u0300-\u036f]/g, "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");
}

export function getTerms(posts: Post[], field: "categories" | "tags") {
  const terms = new Map<string, { label: string; posts: Post[] }>();

  for (const post of posts) {
    for (const term of post.data[field]) {
      const slug = termSlug(term);
      const existing = terms.get(slug) ?? { label: term.trim(), posts: [] };
      if (!existing.posts.some((entry) => entry.id === post.id)) existing.posts.push(post);
      terms.set(slug, existing);
    }
  }

  return [...terms.values()]
    .map(({ label, posts: entries }) => [label, entries] as [string, Post[]])
    .sort(([a], [b]) => a.localeCompare(b));
}
