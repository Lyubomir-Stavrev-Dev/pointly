I want to introduce a new recurring character/mascot system into Pointly.

Before implementing anything, please read this entire specification and inspect the existing repository so you understand how this should fit into the current macOS app architecture.

# PRODUCT CONTEXT

Pointly is a macOS menu-bar screen annotation application.

Its purpose is to help people communicate visually while:
- presenting
- screen sharing
- teaching
- recording demos
- explaining interfaces
- guiding someone's attention

Pointly has tools/features such as:
- Draw / Pen
- Arrows
- Highlighter
- Shapes / Lines
- Laser Pointer
- Spotlight
- Blur
- Canvas / Whiteboard
- Zoom
- Timer
- Cues
- Clear
- Undo / Redo
- etc.

There is a Free tier and a Pro tier.

The existing menu-bar popover is important and should NOT be redesigned as part of this task.

Currently it roughly contains:

Pointly                         PRO

[ Start Annotating ]

[ Canvas ]   [ Timer ]
[ Cues   ]   [ Zoom  ]

Shortcuts
Tutorial

Settings
Quit


# THE NEW POINTLY MASCOT

We now have a Pointly mascot.

The character is based on the Pointly cursor/logo.

Visually he is:

- orange
- triangular / cursor-shaped
- large expressive cartoon eyes
- small black arms
- small black legs
- white gloves
- expressive mouth
- playful 3D/cartoon appearance

Think of him as the Pointly cursor becoming alive.

This is NOT just artwork for one popup.

I want this character to eventually become part of Pointly's product identity.

He may eventually appear in:

- Pro promotion
- onboarding
- feature discovery
- tutorials
- contextual tips
- shortcuts education
- new-feature announcements
- empty states
- celebrations
- marketing
- potentially interactions with actual UI elements

Therefore please architect this as a reusable mascot system, NOT a one-off animation attached specifically to the Pro popup.


# PERSONALITY

The mascot should feel:

- playful
- slightly cheeky
- expressive
- helpful
- charming
- occasionally dramatic
- self-aware

He should NOT feel like:

- a corporate assistant
- Clippy
- an intrusive advertisement
- a generic chatbot
- an annoying animated popup

His humor can be things like:

"Psst… that PRO badge is looking lonely."

"You know I can do more than draw arrows, right?"

"Laser. Spotlight. Blur. I'm just saying…"

"We've been through a lot together. Go Pro already."

"I promise I'm not here to sell you— okay, I am."

If the user ignores him, an interaction could eventually be:

Mascot:
"Okay."

He slowly disappears behind the window.

Then just his eyes peek back out.

"...Laser though?"


# IMPORTANT ANIMATION DECISION

I do NOT want to build this as a collection of static PNGs with SwiftUI swapping images.

I also don't want the character animation itself to consist primarily of SwiftUI transforms.

I want to use Rive.

The goal is to have a proper interactive animated character driven by a Rive state machine.

SwiftUI/macOS should own:
- product logic
- timing
- positioning
- eligibility
- persistence
- popup/speech bubble UI
- interaction with Pointly
- deciding which mascot behavior to request

Rive should own:
- character movement
- facial animation
- blinking
- body animation
- transitions
- reactions
- pointing
- peeking
- emotional states
- idle animation

SwiftUI transforms may still be used to position the entire Rive view relative to the Pointly UI, but they should not be the primary character animation system.


# HIGH LEVEL ARCHITECTURE

Conceptually I want something along the lines of:

Pointly application state
        ↓
Mascot coordinator/controller
        ↓
PointlyMascotView
        ↓
Rive State Machine
        ↓
character animation

The exact naming and architecture should follow the conventions already used by this repository.

Do NOT blindly create these exact classes if something else fits the existing architecture better.

Inspect first.


# RIVE

Please investigate and use the current supported Rive runtime/integration for macOS/Swift/SwiftUI.

Do not rely on outdated APIs from memory.

The final mascot will be provided as a .riv asset.

We do NOT have to have the final .riv animation before building the surrounding architecture, but the integration should be designed around a real Rive state machine rather than temporary PNG animation.

I want the eventual Rive character to support behaviors approximately like:

hidden
peek
enter
idle
blink
talk
pointToPro
happy
sad
surprised
dismiss
exit

These do NOT necessarily need to map 1:1 to individual Rive state machine inputs.

Please design a sensible abstraction.

For example, the Swift side might think in terms of higher-level mascot actions:

