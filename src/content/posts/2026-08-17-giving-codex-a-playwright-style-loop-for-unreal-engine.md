---
title: "Giving Codex a Playwright-Style Loop for Unreal Engine"
date: 2026-08-17T12:00:00-04:00
categories:
  - General
  - Automation
  - Linux
tags:
  - Unreal Engine
  - Codex
  - MCP
  - Game Development
  - Automation
  - Linux
description: "A practical, bounded architecture for letting Codex inspect a packaged Unreal Engine game, drive real input, collect rendered evidence, and stop before automation becomes a substitute for human playtesting."
draft: false
---

## A Game Does Not Have A DOM. That Does Not Mean It Has To Be Opaque.

One of the things I have come to appreciate about browser automation is the loop behind it.

Inspect the page. Do something. Wait for the application to respond. Check the state again. Take a screenshot. Figure out whether what happened is actually what you meant to happen.

Playwright is very good at this because the web already gives it a language: the DOM. A game does not. You cannot ask a packaged Unreal Engine build for the selector of the enemy that just failed to lock on, and trying to decide everything from a screenshot is a remarkably efficient way to become confidently wrong.<!--more-->

So I wanted to see what the equivalent loop would look like for a native Unreal Engine game running locally on Linux.

Not “let an AI loose in the editor and see what happens.” Not a remote-control layer with a console command hiding behind every button. I wanted a small, game-owned interface that could let Codex playtest something in a way that was observable, bounded, and useful.

The result is a Playwright-style loop for a packaged Development build:

```text
inspect → act → wait → inspect/assert → capture → review → revise
```

It is not Playwright running inside Unreal. It is the same underlying discipline, translated into the things a game actually knows.

## What I Needed The Loop To Know

A screenshot can show that a character looks like it is standing somewhere. It cannot reliably say whether the character moved far enough, whether a jump produced positive vertical velocity, whether lock-on selected the intended target, or whether the ability that appeared on screen actually consumed the expected resource.

At the same time, numbers alone can be a little too forgiving. A state report can say movement completed while the camera is buried in terrain, the UI is unreadable, or an animation looks like it is negotiating with gravity.

The useful loop needs both.

The prototype could read a small set of authoritative state: player position and velocity, health, camera direction, objective state, and nearby enemy state. It could drive the same Enhanced Input mappings a person uses—timed movement, camera look, jump, dodge, attack, and other allowlisted actions. Then it could request a rendered PNG from the viewport and retain the state and image as evidence.

That gave Codex something better than “the picture seems fine.” It could make a bounded move, wait, inspect the delta, and capture the resulting frame. The picture stayed evidence. It just stopped being the entire argument.

## The Important Part Was Not Giving It More Buttons

The easy version of this project would expose an Unreal console, arbitrary reflection, actor spawning, Blueprint mutation, shell access, and whatever else happened to be convenient during development.

That is not a playtesting interface. That is a fairly impressive way to give an agent a universal remote and then act surprised when it changes the channel.

The runtime surface stayed deliberately small:

- `game-state`
- `game-move`
- `game-action`
- `game-look`
- `game-capture-request`
- `game-capture-read`

Each one describes a game concept rather than an engine internals concept. `game-move` takes clamped axes and a bounded duration; it drives mapped input rather than setting an actor transform. `game-action` accepts a fixed list of actions. `game-capture-request` writes only beneath one game-controlled ignored directory, and `game-capture-read` applies a size limit before and after reading the PNG.

Damage and deterministic reset are useful test tools, but they remain explicitly destructive actions with their own approval boundary. They do not get folded into a cheerful generic “do game stuff” command.

That gave the loop a vocabulary that is narrow enough to audit and stable enough to test.

## The Bridge Is Local. The Boundary Still Matters.

