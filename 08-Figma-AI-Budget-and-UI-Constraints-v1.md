# Figma AI Budget and UI Design Constraints v1

## 1. Purpose

This document defines how UI design work for this project should be done when using Figma AI / Figma Make on a free Starter plan.

The goals are:

- preserve the best current design state
- reduce wasted AI generations
- batch related UI changes into fewer prompts
- keep the product visually consistent across pages

## 2. Current Figma AI quota fact

As of the latest Figma help center and pricing pages:

- Starter / Free plan includes `150 AI credits/day`
- Starter / Free plan also includes `up to 500 AI credits/month`
- AI usage is not a fixed "number of prompts per day"
- each AI action consumes credits based on the action type, request complexity, and model used
- some actions are free, while agentic actions like Figma Make consume variable credits

Practical implication:

- there is no official fixed answer like "3 times per day" or "10 times per day"
- the usable count depends on what kind of AI action is requested
- for Figma Make, treat the budget as `150 credits/day`, not as a fixed prompt count

## 3. Design workflow rule

For every future UI design task in this project:

1. Preserve the current good version.
2. Bundle related changes into one prompt.
3. Prefer adding missing structure over polishing tiny details.
4. Avoid repeated iterations for the same screen unless there is a clear new defect.
5. If a screen is already visually strong, do not rebuild it.
6. Use the smallest prompt that can produce a complete screen-level change.

## 4. Prompt batching strategy

When using Figma Make, design requests must be grouped by outcome:

- one prompt for a page shell or screen family
- one prompt for another page/state only if it is structurally distinct
- one prompt for sidebar / navigation states if they affect multiple screens
- one prompt for component-level polishing only when the layout is already correct

Do not split these into many small prompts:

- spacing tweaks
- label wording
- border softness
- icon alignment
- color micro-adjustments

Those should be bundled into the next meaningful screen-level revision.

## 5. Default UI design priorities for this project

The product is a Mac-first software delivery control center, so design prompts must preserve:

- Apple-like calmness
- light frosted glass
- thin dividers
- quiet blue active state
- subtle depth, not heavy shadows
- strong hierarchy, not enterprise dashboard density
- overview + detail page structure
- expandable sidebar support

## 6. Hard constraints for future Figma design prompts

Do:

- keep the current overview page intact unless a rewrite is explicitly requested
- include navigation between overview and detail screens
- use compact structure and avoid decorative clutter
- keep the sidebar narrow by default and expandable on demand
- add second-page workspaces when the product needs execution depth

Do not:

- rebuild the homepage just to add a small feature
- introduce enterprise SaaS styling
- add unnecessary cards, badges, or status noise
- add heavy shadows or opaque blocks
- create unrelated alternate visual directions

## 7. Recommended screen delivery order

When the project needs UI work, Figma prompts should follow this order:

1. Overview dashboard
2. Detail / workspace page
3. Sidebar expanded and collapsed states
4. Empty / loading / error states
5. Final polish pass only if credits remain

## 8. Figma prompt template

Use this structure when prompting Figma Make:

```text
Keep the current working version.
Add or improve only the following:
1. [screen or component]
2. [screen or component]
3. [screen or component]

Constraints:
- Apple-like calm visual system
- light frosted glass
- thin dividers
- quiet blue active states
- no enterprise dashboard look
- do not rebuild screens that already work
- batch related changes into the same screen family

Deliverable:
- [exact pages, states, or components to output]
```

## 9. How this should be used

Before any future UI design work on this project:

- read this document first
- identify the minimum screen family that must change
- send one batched Figma prompt
- only do another generation if the previous one is structurally correct but missing a clear requirement

## 10. File ownership

This document is the UI design budget and execution guardrail for the project.
It should be updated whenever the product structure or Figma plan changes.