.show()
.peek()
.speak(...)
.point(at: ...)
.react(...)
.dismiss()

while internally translating those into Rive triggers/booleans/numbers.

Again, choose an architecture appropriate for the existing app.


# IDLE BEHAVIOR

One major reason we're using Rive is that I want the mascot to feel alive even when he's not performing a scripted animation.

Eventually idle behavior could include:

- occasional blinking
- tiny breathing/body movement
- subtle eye movement
- looking toward UI
- small posture changes

It should be subtle.

Do NOT make him bounce continuously like a loading animation.


# FIRST USE CASE: PRO MASCOT INTERACTION

The first implementation will be an animated Pro upsell interaction in the existing Pointly menu-bar popover.

IMPORTANT:

This should NOT look like a normal modal.

It should feel like the mascot physically lives around/behind the Pointly popover.


## Sequence

For an eligible FREE user:

1. User opens the normal Pointly menu-bar popover.

2. Everything behaves normally.

3. After approximately 1–2 seconds, if the popover is still open, the mascot begins peeking from behind one of the edges.

My current preference is the right/lower-right side, but inspect the existing popover geometry and recommend the best location.

4. Initially only part of him should be visible.

The illusion should be:

"Something is hiding behind the Pointly window."

5. He notices the user / blinks.

6. He comes further into view.

7. A small Pointly-styled speech bubble appears.

Example:

"Psst… that PRO badge is looking lonely."

8. The mascot then gestures/points toward the existing PRO badge or relevant Pro UI.

9. The speech UI provides something like:

[ See Pro → ]

and a subtle dismiss control.

10. Clicking See Pro must call the EXISTING Pointly Pro/paywall flow.

Do not create a second subscription implementation.

11. If the user dismisses it, the mascot should react.

For example:
- disappointed expression
- looks at user
- shrugs
- retreats behind the popover

12. Eventually we could add the joke where only his eyes reappear and he says:

"...Laser though?"

But don't overcomplicate v1 if the architecture already supports adding this later.


# VERY IMPORTANT: WINDOW / POPOVER CONSTRAINTS

Please investigate this carefully.

The mascot ideally needs to APPEAR to come from behind/outside the Pointly popover.

A normal SwiftUI overlay may be clipped to the bounds of the popover/window.

Do not assume that putting the mascot in a ZStack will automatically achieve the visual effect.

Inspect how Pointly's current menu-bar popover/window is implemented.

Determine whether we need:

- a larger transparent content area
- an NSPanel
- a borderless transparent companion window
- a child window
- another AppKit mechanism
- or whether the existing window already supports what we need

The desired visual result matters more than forcing everything into one SwiftUI view.

If a transparent companion panel/window is the correct macOS architecture for allowing the mascot to exist visually outside the popover bounds, tell me.

The mascot must feel attached to the Pointly popover, not like an unrelated floating window.

It also needs to correctly follow the popover if necessary and disappear when appropriate.


# INTERACTION

The existing Pointly popover MUST remain usable.

The mascot should not create a giant invisible hit-testing layer blocking:

- Start Annotating
- Canvas
- Timer
- Cues
- Zoom
- Shortcuts
- Tutorial
- Settings
- Quit

Only actual interactive mascot/speech bubble regions should intercept clicks.

Transparent mascot/window areas should not unnecessarily block interaction.


# WHEN IT SHOULD APPEAR

Do NOT show this every time the menu opens.

That would become annoying very quickly.

For the first implementation, create a clean eligibility/frequency system.

Conceptually:

- Free users only
- never while user is already Pro
- don't immediately show on first-ever launch
- user should have experienced Pointly first
- require some meaningful amount of app usage / menu opens
- once shown, don't immediately show again
- dismissal should create a cooldown of several days
- explicit permanent dismissal should be possible later
- successful Pro conversion obviously disables Pro upsell behavior

Please inspect what analytics/local persistence/preferences infrastructure already exists before inventing another storage mechanism.

For development, provide an easy DEBUG-only way to force the mascot experience to appear so we don't have to wait several days while testing.


# SPEECH BUBBLE

The speech bubble itself can be native SwiftUI.

It does NOT need to be part of the Rive file.

That lets us dynamically change copy without rebuilding the animation.

Conceptually:

PointlyMascotView
+
MascotSpeechBubble

The bubble should visually belong to the character.

It should use Pointly's existing design language.

Keep it small.

It should never become a giant modal card.


# COPY SYSTEM