The prototype used the open-source [Unreal-MCP](https://github.com/IvanMurzak/Unreal-MCP) runtime and [GameDev-MCP-Server](https://github.com/IvanMurzak/GameDev-MCP-Server) as the bridge between an MCP client and Unreal. At the time of this writing, both projects are published by Ivan Murzak under Apache-2.0.

A local server accepts MCP calls, a supervised sidecar bridges the connection to Unreal, and a project-owned semantic provider translates those calls into real input and authoritative state. The provider is the important piece. It is where a generic tool transport becomes something the game can safely understand.

Unreal Engine 5.8 also has Epic's Experimental [Unreal MCP](https://dev.epicgames.com/documentation/unreal-engine/unreal-mcp-in-unreal-editor?application_version=5.8). Its documented workflow is primarily editor-oriented: working with actors, assets, materials, and editor automation. Its underlying runtime modules can host a server in a cooked build, but editor toolsets are not automatically carried into that environment; runtime tools must be deliberately registered.

That makes the two approaches adjacent rather than interchangeable. Epic's tooling is useful for authoring. This experiment is intentionally a narrower, Development-only architecture for exercising and observing a packaged game.

## Security Work Is Not The Boring Part

The most useful findings were not about whether Codex could press a button. They were about what had to be true before it should be allowed to.

The rules were fairly simple:

1. Compile the automation adapter out of Shipping.
2. Require an explicit command-line opt-in in Development.
3. Force any unauthenticated service to loopback.
4. Verify downloaded archives and installed executables by checksum.
5. Put a wall-clock timeout around the whole run.
6. Terminate and wait for every owned child process on every exit path.
7. Keep destructive tools behind approval.

One iterative review found a subtle gap. The opt-in flag stopped the sidecar and connection path, but a third-party runtime subsystem could still arm a private loopback IPC listener during non-Shipping initialization. Nothing connected when opt-in was absent, but that is not the same thing as proving the listener never existed.

The stronger design is to gate listener creation as well.

That is exactly why I like working through a loop like this in the open: “not reachable” and “not started” are different guarantees. A tool that will eventually be used by someone else has to say which one it actually provides.

## What Passed—And What Still Belongs To A Person

The prototype compiled Editor, Development, and Shipping targets. It cooked and packaged a Development build, negotiated MCP, drove the player through real input, observed positive jump velocity, captured rendered frames, and cleaned up its game, server, sidecar, and test listener afterward.

That is enough to qualify the integration and show that the loop is useful.

It does not qualify combat feel, animation quality, level design, accessibility, pacing, or fun. The system can tell me that a jump happened. It cannot tell me whether the jump feels good. It can preserve a screenshot. It cannot decide whether the world behind it is worth exploring.

Those are not missing assertions. They are human judgments.

## Where This Goes From Here

The public version is now available as the [Unreal Codex Playtesting Pipeline](https://github.com/Unhall0w3d/unreal-codex-playtesting-pipeline), a standalone Apache-2.0 reference package rather than a release of the original prototype. It contains generic configuration patterns, a semantic-provider contract, checksum-pinned installation examples, a bounded smoke-test harness, and a small MCP client skeleton. It does not include the original game, Unreal Engine files, Epic/Fab assets, third-party binaries, credentials, or local project history.

The next real job is a tiny redistributable sample game and a handful of declarative scenarios: where the player starts, what the test does, what should be true afterward, and what evidence is worth keeping. I also want the harness to prove that the process it launched owns the expected loopback port, rather than merely noticing that a port is open.

I am not especially interested in calling this “AI game testing” and declaring the problem solved. A useful test loop should run one bounded scenario, leave enough evidence for me to understand what happened, and get out of the way when it is done. If it cannot do that, it is just a clever demo with more moving parts.

This pass proved the part I wanted to prove: Codex can speak to a packaged Unreal build well enough to repeat a few meaningful checks. Whether the movement feels right, whether an encounter is fun, or whether a scene holds together is still mine to play. That is where it should stay.

*The repository's dependency versions are historical qualification pins. Revalidate current upstream releases, checksums, compatibility, and licenses before reuse.*
