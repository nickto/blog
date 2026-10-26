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

Overall, it looks like there are two generic and polished solutions, and the
rest is mostly targeting a very specific use case.

### [Wishlist](https://github.com/cmintey/wishlist) by cmintey

672 stars. Wishlists for friends and family. Everyone has an account, and users
are organised into groups where members see each other's lists and claim items.
Lists can also be shared through a public link. Other features include product
details fetched from a URL and OIDC login.

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

423 stars. A family Christmas wishlist that prevents double gifting. The admin
creates an account for each family member, and everyone gets one list. Others
in the family pledge items and can see what has been pledged, but the owner
can't. It also supports guest viewing, OIDC login and a single-list mode.

It is surprisingly popular given what I found, so it's quite possible I'm
missing something.

Excluded:

- Very targeted: it asks for things like clothing sizes, and each user gets
  only one list.
- Public lists are view-only, and they show what has been pledged, so the owner
  can see it too.
- Doesn't pass my "not Web 2.0" vibe check, although I suspect the idea is
  that you bring your own CSS.
- Somehow too minimalistic and too bloated at the same time. Some buttons
  don't do anything, and overall it doesn't feel like a finished product.

### [wishthis](https://github.com/wishthis/wishthis)

310 stars. A privacy-focused wishlist platform with many translations. Users
register and create lists, and anyone with the link can view a list and mark
wishes as fulfilled without an account.

Excluded:

- Adds an affiliate parameter to amazon.de links, and there's no way to turn it
  off. This is what ruled it out when I first looked into this a couple of
  years ago.
- Since then, it has also stopped being maintained.

Either one is a deal breaker, so I didn't look any further, even though it
seems like a polished product.

### [Pønskelisten](https://github.com/aunefyren/poenskelisten)

214 stars. Group wishlists for a circle of registered users, such as a family.
Owners share lists with groups, and group members claim gifts. Login is by
password or OIDC.

Excluded:

- Items on public lists can't be claimed.
- So one needs not only to register, but also to be added to a group.
- On top of that registration with invite codes is confusing (and buggy),
  although OIDC login should alleviate this.

### [Wishlist](https://github.com/Reggio-Digital/wishlist) by Reggio-Digital

47 stars. A single-container app for one household: one admin creates lists
for everyone, shares them by URL, and friends claim items without an account.

Excluded:

- A different goal: managing a wishlist within a close group, such as a
  family, where everyone can do and see everything.
- Anyone can unclaim anyone's claim.

### [simple-wishlist](https://github.com/ajb3932/simple-wishlist)

44 stars. One wishlist per instance for a birthday, Christmas or wedding. The
owner adds items on an admin page, and visitors mark them as purchased.

Excluded:

- Anyone can mark an item as purchased, and anyone can undo it.
- No commits in the last year.

### [Wilik](https://github.com/joostvanopdorp/wilik)

37 stars. Personal wishlists shared by link. Guests claim items without an
account, claims are hidden from the owner unless they opt in, and item details
are auto-filled from a product URL.

The closest to what I want: it's the only one where the owner decides whether
to see claims (as long as the admin allows it).

Excluded:

- The admin has to register users.
- You can set a desired quantity for an item, but each click claims just one.
- Many options (brands, labels, filters, ratings, currency management) that
  aren't needed and aren't well thought through; it feels vibe-coded.

## Lessons from the existing solutions

- No admin page please.
- No specific holiday theme.
- Does not look like web 2.0.
- No referral links.
- Releasing a claim matters. Many apps get it wrong: either there is no undo,
  or anyone can undo anyone's claim.
- Public and claimable should go together. Most apps make you pick one.

## Building my own

- Simple and minimalistic in GUI and backend.
- The owner of the lists decides whether they want to see what is already
  reserved.