Please don't hardcode one string directly inside the view.

Create a lightweight way to support different mascot messages/context later.

For example, future contexts might include:

proUpsell
laserDiscovery
spotlightDiscovery
shortcutTip
welcome
newFeature
celebration

The exact implementation is up to you.

I want us to eventually be able to say something conceptually like:

mascot.present(
    context: .proUpsell,
    message: ...
)

without the menu popover knowing how mascot animation works.


# FUTURE DIRECTION

Please keep these future interactions in mind when deciding boundaries, but DO NOT implement all of them now.

Eventually I want the mascot to be able to:

- point at specific UI elements
- teach shortcuts
- celebrate actions
- introduce features
- react to feature usage
- sit on/around UI elements
- peek around windows
- guide onboarding
- appear in contextual tips
- announce new features

Potential examples:

User hasn't discovered Laser:
"You're still moving your cursor around like that? Watch this."

Then he points toward Laser.

User discovers Spotlight:
"There we go. Now they HAVE to look."

User learns a keyboard shortcut:
"Look at you. Professional already."

This is why the architecture must separate:

PRODUCT LOGIC
from
MASCOT PRESENTATION
from
RIVE CHARACTER ANIMATION.


# ACCESSIBILITY / USER PREFERENCES

Please account for:

- Reduce Motion
- users who dismiss the mascot
- users who don't want promotional interruptions
- popover closing during an animation
- application losing focus
- rapid open/close cycles
- animation cancellation
- cleanup
- no retain cycles
- no timers surviving unnecessarily

If macOS Reduce Motion is enabled, provide a calmer behavior.

For example:
mascot may simply fade/appear in a resting pose rather than performing the full entrance animation.


# PERFORMANCE

This is a menu-bar utility.

The mascot system should NOT cause meaningful idle CPU/GPU usage when:

- the popover is closed
- mascot isn't visible
- app is sitting in menu bar
- animation isn't needed

Do not keep animation/render loops running unnecessarily.

Unload/pause Rive animation appropriately when it isn't being shown if supported/recommended by the runtime.


# ASSET HANDLING

We'll eventually have something like:

PointlyMascot.riv

Please decide where this belongs based on the existing project's resource structure.

Do not tightly couple the entire system to a specific file path scattered throughout the code.

Have one clear place responsible for loading/configuring the mascot resource.


# DEVELOPMENT STRATEGY

I do NOT want you to immediately start making large changes.

FIRST:

Inspect the repository.

Find:

1. menu-bar implementation
2. popover/window implementation
3. SwiftUI/AppKit boundary
4. Pro entitlement/subscription state
5. existing paywall opening mechanism
6. local persistence/preferences
7. relevant app lifecycle logic
8. existing animation dependencies
9. package/dependency management
10. whether Pointly already has any reusable overlay/panel/window infrastructure

Then come back to me with your proposed implementation.


# I WANT YOUR FIRST RESPONSE TO CONTAIN

## 1. Existing architecture

Tell me exactly how the current Pointly menu/popover works based on the repository.

## 2. Best visual architecture

Specifically answer:

Can the mascot visually extend beyond the existing popover?

If not, what macOS/AppKit mechanism should we use?

I care strongly about the illusion that the mascot is crawling/peeking from BEHIND the Pointly panel.

## 3. Rive integration

Explain how you recommend integrating Rive into THIS repository.

Use current Rive APIs, not assumed/outdated APIs.

## 4. Proposed files/components

Show me the files/classes/views you would add or modify.

Keep the system reasonably small.

## 5. State/event architecture

Explain how:

Pointly state
→ mascot coordinator
→ Rive state machine

will communicate.

## 6. First animation sequence

Explain precisely how:

popover opens
→ delay
→ peek
→ enter
→ bubble
→ point at Pro
→ CTA/dismiss
→ exit

will work.

## 7. Risks

Call out anything potentially difficult, especially:

- clipping outside popover bounds
- NSWindow/NSPanel behavior
- focus
- hit testing
- positioning
- multi-monitor behavior
- menu-bar placement
- lifecycle
- Rive/macOS compatibility

DO NOT implement yet.

I want to approve the architecture first.


# DESIGN PRINCIPLE

This feature succeeds if users think:

"Wait... did that little guy just crawl out of the Pointly menu?"

It fails if users think:

"Oh, they added an animated upgrade popup."

The character should feel like he belongs inside Pointly and occasionally comes alive.

This should feel delightful first and promotional second.