---
title: "NOC Thoughts, Rewired"
date: 2026-07-13T08:00:00-04:00
categories:
  - General
  - Web Development
tags:
  - Astro
  - GitHub Pages
  - NOC Thoughts
  - Website
  - General
description: "A look at the rebuilt NOC Thoughts website, what survived the migration, and how to navigate the new signal."
---

## Well, This Looks Different

Hey there! If you have been to NOC Thoughts before, your first thought was probably something along the lines of, “Wait... am I on the right website?”

You are. I just changed virtually everything around you.

The old NOC Thoughts site had been online for years using Jekyll and the Minimal Mistakes theme. It worked, the posts were readable, and I was able to occasionally drop another overly specific Cisco query onto the internet before disappearing back into the NOC. It did what I needed it to do.

The problem was that I wanted to do more with it.<!--more-->

I wanted the site to feel less like a blog wearing a theme and more like *NOC Thoughts*. Something dark, a little strange, and somewhere between a network operations console and whatever techno-sorcery looks like when it has a CSS file.

Once “next-generation cyberpunk techno-sorcery” entered the conversation as a design goal, there was really no going back.

## So I Rebuilt The Blog

This started innocently enough. I wanted more control over the design and thought it would be worth looking at what could be changed.

One thing led to another, the old theme started coming apart, Astro entered the picture, and suddenly the blog was in the middle of a full platform migration. You know how it goes. You open something up to make one adjustment and three hours later there are parts all over the floor and you are telling yourself this was definitely the plan.

The new site is built with [Astro](https://astro.build/) and is still hosted through GitHub Pages. That means the posts can remain simple Markdown files while the surrounding site is something we have complete control over.

It also means I am no longer negotiating with an existing theme every time I decide a page needs to look or behave differently. If I want glowing cyan lines, purple text that looks vaguely magical, or a picture of myself that flips over to reveal a system sigil, I can do that.

So I did.

Go ahead and click the picture in the **System Signal** panel on the home page. It flips around to show the new NOC Thoughts sigil. Click it again and, assuming the operator has not escaped, I should reappear.

Was this the most important part of rebuilding the website? No. Was it one of the first things I showed people after it worked? Absolutely.

## Did Everything Survive?

The good news is that I did not feed the old blog into the void in exchange for neon lights.

All 52 existing posts made the trip, along with the screenshots, code samples, queries, and other files attached to them. The old post addresses were also preserved, so bookmarks and links to previous articles should continue working.

That was important to me. There is a lot of history in the archive—not just technical information, but a record of what I was working on, what I was learning, and apparently how often I decided the answer to a problem was “I should write a script for this.”

The RSS feed, custom domain, search-related files, analytics, and the other bits living behind the curtain came along too. Most readers will never see those parts, which is generally the sign that they are doing their job.

If you do find an older post with a missing screenshot, broken link, or formatting that appears to have been attacked during transport, let me know. Moving years of content went surprisingly well, and saying that out loud has almost certainly guaranteed I will find something later.

## Where Did Everything Go?

Navigation is a little different, but everything should be easier to find once you know where to look.

### Home

The **Home** page shows the five newest posts under Recent Transmissions. This is the quickest way to see what I have been working on lately, or at least what I have managed to finish writing about.

You will also find the System Signal panel there, along with links into the full archive and the Operator page.

### Archive

The **Archive** is every post, newest to oldest. There is a search box that filters the list by title, description, category, or tag.

This should help when you vaguely remember that I wrote something about a CUCM database query in 2020 but cannot remember the title. I wrote the thing and still find myself in that exact situation, so the search box is as much for me as it is for anyone else.

### Categories And Tags

**Categories** are the broad subjects: Cisco, Unified Communications, Linux, Python, VMware, Automation, and so on.

**Tags** narrow things down to specific products and topics. If you know you are looking for UCCX, Expressway, SQL, certificates, or another particular piece of technology, tags should get you there faster.

Think of Categories as choosing the part of the data center and Tags as pointing at the specific thing making the noise.

### Operator

The **Operator** page is the About page, only with a name that fits the new design much better. It contains a little about me, what I work on, and why this site contains such a suspicious amount of Cisco Unified Communications material.

At the bottom of the site you will also find links for RSS, the privacy policy, and my GitHub profile.

There we go. You now know where everything is. No runbook required.

## What's Next?

Part of rebuilding the site was about getting excited to use it again.

I have always enjoyed documenting the odd problems that turn up in real environments—the things that sound simple until a version difference, firewall rule, ancient server, or perfectly reasonable business requirement makes them weird. NOC Thoughts has been where I put those stories after the issue is over and I can laugh at it a little.

The new site gives those stories a much better home, and it gives me room to experiment when I inevitably decide the website needs another feature nobody asked for.

There will probably be small changes as I live with the redesign and discover which clever decisions remain clever after I have looked at them fifty times. More importantly, there will be new posts: Unified Communications, automation, scripts, Linux, infrastructure, and whatever else catches fire or catches my interest.

Same archive. Same operator. Much better console.

Thanks for stopping by and taking a look around. The new signal is online, and there is more to come.
