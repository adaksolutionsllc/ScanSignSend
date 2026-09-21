# Pricing — Scan Sign Send

One-time non-consumable unlock, product ID `com.adakVentures.fullaccess`.
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

The consequence for pricing is specific: the buyer is not comparing $14.99 to a
$2.99 utility. They are comparing it to *the first two months* of a
subscription they'd otherwise carry forever. That comparison supports a price
well above the usual impulse ceiling — and it means underpricing actively
weakens the positioning, because a $4.99 scanner reads as a toy next to a
$60/yr incumbent.

There are no servers and no per-user marginal cost, so there is no floor
imposed by economics. The floor is perceptual.

## 2. Recommendation

**Launch at $14.99 in tier-1 markets. Do not launch higher.**

$14.99 is defensible against the subscription comparison, sits at a familiar
price point, and leaves headroom. $19.99 is probably also viable — the buyer
who accepts "pay once instead of forever" is not usually sensitive to a $5
delta — but that is a guess, and the asymmetry matters: **raising a price later
is routine, cutting one signals the product failed.** Launch at $14.99, measure,
and test $19.99 once there's a baseline.

**Do not add a subscription.** It converts the one asset the app has that the
incumbents can't copy into a worse version of what they already do well.

## 3. Regional pricing — the part that actually matters

Default store currency conversion would put this at roughly ₹1,250 in India and
R$80 in Brazil. Those are not adjusted prices; they are a decision not to sell
in those markets. Indian paid-app expectations top out far lower, and the app
now ships in Hindi, Tamil and Telugu specifically to reach those users.

Set explicit per-country prices rather than accepting auto-conversion:

| Market | Price | ≈ USD |
|---|---|---|
| US | **$14.99** | 14.99 |
| Eurozone | **€14.99** | ~16 |
| UK | **£12.99** | ~16 |
| Canada | **CA$19.99** | ~14.50 |
| Australia | **A$22.99** | ~15 |
| Japan | **¥2,200** | ~14.50 |
| **India** | **₹499** | ~5.90 |
| **Brazil** | **R$ 29.90** | ~5.50 |
| Mexico | **MX$ 119** | ~6.50 |
| SE Asia (ID/PH/VN/TH) | ~**$5.99** equivalent | 5.99 |
| Turkey, Eastern Europe | ~**$6.99** equivalent | 6.99 |
| LatAm (ex-BR/MX) | ~**$7.99** equivalent | 7.99 |
| Middle East (AE/SA) | **$14.99** equivalent | 14.99 |

Rationale for the discounted tiers: a one-time purchase has no ongoing cost to
serve, so a ₹499 sale is close to pure margin. The alternative is not a ₹1,250
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
- Paywall → purchase conversion is known (below ~2% suggests a positioning or
  trial problem, not a price problem; above ~8% suggests headroom at $19.99)
- India/Brazil install volume is material but purchase volume is not — that
  points at the discounted tier still being too high, not too low
