---
title: "Wishlist"
date: 2026-10-25T21:38:53+02:00
draft: true
---

Everyone who learns how to (vibe) code seems to build a calculator, a weather
app and a wishlist app.

## Why a wishlist?

Wishlists simplify our lives and mean less waste and fewer dust-collectors by
making sure that the gift is actually desired.

But what if I want to be surprised? As long as your list is long enough and you
don't know what exactly you are going to receive and from whom, I'd argue that
there is plenty of room for surprise. And if you don't like giving items from
the wishlist, nobody forces you to do so.

## What I need

My initial requirements before starting to build my own solution.

- Share lists publicly or with OIDC that basically everyone already has: if you
  need to register on yet another service, the chances that people will actually
  use it are slim.
- Reserve/release: publishing a static list is easy, but not very useful. Also,
  the release seems important. At least in my case it happened quite often that I
  was focused on gifting one thing, but could not find it, so had to bail.
- Reservations are visible to people trying to reserve, so that there is no
  overlap.
- Reservations are not visible to the owner of the list, so that they can be
  surprised.
- Simple and minimalistic in both UI and functionality.
- Maintained, duh.

## Existing solutions

I have a homelab running k3s. And a bunch of services there use Helm charts by
[TrueCharts](https://truecharts.org/), so naturally, it was the first place I
checked. But there was no single wishlist app.

So I turned to Google: the first time I looked into this was a few years ago,
so one would still use a search engine instead of an LLM.

### [Wishlist](https://github.com/cmintey/wishlist) by cmintey

672 stars. Self-hosted wishlists shared with friends and family or a public
link, with claiming, groups, product details fetched from a URL, and OIDC
login.

Honestly, had I found it the first time I looked, I would probably have been
satisfied. Still, a few things make it not quite what I want.

Excluded:

- Whether owners can see claims on their lists is up to the admin, not the
  owner. Worse, it's a single global setting: once the admin turns it on, every
  owner sees what has been claimed.
- Group membership changes how the app behaves. Members can make suggestions
  on other people's lists (this can be turned off) and see every list in the
  group, which is more than a simple wishlist needs.
- Anyone can claim items on a public list anonymously, and there is no way to
  require a login. Anonymous claims, however, can't be undone.
- Arguably, a bit bloated: suggestions, list managers, claiming your own items,
  managing lists on behalf of others, a "most wanted" flag, and separate
  "claimed" and "purchased" states. To be fair, all of them make sense in certain
  contexts, and you can simply ignore the ones you don't need. I'd still prefer to
  be able to turn them off so they don't clutter the UI.

### [Christmas Community](https://github.com/Wingysam/Christmas-Community)

423 stars. Family wishlists that prevent double-gifting, with guest viewing, Google or OIDC login and a single-list mode.

Excluded: TBD

### [wishthis](https://github.com/wishthis/wishthis)

310 stars. A privacy-focused wishlist platform with many translations.

Excluded:

- Adds an affiliate parameter to amazon.de links, which can't be turned off.
- No longer maintained.

### [Pønskelisten](https://github.com/aunefyren/poenskelisten)

214 stars. Group wishlists with anonymous claiming, password or OIDC login and optional TOTP.

Excluded:

- Items on public lists can't be claimed.
- Registration through individual invite links is confusing (it may be configurable).

### [Wishlist](https://github.com/Reggio-Digital/wishlist) by Reggio-Digital

47 stars. A single-container app: share a list by URL, friends need no account, and claimed items are visible to everyone.

Excluded:

- A different goal: managing a wishlist within a close group, such as a family, where everyone can do and see everything.

### [simple-wishlist](https://github.com/ajb3932/simple-wishlist)

44 stars. A minimal self-hosted wishlist.

Excluded: TBD

### [Wilik](https://github.com/joostvanopdorp/wilik)

37 stars. Claims without an account, hidden from the owner unless they opt in, and item details auto-filled from a product URL.

Excluded:

- The admin has to register users.
- You can set a desired quantity for an item but can't claim more than one.
- Many options (brands, labels, filters, ratings, currency management) that aren't needed and aren't well thought through; it feels vibe-coded.

### [wysh](https://github.com/hamaluik/wysh)

3 stars. Google or Facebook login, friends, and private, friends-only or public lists.

Excluded:

- The last commit was 9 years ago.

### [Super-Simple-Wishlist](https://github.com/ghomasHudson/Super-Simple-Wishlist)

3 stars. Renders a plaintext file of URLs as a wishlist and tracks when someone buys something.

Excluded: TBD

### [wishlist-app](https://github.com/Superior-Kqller/wishlist-app)

1 star. A small Next.js and Prisma wishlist app.

Excluded: TBD

### [Wishlist](https://github.com/SantiagoVargasVe/wishlist) by SantiagoVargasVe

0 stars. Paste a product link, share the list, and let people mark items as bought without spoiling the surprise.

Excluded: TBD

## Lessons from the existing solutions

- No admin page please.
- No specific holiday theme.
- Does not look like web 2.0.
- No referral links.

## Building my own

- Simple and minimalistic in GUI and backend.
- The owner of the lists decides whether they want to see what is already
  reserved.
