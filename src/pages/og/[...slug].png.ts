import fs from "node:fs";
import path from "node:path";
import { Resvg } from "@resvg/resvg-js";
import type { APIRoute } from "astro";
import { getCollection } from "astro:content";
import satori from "satori";
import { pillarTitle } from "../../config/taxonomy";
import { formatPostDate, postDateParts, postSlug, readingTime, sortPosts, type Post } from "../../lib/posts";

const fontRoot = path.join(process.cwd(), "node_modules/@fontsource");
const spaceGroteskBold = fs.readFileSync(
  path.join(fontRoot, "space-grotesk/files/space-grotesk-latin-700-normal.woff")
);
const interRegular = fs.readFileSync(
  path.join(fontRoot, "inter/files/inter-latin-400-normal.woff")
);
const jetbrainsMonoMedium = fs.readFileSync(
  path.join(fontRoot, "jetbrains-mono/files/jetbrains-mono-latin-500-normal.woff")
);

type CardProps = {
  pillar: string;
  era: string;
  title: string;
  subtitle: string;
  dateText: string;
  readTimeText: string;
};

export async function getStaticPaths() {
  const posts = sortPosts((await getCollection("posts", ({ data }) => !data.draft)) as Post[]);

  const staticPages: Array<{ params: { slug: string }; props: CardProps }> = [
    {
      params: { slug: "index" },
      props: {
        pillar: "SIGNAL CONSOLE",
        era: "6.830 MHz",
        title: "Where network operations meet local AI.",
        subtitle: "Cisco UC procedures, preview-first automation scripts, and local multi-GPU agent engineering.",
        dateText: "NOCTHOUGHTS.COM",
        readTimeText: `${posts.length} SIGNALS INDEXED`
      }
    },
    {
      params: { slug: "posts" },
      props: {
        pillar: "SIGNAL ARCHIVE",
        era: "FIELD NOTES",
        title: "Field Notes & Operational Dispatches",
        subtitle: "Unified communications, automation tooling, local AI agents, and systems infrastructure.",
        dateText: "NOCTHOUGHTS.COM/POSTS.HTML",
        readTimeText: `${posts.length} DISPATCHES`
      }
    },
    {
      params: { slug: "tools" },
      props: {
        pillar: "FIELD TOOLBOX",
        era: "SPEC CARDS",
        title: "Tools, Read-Only SQL & Backup Specifications",
        subtitle: "Explicit safety postures, lab validation boundaries, and SHA-256 verified downloads.",
        dateText: "NOCTHOUGHTS.COM/TOOLS.HTML",
        readTimeText: "PREVIEW FIRST"
      }
    },
    {
      params: { slug: "experiments" },
      props: {
        pillar: "THE SIGNAL LAB",
        era: "INSTRUMENTS",
        title: "Telemetry, Acoustics & Local Compute Studies",
        subtitle: "Local LLM Observatory, Kestrel Sound, Aftertone, and Fold Register.",
        dateText: "NOCTHOUGHTS.COM/EXPERIMENTS.HTML",
        readTimeText: "4 LIVE INSTRUMENTS"
      }
    },
    {
      params: { slug: "about" },
      props: {
        pillar: "OPERATOR PROFILE",
        era: "SYRACUSE, NY",
        title: "Kenneth Perry — UC & Automation Engineer",
        subtitle: "Infrastructure diagnostics, Collaboration engineering, and bounded local AI workflows.",
        dateText: "NOCTHOUGHTS.COM/ABOUT.HTML",
        readTimeText: "OPERATOR // 01"
      }
    }
  ];

  const postPaths = posts.map((post) => {
    const { year, month, day } = postDateParts(post);
    const slug = `${year}/${month}/${day}/${postSlug(post)}`;
    const era = Number(year) >= 2026 ? "2026 SPEC" : `ARCHIVE NOTE · ${year}`;
    return {
      params: { slug },
      props: {
        pillar: pillarTitle(post.data.pillar).toUpperCase(),
        era,
        title: post.data.title,
        subtitle: post.data.description,
        dateText: formatPostDate(post.data.pubDate).toUpperCase(),
        readTimeText: `${readingTime(post)} MIN READ`
      }
    };
  });

  return [...staticPages, ...postPaths];
}

