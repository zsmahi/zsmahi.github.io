---
title: "EP09- Why Your Subscription Billing Engine Needs More Than One Clock"
author: zsmahi
date: 2026-09-10 20:00:00 +0200
description: Two customers, same plan, same start date, different invoice. Why business rules that change over time need one binding policy per rule, not one global effective date.
categories: [Blogging, System Design]
tags: [Domain Driven Design, system design, .net, c#, architecture, temporal-versioning, temporal-patterns]
pin: true
math: false
mermaid: false
image:
  path: /assets/img/posts/20260911/cover-linkedin.png
  alt: Same plan, same start date, different invoice
---

## Introduction

Alice runs a small design studio. In March 2022, she subscribed to the Pro plan of a project management SaaS for €19 per month. Since then, the public price went up to €29, then to €39. Alice still pays €19. That's *grandfathering*, and it's one of the most common pricing practices out there.

*(The problem comes from real work. The billing scenario, names, prices and dates are made up to illustrate it.)*

The first implementation is usually simple: store the subscription date, add an `if`. And it works, until a second rule that also changes over time shows up. A loyalty discount, for example. Then a tax rate change. Each of these rules has its own calendar, and none of them care about the others.

That's the problem I want to look at: not one rule changing over time, but several, each at its own pace. I've run into it in more than one rule engine, and it took me a while to understand what was really going wrong.

> **TL;DR**
> - Different business rules follow different clocks: the price is bound at subscription, the discount at business events, the tax at each invoice.
> - The real state of a subscription is a tuple of versions, one per rule, not a date.
> - Compatibility between rule versions should be data you can list and test, not scattered `if` statements.
> - A new rule shouldn't go live until someone decides what happens to the existing customers it affects.
{: .prompt-tip }

---

## 1. The naive approach and why it collapses

```csharp
public decimal GetMonthlyPrice(Subscription sub)
{
    if (sub.StartDate < new DateOnly(2024, 1, 1))
        return 19m;

    if (sub.StartDate < new DateOnly(2026, 1, 1))
        return 29m;

    return 39m;
}
```

This is where most billing code starts, and there's nothing wrong with it. It's readable, easy to test, and it matches what the business asked for.

Then the marketing team adds a loyalty discount: 10% off once the customer has been with us for 12 months. In July 2024 they change it: 15% off, but only after 24 months, and only for annual plans. Customers who renewed before the change keep the old rule until their next renewal. Meanwhile, the VAT rate goes from 20% to 21% in January 2025.

The method grows:

```csharp
public decimal GetMonthlyAmount(Subscription sub, DateOnly invoiceDate)
{
    var price = GetMonthlyPrice(sub);
    var months = sub.MonthsActiveAt(invoiceDate);

    if (sub.LastRenewalDate < new DateOnly(2024, 7, 1))
    {
        if (months >= 12)
            price *= 0.90m;
    }
    else if (months >= 24 && sub.IsAnnual) // monthly plans excluded, see BILL-412
    {
        price *= 0.85m;
    }

    var vatRate = invoiceDate < new DateOnly(2025, 1, 1) ? 0.20m : 0.21m;
    return price * (1 + vatRate);
}
```

Look at the dates this method uses. `StartDate` for the price (inside `GetMonthlyPrice`), `LastRenewalDate` for the discount, `invoiceDate` for the tax. Three different dates in the same method, and nothing in the code tells you which rule is supposed to read which date. That knowledge lives in the head of whoever wrote it.

The discount check is the most interesting one. What it really tries to answer is "which discount rule did this customer get at their last renewal?". But the system never stored that answer, so the code tries to rebuild a past decision from the current state, using a date as a clue, every single time we send an invoice.

The `IsAnnual` condition has its own story. At some point, someone decided that the new discount only applies to annual plans, which is probably a good decision. But it sits inside an `else if`, next to a comment pointing to a ticket, and in six months nobody will remember it's there.

And the combinations add up fast. Three price versions, two discount versions, two tax versions: that's already 12 possible combinations. Add one new version per rule per year, and after a few years you're in the hundreds. To be clear, nobody needs to implement all of them. The combinations form a Cartesian product: it's the space of states your system *could* be in. Some of them are valid, some should be forbidden, some can simply never happen. This code can't tell you which is which:

- Which combinations exist in production today?
- Which ones are allowed?
- Which ones were never tested?

I didn't get this right the first time. The first version I designed of an engine like this was built on a simple idea: at any given date, exactly one version of each rule is in force. On paper, it was clean and easy to explain, and I defended it for a while.

It held until the first transition period. New terms were announced, but for several months the old ones and the new ones were both valid at the same time, and which one applied depended on the customer's situation, not on the date. My model had no way to say that. Then came a second problem: a promise that no existing customer would lose a benefit they already had because of the change. For some customers, that meant looking at the old rule and the new one, and keeping whichever was better for them. At that point, "which rule is in force today?" was clearly the wrong question. The right one was: which version is *this* customer bound to, and why?

That's when I understood that the number of dates was never really the issue. What hurts is treating "the date" as one shared variable, when these rules have nothing to do with each other and each one needs its own clock.

---

## 2. One axis, one binding policy

None of this is new territory. Martin Fowler's [temporal patterns](https://martinfowler.com/eaaDev/timeNarrative.html) (Effectivity, Temporal Property, Snapshot) answer "what was true at date X?" very well. What they leave open is *which* date each rule should use, and what happens when several rules, each on its own clock, have to live together. That's the part I want to focus on.

Let's call each independent rule (price, discount, tax) an *axis*. Each axis has a policy that says which moment decides its version. I've found that three patterns cover a lot of real cases.

1. **Binding at subscription.** The version is chosen once, when the customer subscribes, and never moves. That's the base price: Alice's was decided in March 2022. (A plan change counts as a new agreement, with a new snapshot.)
2. **Resolution at evaluation.** The version is looked up at each calculation, using the calculation date. That's the tax: nobody gets a grandfathered VAT rate. Strictly speaking, nothing is bound here, but "use the version in force at evaluation time" is still a decision.
3. **Binding at trigger event.** The version is chosen when a business event happens, and stays until the next one. That's the loyalty discount: it's picked again at each renewal or tier change.

Three words get mixed up a lot here, and I've seen teams confuse them for a long time. Discount v2 has a *validity period*: it's in force from July 2024. Alice is *bound* to v1 since her March 2024 renewal. Her November 2024 invoice is *evaluated* at that date. In November 2024, v2 is in force and Alice is still on v1. Both are true.

**A rule being in force doesn't mean every customer is bound to it.** Or, more simply: a rule can change over time without changing for everyone.

### Three clocks, one customer

Here's Alice (annual plan, renewed every March). The boxes are the versions in the catalogue, the red line is what Alice actually gets, and each red dot is a moment where her version is chosen:

![Three clocks, one customer: the price is bound at subscription, the discount at each renewal, and the tax is resolved at each invoice](/assets/img/posts/20260911/three-clocks.png)

Same customer, three axes, three different clocks.

### Same seniority, different rules

Now take Bob: same plan, same start month. In October 2024 he went from 5 to 10 seats, a trigger event, so his discount was bound again, this time to v2. Alice had no event until March 2025. In November 2024, they have the same plan, the same seniority, and different discount rules. Nothing is broken, but if nobody on the team expects it, it will come back as a support ticket.

So the state of a subscription can't be described by one date, not even one "effective date". It's a *tuple of versions*, one per axis:

| Customer (Nov 2024) | Price | Discount | Tax |
|---|---|---|---|
| Alice | v1 (€19) | v1 (10% after 12 months) | v1 (20%) |
| Bob | v1 (€19) | v2 (15% after 24 months) | v1 (20%) |

### Modeling it

It's tempting to write something generic here:

```csharp
RuleVersion Resolve(RuleType type, DateOnly effectiveDate);
```

One method for every rule looks clean, but it brings back the original mistake: it assumes every rule answers to the same kind of date. The caller has to know which date to pass for each rule (subscription date? invoice date? last renewal or last tier change?), and the business meaning ends up scattered across call sites again. I'd rather make each binding policy visible where it happens.

> The code here shows the model, not a production implementation. With large volumes of data, you'll make infrastructure trade-offs (storage, indexing, read models, caching). They matter, but they don't change the model, so I'm leaving them out.
{: .prompt-info }

First, the price. It's *not* an attribute of `Plan`, otherwise changing it would change it for everyone. It's an immutable value object captured at subscription and attached to the `Subscription` aggregate. (Close to Fowler's Snapshot, but not quite: his is a view of an object as at a given date, reading through to the underlying object; this one is a copy taken once, at binding time.)

```csharp
public sealed record PricingSnapshot(
    PlanCode Plan,
    RuleVersion PriceVersion,
    Money MonthlyPrice,
    DateOnly CapturedOn);

public sealed class Subscription
{
    public SubscriptionId Id { get; }
    public PricingSnapshot Pricing { get; }                  // bound at subscription
    public RuleVersion DiscountVersion { get; private set; } // bound at trigger event
    public SeatTier Tier { get; private set; }

    // ...

    public void ChangeTier(SeatTier newTier, RuleVersion discountVersion)
    {
        Tier = newTier;
        DiscountVersion = discountVersion;
    }
}
```

Then the discount. The version is resolved once, when the trigger event happens, by the application layer:

```csharp
public sealed class ChangeTierHandler(
    ISubscriptionRepository subscriptions,
    IRuleCatalog<DiscountRule> discounts)
{
    public async Task Handle(ChangeTierCommand command)
    {
        var subscription = await subscriptions.GetAsync(command.SubscriptionId);

        // Trigger event: resolve the discount version here, once
        var discountVersion = discounts.VersionInForceOn(command.EffectiveOn);

        subscription.ChangeTier(command.NewTier, discountVersion);
        await subscriptions.SaveAsync(subscription);
    }
}
```

The aggregate never sees the rule catalogue: the application layer resolves the version, the aggregate stores it. And the version is resolved once, at the event, then persisted. That's the real fix for the naive code: instead of rebuilding "which version did Alice get?" at every invoice, we answer it when it happens and write it down. Renewals work the same way.

At billing time, resolving the tuple becomes boring, which is what we want:

```csharp
public sealed record VersionTuple(
    RuleVersion Price,
    RuleVersion Discount,
    RuleVersion Tax);

public sealed class VersionResolver(IRuleCatalog<TaxRule> taxes)
{
    public VersionTuple Resolve(Subscription sub, DateOnly invoiceDate) => new(
        Price:    sub.Pricing.PriceVersion,           // bound at subscription
        Discount: sub.DiscountVersion,                // bound at last trigger event
        Tax:      taxes.VersionInForceOn(invoiceDate) // in force on the invoice date
    );
}
```

(In practice, the tuple is resolved per evaluation period rather than per invoice: a mid-cycle tier change can give one invoice two periods, each with its own tuple.)

The engine never goes to "fetch the current price". It reads what's bound, or resolves with the axis's own policy, and each axis becomes a lookup: version N in, parameters out. Adding a new version is then mostly a new row in a table, not a new `if`. "Mostly", because a version that changes the *shape* of the calculation still needs code, but as a new strategy next to the old ones, without touching the customers bound to them.

---

## 3. When axes stop being independent

So far, each axis is resolved on its own. If the price has 5 versions, the discount 4 and the tax 3, the state space has 60 possible tuples. Are they all valid? Almost certainly not. Say discount v3 is a 30% launch offer, designed with the €39 price in mind. Combined with Alice's grandfathered €19, it would bring her down to €13.30 a month for a plan now sold at €39. **Nobody would approve that on purpose, but if each axis is resolved separately, nothing prevents it.**

The usual reaction is another `if` somewhere in the business code:

```csharp
if (tuple.Discount == Discounts.V3 && tuple.Price == Prices.V1)
    discount = Discount.None; // launch offer not for grandfathered prices
```

It works, but it's invisible. You can't list these rules, you can't review them with the business, and you can't test them all because you don't even know how many there are. This is how you get billing bugs that nobody notices for months.

What worked better for me is to treat compatibility as a first-class concept. A `CompatibilityRule` is data, not a branch in the code:

```csharp
public enum Verdict { Allowed, Forbidden }

// A null version means "any version" on that axis
public sealed record CompatibilityRule(
    string Id,
    RuleVersion? Price,
    RuleVersion? Discount,
    RuleVersion? Tax,
    Verdict Verdict,
    string Reason)
{
    public bool Matches(VersionTuple t) =>
        (Price    is null || Price    == t.Price) &&
        (Discount is null || Discount == t.Discount) &&
        (Tax      is null || Tax      == t.Tax);
}

var rule = new CompatibilityRule(
    Id: "CR-007",
    Price: Prices.V1,
    Discount: Discounts.V3,
    Tax: null,
    Verdict: Verdict.Forbidden,
    Reason: "Launch offer was designed for the €39 price, not for grandfathered ones");
```

The three nullable fields keep the example readable. Conceptually, a compatibility rule is a predicate on the tuple that returns a verdict, and the tuple grows with each new axis (usage quotas, contract terms...). The rules can now be listed, reviewed by the business, and tested without generating a single invoice.

It helps to draw it as a table: one column per price, one row per discount. Each cell is a combination, and the rules say which cells are allowed:

![Which discount can go with which price: a table of combinations, with one cell not allowed and one cell nobody has decided on](/assets/img/posts/20260911/compatibility-grid.png)

### Two moments of validation

When should you check? For a long time I only checked when the tuple was created, and that's not enough.

**At state transitions.** When a customer subscribes, changes plan, renews or changes tier, the application service resolves the resulting tuple and checks it against the compatibility rules before saving the change. The aggregate protects its own invariants, while the compatibility rules deal with the relationship between axes. This stops invalid combinations from being born.

**At every billing run.** Some axes move on their own. The tax is resolved at evaluation, so it changes with no event on the subscription. Imagine tax v3 requires every discount to appear as its own invoice line, and discount v1 was built as a silent multiplier on the price. A customer still bound to discount v1 was fine last month. This month their tuple is (Price v1, Discount v1, Tax v3), and nobody touched their account. Adding a new compatibility rule has the same effect. If you only validate at state transitions, these cases go straight to the invoice.

Because the rules are data, you can also audit them like a decision table, looking for *gaps* (a possible tuple that no rule covers, so undefined behavior in a closed table) and *overlaps* (two rules disagreeing on the same tuple). I treat an overlap as a configuration error to fix before activation, never as something the engine settles at runtime with a priority order. If two rules disagree, the system should stop, not pick one.

### Replaying the past

The compatibility catalogue has versions too. Recalculate Alice's September 2026 invoice in 2030 with the 2030 catalogue, and you may get a different amount. That's not a recalculation anymore, it's a new invoice. An issued invoice never changes; replaying it is for checking it or preparing a credit note. So each invoice records its inputs and the versions it used:

```text
Invoice date         2026-09-01
Seats                5
Price version        v1
Discount version     v2   (bound at her March 2025 renewal)
Tax version          v2
Compatibility set    v7
```

Replaying it means using exactly those, never the current ones. A past result shouldn't depend on today's rules.

---

## 4. The decision nobody wants to make

A new compatibility rule makes some existing tuples invalid. In the table, it's a cell that gets a cross while customers are already in it. What happens to those subscriptions? I've seen teams avoid this question for a long time.

Two common choices are:

- **Migrate automatically** at the next renewal: move Alice to the current discount, or the current price, whatever makes her tuple valid again.
- **Freeze** the affected bindings (her discount version, for example), and record them as an explicit exception.

I've gone back and forth on this one. Where I've landed: the engine never decides, and for anything contractual, the default is to freeze.

For contractual terms, like the price Alice agreed to or a commercial discount, freezing is the default. An automatic migration changes an agreement the customer already accepted, as a side effect of a rule written for other customers, without anyone deciding it for her. When Alice asks support why her invoice went up, the only honest answer is "a rule changed and your account got caught in it".

**A freeze can be undone: the business can still migrate her later, on purpose, with notice. A wrong invoice is much harder to undo:** credit notes, support tickets, and a customer who trusts you a little less. Freezing has a cost too. Exceptions pile up, so each one needs an owner and a review date.

For rules you don't control, like tax, freezing may not be a valid option: the business has to apply the current rate. The decision then moves to the other axes. In the tax v3 example, the question is what happens to the old discount.

And for internal calculation details that don't change what the customer pays or sees, automatic migration is usually fine.

So the rule isn't "always freeze". The rule is that the engine never decides whether existing customers get migrated. That decision belongs to the business policy of each axis, just like the binding policy. In the end, each axis has two policies:

```text
Axis
 ├── Binding policy    → when is a version selected?
 └── Evolution policy  → what happens to existing bindings
                         when the rules change?
```

I started this article talking about clocks, and I think this is where it actually ends up: each axis needs its own clock, and each clock needs its own answer for the past.

On the architecture side, this has a direct consequence. **Activating a new `CompatibilityRule` is not finished until someone has made an explicit decision about the existing tuples it invalidates.** Until then, the rule should not be allowed to go live.

```csharp
public sealed record EvolutionDecision(
    VersionTuple AffectedState,
    DecisionKind Kind,   // Freeze | Migrate
    string DecidedBy,
    DateOnly ReviewBy);

public sealed class CompatibilityRuleActivation(
    ISubscriptionRepository subscriptions,
    ICompatibilityCatalog catalog)
{
    public ActivationResult Activate(
        CompatibilityRule rule,
        IReadOnlyCollection<EvolutionDecision> decisions)
    {
        var undecided = subscriptions
            .DistinctActiveTuples()
            .Where(rule.Matches)
            .Where(t => decisions.All(d => d.AffectedState != t))
            .ToList();

        if (undecided.Count > 0)
            return ActivationResult.Blocked(rule.Id, undecided); // doubt blocks, it never defaults

        catalog.Activate(rule, decisions);
        return ActivationResult.Activated(rule.Id);
    }
}
```

The decision is made per affected state, not per subscription. In practice, a handful of these states usually covers thousands of subscriptions, so the business gets a short list to go through, not an endless one.

> When the system is in doubt, it should stop and ask, not quietly fall back to some default behavior. A blocked activation is annoying for a day. A silent default can be wrong for years.
{: .prompt-warning }

Or, as I've started to put it:

> A rule that has nothing to say about the past shouldn't be allowed to change the future.
{: .prompt-tip }

![That's all folks!](/assets/img/posts/20260911/thats-all-folks.gif){: width="220" height="146" }
