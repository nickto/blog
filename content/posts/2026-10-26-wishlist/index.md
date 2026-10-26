---
title: "Wishlist"
date: 2026-10-25T21:38:53+02:00
draft: true
---

## Why a wishlist?

Wishlists make gift-giving easier. Givers don't have to guess, and recipients
get something they actually want instead of another dust collector. Less
guessing means less dust collecting shelfware.

But what about surprises? If the list is long enough, you don't know exactly
what you'll get or from whom, so there is still plenty of room for surprise.
And if you'd rather not pick a gift from someone's wishlist, nobody forces you
to.

## What I need

These were my requirements before I started building my own solution.

**No new accounts.** Lists should be shareable via a public link or via OIDC
with a provider that basically everyone already has. If people have to register
on yet another service, the chances that they will actually use it are slim.

**Reserving and releasing items.** Publishing a static list is easy, but not
very useful: givers need to mark what they are getting.

- Reservations are visible to other givers, so two people don't buy the same
  thing.
- Reservations are hidden from the list owner, so they can still be surprised.
- Reservations can be released. It has happened to me more than once that I
  settled on a gift but couldn't find it anywhere and had to give up on it.

**Simple.** Minimalistic in both UI and functionality.

**Maintained.** Duh.

## Existing solutions

I have a homelab running k3s. And a bunch of services there use Helm charts by
[TrueCharts](https://truecharts.org/), so naturally, it was the first place I
checked. But there was no single wishlist app.

So I turned to Google: the first time I looked into this was a few years ago,
so one would still use a search engine instead of an LLM. While doing that,
I discovered that wishlists are probably the most popular type of apps after calculators and weather apps. Yet, a couple of them genuinly look like generic and polished solutions. While the rest is mostly targeting a very specific use case.

### [Wishlist](https://github.com/cmintey/wishlist) by cmintey

672 stars. Wishlists for friends and family. Everyone has an account, and users
are organised into groups where members see each other's lists and claim items.
Lists can also be shared through a public link. Other features include product
details fetched from a URL and OIDC login.

Honestly, had I found it the first time I looked, I would probably have been
satisfied. Still, a few things make it not quite what I want.

What I liked: it's the most complete of the lot and actively developed by many
contributors. Claiming and unclaiming are one click, quantities are handled
properly, and claims are hidden from owners by default.

Why it's not for me:

- Whether owners see claims is a single global admin setting, not the owner's
  choice: once it's on, every owner sees what has been claimed.
- Groups do more than I need: members see every list in the group and can
  suggest items on other people's lists (this can be turned off).
- Anyone can claim items on a public list anonymously, with no option to
  require a login, and anonymous claims can't be undone.
- More features than I need: suggestions, list managers, claiming your own
  items, a "most wanted" flag, separate "claimed" and "purchased" states. They
  are genuinely useful, just not to me, and since most can't be turned off,
  they only add clutter.

### [Christmas Community](https://github.com/Wingysam/Christmas-Community)

423 stars. A family Christmas wishlist that prevents double gifting. The admin
creates an account for each family member, and everyone gets one list. Others
in the family pledge items and can see what has been pledged, but the owner
can't. It also supports guest viewing, OIDC login and a single-list mode.

It is surprisingly popular given what I found, so it's quite possible I'm
missing something.

What I liked: pledging and unpledging are one click, an item can't be pledged
twice, owners never see pledges, and OIDC login works with any provider.

Why it's not for me:

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

What I liked: givers just open the link and mark a wish as fulfilled, no account
needed. It's also polished, with many translations and several lists per user.

Why it's not for me:

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

What I liked: reserve and release are done right. There's one claim per item,
the claimer can release it, and the owner never sees claims. It's also actively
maintained, with OIDC, two-factor authentication and session management.

Why it's not for me:

- Items on public lists can't be claimed.
- So one needs not only to register, but also to be added to a group.
- On top of that registration with invite codes is confusing (and buggy),
  although OIDC login should alleviate this.

### [Wishlist](https://github.com/Reggio-Digital/wishlist) by Reggio-Digital

47 stars. A single-container app for one household: one admin creates lists
for everyone, shares them by URL, and friends claim items without an account.

What I liked: it's genuinely simple. It's a single container, givers don't need
an account, and claimed items are hidden from other visitors by default.

Why it's not for me:

- A different goal: managing a wishlist within a close group, such as a
  family, where everyone can do and see everything.
- Anyone can unclaim anyone's claim.

### [simple-wishlist](https://github.com/ajb3932/simple-wishlist)

44 stars. One wishlist per instance for a birthday, Christmas or wedding. The
owner adds items on an admin page, and visitors mark them as purchased.

What I liked: it does what it says, with one list and a few fields, set up in
minutes.

Why it's not for me:

- Anyone can mark an item as purchased, and anyone can undo it.
- No commits in the last year.

### [Wilik](https://github.com/joostvanopdorp/wilik)

37 stars. Personal wishlists shared by link. Guests claim items without an
account, claims are hidden from the owner unless they opt in, and item details
are auto-filled from a product URL.

The closest to what I want: it's the only one where the owner decides whether
to see claims (as long as the admin allows it).

What I liked: besides that, claimer names are hidden from other guests, guests
claim without an account, and quantities are supported.

Why it's not for me:

- The admin has to register users.
- You can set a desired quantity for an item, but each click claims just one.
- Many options (brands, labels, filters, ratings, currency management) that
  I don't need, and they make the app feel cluttered rather than focused.

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