export const GET: APIRoute = async ({ props }) => {
  const { pillar, era, title, subtitle, dateText, readTimeText } = props as CardProps;
  const titleFontSize = title.length > 68 ? 46 : title.length > 46 ? 54 : 62;
  const clampedSubtitle =
    subtitle.length > 150 ? `${subtitle.slice(0, 147).replace(/\s+\S*$/, "")}…` : subtitle;

  const element = {
    type: "div",
    props: {
      style: {
        width: "1200px",
        height: "630px",
        display: "flex",
        flexDirection: "column",
        justifyContent: "space-between",
        padding: "56px 64px",
        backgroundColor: "#0E1013",
        color: "#ECEEF2",
        fontFamily: "Inter",
        border: "1px solid rgba(255,255,255,0.12)"
      },
      children: [
        // Top Header Bar
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              paddingBottom: "24px",
              borderBottom: "1px solid rgba(255,255,255,0.12)"
            },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    display: "flex",
                    alignItems: "center",
                    gap: "14px"
                  },
                  children: [
                    {
                      type: "div",
                      props: {
                        style: {
                          width: "12px",
                          height: "12px",
                          borderRadius: "999px",
                          backgroundColor: "#38C6B8"
                        }
                      }
                    },
                    {
                      type: "span",
                      props: {
                        style: {
                          fontFamily: "Space Grotesk",
                          fontSize: "22px",
                          fontWeight: 700,
                          letterSpacing: "0.06em",
                          color: "#ECEEF2"
                        },
                        children: "NOC THOUGHTS"
                      }
                    },
                    {
                      type: "span",
                      props: {
                        style: {
                          fontFamily: "JetBrains Mono",
                          fontSize: "16px",
                          color: "#848D9C",
                          marginLeft: "8px"
                        },
                        children: "// AFTERTONE TELEMETRY"
                      }
                    }
                  ]
                }
              },
              {
                type: "div",
                props: {
                  style: {
                    display: "flex",
                    alignItems: "center",
                    gap: "12px"
                  },
                  children: [
                    {
                      type: "span",
                      props: {
                        style: {
                          padding: "6px 14px",
                          borderRadius: "999px",
                          backgroundColor: "rgba(56, 198, 184, 0.14)",
                          border: "1px solid rgba(56, 198, 184, 0.35)",
                          color: "#38C6B8",
                          fontFamily: "JetBrains Mono",
                          fontSize: "15px",
                          letterSpacing: "0.05em"
                        },
                        children: pillar
                      }
                    },
                    {
                      type: "span",
                      props: {
                        style: {
                          padding: "6px 14px",
                          borderRadius: "4px",
                          backgroundColor: "#15181D",
                          border: "1px solid rgba(255, 255, 255, 0.14)",
                          color: "#E5A448",
                          fontFamily: "JetBrains Mono",
                          fontSize: "15px",
                          letterSpacing: "0.05em"
                        },
                        children: era
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        // Center Title & Subtitle
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              flexDirection: "column",
              gap: "22px",
              marginTop: "12px",
              marginBottom: "12px"
            },
            children: [
              {
                type: "div",
                props: {
                  style: {
                    fontFamily: "Space Grotesk",
                    fontSize: `${titleFontSize}px`,
                    fontWeight: 700,
                    lineHeight: 1.1,
                    letterSpacing: "-0.025em",
                    color: "#ECEEF2"
                  },
                  children: title
                }
              },
              {
                type: "div",
                props: {
                  style: {
                    fontFamily: "Inter",
                    fontSize: "24px",
                    lineHeight: 1.45,
                    color: "#9CA3AF",
                    maxWidth: "1020px"
                  },
                  children: clampedSubtitle
                }
              }
            ]
          }
        },
        // Bottom Telemetry Footer
        {
          type: "div",
          props: {
            style: {
              display: "flex",
              alignItems: "center",
              justifyContent: "space-between",
              paddingTop: "22px",
              borderTop: "1px solid rgba(255,255,255,0.12)",
              fontFamily: "JetBrains Mono",
              fontSize: "17px",
              color: "#848D9C",
              letterSpacing: "0.05em"
            },
            children: [
              {
                type: "span",
                props: {
                  children: `${dateText} // KENNETH PERRY`
                }
              },
              {
                type: "span",
                props: {
                  style: {
                    color: "#E5A448"
                  },
                  children: readTimeText
                }
              }
            ]
          }
        }
      ]
    }
  };

  const svg = await satori(element as any, {
    width: 1200,
    height: 630,
    fonts: [
      {
        name: "Space Grotesk",
        data: spaceGroteskBold,
        weight: 700,
        style: "normal"
      },
      {
        name: "Inter",
        data: interRegular,
        weight: 400,
        style: "normal"
      },
      {
        name: "JetBrains Mono",
        data: jetbrainsMonoMedium,
        weight: 500,
        style: "normal"
      }
    ]
  });

  const resvg = new Resvg(svg, {
    fitTo: { mode: "width", value: 1200 }
  });
  const pngBuffer = resvg.render().asPng();

  return new Response(new Uint8Array(pngBuffer), {
    headers: {
      "Content-Type": "image/png"
    }
  });
};
