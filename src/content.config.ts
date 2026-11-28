import { defineCollection } from "astro:content";
import { glob } from "astro/loaders";
import { z } from "astro/zod";
import { PILLARS, PILLAR_META } from "./config/taxonomy";

export { PILLARS };

const posts = defineCollection({
  loader: glob({ pattern: "**/*.{md,mdx}", base: "./src/content/posts" }),
  schema: z
    .object({
      title: z.string().min(1),
      description: z.string().min(10).max(240),
      pubDate: z.coerce.date(),
      updatedDate: z.coerce.date().optional(),
      pillar: z.enum(PILLARS),
      tags: z
        .array(z.string().regex(/^[a-z0-9-]+$/))
        .max(6)
        .default([]),
      legacyCategories: z.array(z.string()).optional(),
      hasTool: z.boolean().default(false),
      draft: z.boolean().default(false),
      validation: z
        .object({
          posture: z.enum([
            "read-only",
            "preview-first",
            "observe-default",
            "lab-verified",
            "reference"
          ]),
          testedOn: z.string(),
          limits: z.string().optional()
        })
        .optional(),
      image: z.string().optional(),
      imageAlt: z.string().optional(),
      imageWidth: z.number().int().positive().optional(),
      imageHeight: z.number().int().positive().optional(),
      excerpt_separator: z.string().optional()
    })
    .refine(
      (data) => {
        const pillarTitleLower = PILLAR_META[data.pillar].title.toLowerCase();
        return (
          !data.tags.includes(data.pillar) &&
          !data.tags.some((t) => t.toLowerCase() === pillarTitleLower) &&
          new Set(data.tags).size === data.tags.length
        );
      },
      { message: "Tag must be unique and must not duplicate pillar slug or label." }
    )
});

const pages = defineCollection({
  loader: glob({ pattern: "**/*.md", base: "./src/content/pages" }),
  schema: z.object({
    title: z.string(),
    description: z.string().optional(),
    date: z.coerce.date().optional(),
    permalink: z.string().optional(),
    sitemap: z.boolean().optional()
  })
});

export const collections = { posts, pages };
