# Content guide

## URL policy

Existing posts retain their published URLs exactly, including the `.html` suffix. The URL date comes from front matter, not necessarily the filename, because that matches Jekyll's historical behavior.

Changing a post's `date` or filename changes its public URL. If either must change, add a redirect before publishing.

## Front matter

Required fields:

- `title`: reader-facing title
- `date`: publication time with an explicit UTC offset
- `categories`: one or more broad operational domains
- `tags`: specific products, technologies, and concepts

Optional fields:

- `description`: custom archive and SEO summary
- `draft`: set to `true` to exclude the post from builds

Legacy `layout`, `classes`, and `excerpt_separator` fields remain accepted so migrated posts can stay editorially intact. New posts do not need them.

## Excerpts

Use `<!--more-->` after the introductory passage to control archive and SEO excerpts. If it is omitted, the site derives a shortened excerpt from the beginning of the post.

## Images and code

Store repository-hosted images in `public/assets/images`. Use descriptive alternative text:

```md
![CUCM registration summary](/assets/images/registration-summary.png)
```

Use fenced code blocks with a language identifier:

````md
```python
print("signal acquired")
```
````

## Pre-publication check

Run:

```sh
npm run validate
```

This fails if a local link or image is missing, a historical sitemap URL disappears, or the migrated archive count changes unexpectedly.
