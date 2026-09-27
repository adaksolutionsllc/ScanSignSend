# Pricing — Scan Sign Send

One-time non-consumable unlock, product ID `com.adakventures.scansignsend.fullaccess`.
Free tier: 3 complete Scan → Sign → Send cycles, gated at Press by
`ProfileRepository.canScan()`.

> These are recommendations from category norms and unit economics, not from
> measured demand for this app. Nothing here is validated against live
> conversion data, because there isn't any yet. Treat the launch price as a
> hypothesis with an instrumented review at ~90 days.

---

## 1. What the price has to do

The competitive set has almost entirely moved to subscriptions — Adobe Scan,
CamScanner, SwiftScan, Scanner Pro, SignEasy, DocuSign all recur, mostly in the
$50–120/yr range. That is the wedge this app sells against: **pay once, no
account, nothing leaves the device.**

The consequence for pricing is specific: an informed buyer is not comparing
this to a $2.99 utility. They are comparing it to *the first months* of a
subscription they'd otherwise carry forever. That comparison supports a price
well above the usual impulse ceiling — and it means underpricing actively
weakens the positioning, because a $2.99 scanner reads as a toy next to a
$60/yr incumbent. The caveat is who is doing the comparing, which §2 takes up.

There are no servers and no per-user marginal cost, so there is no floor
imposed by economics. The floor is perceptual.

## 2. Decision: $9.99 at launch

**Launch price is $9.99 in tier-1 markets**, with a planned review once reviews
and ranking exist.

The case for $9.99 over $14.99 comes down to who the launch buyer actually is.
The subscription comparison ($60/yr forever vs. pay once) is a genuinely strong
argument, but it only works on someone *already comparison-shopping* the
category. That is not the launch audience. The launch audience is a cold
browser looking at an unknown developer with zero reviews, deciding whether the
app is worth the risk at all. In that frame:

- $9.99 clears the sub-$10 impulse threshold; $14.99 triggers deliberation, and
  deliberation wants social proof the app doesn't have yet.
- Download velocity feeds store ranking early, and ranking feeds more
  downloads. Volume is worth more than ARPU in month one.
- Zero marginal cost means volume costs nothing to serve.
- $9.99 → $14.99 is a routine move once there are reviews to justify it. The
  reverse is not.

**Do not add a subscription.** It converts the one asset the app has that the
incumbents can't copy into a worse version of what they already do well.

**Revisit $14.99** once the app has meaningful review volume and the
subscription comparison can actually land — see §5.

## 3. Regional pricing — the part that actually matters

Default store currency conversion would put this at roughly ₹850 in India and
R$55 in Brazil. Those are not adjusted prices; they are a decision not to sell
in those markets. Indian paid-app expectations top out far lower, and the app
now ships in Hindi, Tamil and Telugu specifically to reach those users.

Set explicit per-country prices rather than accepting auto-conversion:

| Market | Price | ≈ USD |
|---|---|---|
| US | **$9.99** | 9.99 |
| Eurozone | **€9.99** | ~10.80 |
| UK | **£8.99** | ~11 |
| Canada | **CA$12.99** | ~9.40 |
| Australia | **A$14.99** | ~9.80 |
| Japan | **¥1,500** | ~9.90 |
| **India** | **₹399** | ~4.70 |
| **Brazil** | **R$ 19.90** | ~3.70 |
| Mexico | **MX$ 89** | ~4.90 |
| SE Asia (ID/PH/VN/TH) | ~**$3.99** equivalent | 3.99 |
| Turkey, Eastern Europe | ~**$4.99** equivalent | 4.99 |
| LatAm (ex-BR/MX) | ~**$5.49** equivalent | 5.49 |
| Middle East (AE/SA) | **$9.99** equivalent | 9.99 |

The discounted tiers are not a fixed fraction of the US price — they are set to
locally credible price points (₹399 and R$19.90 are familiar numbers in their
markets), which matters more than arithmetic consistency.

Rationale for the discounted tiers: a one-time purchase has no ongoing cost to
serve, so a ₹399 sale is close to pure margin. The alternative is not a ₹850
sale — it is no sale, plus a translated app nobody buys.

**Where to set this**
- **App Store Connect** → the IAP → Pricing → set the US base price, then
  *Edit prices per storefront* and override IN, BR, MX, ID, PH, VN, TH, TR, and
  the LatAm storefronts. Do not accept the auto-generated equalised prices for
  those.
- **Play Console** → Monetise → Products → In-app products → the product →
  *Set prices by country* and override the same list.

The app already renders the live localized store price via
`IapService.localizedPrice()` and never hardcodes a number, so all of this is a
store-console change with no code release.

## 4. The free tier

3 full cycles is the right shape — the gate sits at Press, which is the moment
the user has already felt the whole product work. Keep it.

Worth watching after launch: whether 3 is enough for the habit to form. If
conversion is weak but retention through cycle 3 is strong, the fix is usually
*more* trial, not a lower price.

## 5. Review triggers

Revisit pricing when any of these is true:
- ~90 days of data exist, or ~1,000 users have hit the paywall
- The app has enough reviews for the subscription comparison to be credible —
  that is the trigger to test **$14.99**, which was the original recommendation
  and is still the right ceiling once trust exists
- Paywall → purchase conversion is known (below ~2% suggests a positioning or
  trial problem, not a price problem; above ~8% is direct evidence of headroom)
- India/Brazil install volume is material but purchase volume is not — that
  points at the discounted tier still being too high, not too low
