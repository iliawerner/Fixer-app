# Product spec: "Fixer" — a functional brief for the designer

This document describes **what** the product must be able to do. It deliberately
does not describe **how** anything looks or where anything lives. There are no
screens, panels, lists, hierarchies, colors, metaphors or element names here —
that is the designer's territory. Every "the user must be able to…" is a
function, not a piece of interface.

The entity names used below (**action**, **prompt template**, **output mode**) are
working names. What they are called in the interface is also the designer's call.

---

## 1. What the product is

A macOS utility that rewrites selected text **in place**, in any application, on a
global keyboard shortcut.

The user selects text in an email, a document, a chat, a form field in a browser —
presses their shortcut — and the selected fragment is replaced with the result of
processing it through a language model: fixed grammar, a translation, a summary, a
different tone — whatever the user described in plain words beforehand.

The value is precisely in the absence of a context switch: no copying, no jumping
to a browser or a chat window, no pasting back. One gesture, inside the app the
person is already working in.

**Target user.** Someone who writes a lot in a non-native language or across
different registers: a developer, a manager, a writer, a support agent. Technical
enough to obtain and paste an API key. Works on macOS, usually across several
applications at once.

**Usage frequency:** dozens of times a day, always in a hurry, always as a side
action inside another task. Every step the product takes costs a fraction of a
second of the user's attention. Setup, by contrast, is a rare procedure that
happens once and then almost never again.

---

## 2. Scope

- Platform: **macOS 13+**, desktop application.
- The app runs continuously in the background; the main interaction happens while
  **someone else's** application is in front.
- Text processing provider: **Google Gemini**, using the user's own personal API
  key. The user picks the model from the list available to their key.
- Billing sits with the provider; the product itself is free and open source. With
  the fast lightweight models, everyday personal use typically stays inside the
  provider's free tier.
- Interface language: English (international distribution).
- The app must behave correctly under both light and dark system appearance — how,
  is the designer's decision.

---

## 3. The main scenario

The single scenario that repeats dozens of times a day:

1. The user is working in an arbitrary application and selects a fragment of text.
2. They press the shortcut bound to one of their **actions**.
3. The product reads the selected text.
4. It substitutes that text into the action's prompt template and sends it to the
   model.
5. It receives the answer and writes it back into the same place: **replacing** the
   selection, or **appending** after it — per the action's setting.
6. The user stays exactly where they were and carries on working.

Between steps 3 and 5 there is a noticeable wait: normally **1–10 seconds**, with a
hard ceiling of **30 seconds**, after which the request is treated as failed. For
that whole time the user is inside another application and needs to understand what
is going on.

**Exactly one** action runs at a time. While processing is under way, pressing any
shortcut again must not start a second run.

---

## 4. Functions

### 4.1. The action

An **action** is the product's core entity: a saved recipe for processing text. The
user creates them for their own purposes. A realistic count is 1 to 10–15.

What an action consists of:

| Property | Meaning |
|---|---|
| Name | How the user recognizes this action among the others. They set it themselves. |
| Prompt template | Free-form instruction text for the model, with a slot for the selected text. See 4.3. |
| Model | Which model processes the request. See 4.6. |
| Output mode | Replace the selection with the result, or append the result after it. See 4.4. |
| Shortcut | The global hotkey that triggers the action. See 4.5. |
| Enabled / disabled | A disabled action never fires, but is preserved in full, including its recorded shortcut. |

Required functions on an action: **create an empty one**, **create one from the
ready-made set**, **change any property**, **duplicate** (get a copy to adapt),
**delete**, **temporarily disable and re-enable**.

Every change is saved immediately and survives restarting the app and the machine.
There is no explicit "save" step in the product, and there should not be one.

### 4.2. Ready-made starters

So that people don't have to invent wording from scratch, the product offers a set
of ready-made actions with clear names and prompts already written. The current set
has 10, by meaning: fix grammar; translate to English; summarize into three
points; make the tone professional; explain in plain language; make it shorter;
turn into a list; draft a reply; make it friendlier; extract key takeaways. The set
may grow.

Functions: the user must be able to **browse** the starters, understand from the
name and a short explanation what each one does, and **add** the ones they want.
Once added, a starter becomes an ordinary action and is edited like any other.

Important: **a freshly added starter does not work yet** — it has no shortcut. The
user has to assign one. The product must carry them through to that step,
otherwise they will add a starter and conclude the product is broken.

Adding the same starter twice must not create a duplicate — already-added starters
must be distinguishable from ones not yet added.

### 4.3. The prompt template and text substitution

The template is free-form multiline text the user writes themselves, in any
language. Inside it there is a **substitution slot** — a marker where the user's
selected text is inserted at run time.

Behavioral rules that must be explainable to the user:

- The marker may appear several times — the selection is substituted into every
  occurrence.
- If the marker **is** present but there is no selected text, the run is aborted
  with an error; no request is sent to the model.
- If the marker is **absent**, the selected text is appended to the end of the
  template. So a template without a marker still works.
- If there is neither a marker nor a selection, the template is sent as is. This is
  a legitimate "generate without input text" mode.

Functions while editing a template: write and edit multiline text; **insert the
marker** without typing it by hand (the user should not have to memorize its exact
spelling, and should not be able to get it wrong); understand where in the template
their text will end up.

In practice, a template almost always needs "return only the result, no
explanations" appended — otherwise the model adds a preamble and that preamble ends
up in the user's document. The product should help the user avoid stepping on this.

### 4.4. Output mode

Two mutually exclusive options per action:

- **Replace** — the result takes the place of the selected text. The original is
  gone.
- **Append** — the original selection is kept and the result is added after it on a
  new line.

The user must understand the difference **before** running, not after. This is one
of the two places in the product where a mistake is expensive: replace mode
destroys the user's original text inside their own document, and the product
provides no way to undo that (see 6.1).

### 4.5. The shortcut

The shortcut is the only way to trigger an action. Functions: **record** a shortcut
(the user presses the combination they want and the product remembers it), **see**
what is recorded, **change** it, **clear** it.

Constraints imposed by the operating system — these must be explained at the moment
of recording, not after a failure:

- A shortcut must include a modifier (⌘, ⌥ or ⌃). A bare key is not allowed: it
  would fire every time the user typed that letter.
- Some keys are reserved by the system and cannot be recorded (Tab on its own, the
  🌐 / Spotlight key).
- A combination may already be taken by another application or by the system
  itself. The product cannot reliably detect this: the user finds out only because
  the action doesn't fire. The product must reduce the chance of that situation
  **up front**.

Conflicts inside the product are detectable: if two actions end up on the same
combination, that must be shown and resolvable. Today this state is allowed and
leads to unpredictable behavior — solving it is part of the job.

An action **without** a shortcut exists and is saved, but there is no way whatsoever
to trigger it. That state must either be marked clearly as unfinished, or removed
by offering an alternative way to trigger (see 6.2).

Shortcuts must work immediately after the app launches, even if the user has never
opened settings.

### 4.6. The model

Each action carries its own model, which is meaningful: a fast cheap model for
grammar fixes, a stronger one for summarizing.

Functions:

- **Load the list of models** available to the user's key. The list comes from the
  provider, contains dozens of entries with both technical and human-readable
  names, and differs from user to user. It is filtered: only models capable of
  generating text remain.
- **Pick a model** for an action from the loaded list.
- **Enter a model manually** when the list hasn't been loaded yet (for example, the
  user hasn't connected a key but is already setting up actions). The identifier is
  validated; a malformed one makes the action fail at run time.
- A new action gets a sensible default model so that it works out of the box.

The designer's problem to solve: the user **does not know** how the models differ,
and should not have to study the provider's documentation to choose. Helping them
choose is part of the work.

### 4.7. Connecting the provider

The product works only with the user's own API key.

Functions:

- **Enter the key.** The key is a secret: a long random string the person copies
  from a third-party site. It should not sit exposed on screen, but the user must be
  able to confirm they pasted it whole and without junk.
- **Store the key** in the system secret store (Keychain). Storing happens by
  itself, without a separate confirmation step.
- **Verify the key.** The only way to find out whether a key works is to call the
  provider. Success means two things at once: the key is valid, and the model list
  has been retrieved. Failure returns the provider's error text.
- **Understand the current state**: no key entered / entered but unverified /
  verified and working / rejected, with the reason.
- **Find out where to get a key** — the user obtains it on the provider's site, and
  without that pointer a first run is impossible.
- **Replace or remove the key** later.

The user must be able to see and understand that the key is stored locally in the
system secret store, and that their text goes only to the provider and nowhere
else. This is a matter of trust, and it is critical — the product reads everything
the user selects.

### 4.8. The system permission

To read a selection inside another application and write the result back, the
product requires the macOS **Accessibility** permission. Without it the product is
entirely non-functional: not a single action will work.

Characteristics that shape the scenario:

- The permission is granted by hand in System Settings, across several steps, and
  users regularly get stuck there.
- The product can: detect the current permission state, trigger the system prompt,
  open the relevant System Settings pane directly, and **notice the grant by
  itself** (within roughly 2 seconds, no restart needed).
- The permission can be revoked by the system later (for instance after an app
  update), at which point the product abruptly stops working. The state must be
  visible at all times, not only on first launch.
- Triggering an action without the permission must fail with a clear message and
  lead the user toward granting it — never do nothing silently.

After the first run, this is the second place where the product loses users. The job
is to carry a person from "downloaded" to "granted" without losses.

### 4.9. Feedback during a run

At the moment of execution the user is inside another application, looking at their
own text. They need to understand three things without clicking anything and
without going anywhere:

1. **It started** — the keypress registered, processing is under way (up to 30
   seconds).
2. **It's done** — the result has been inserted. A glance-level confirmation that
   then gets out of the way.
3. **It failed** — with a reason. The error must be readable in time; it should
   persist longer than the success confirmation, and its text may be long (a
   verbatim provider message, for example).

A hard technical constraint: **no feedback surface may take keyboard focus**. The
result is inserted via a synthetic keystroke into the frontmost application; if
anything of ours becomes active, the result goes to the wrong place and the whole
scenario breaks. This constraint cannot be designed around — it has to be designed
for.

Additionally:

- The error text must remain reachable after the notification disappears — people
  often notice that "nothing happened" only afterwards.
- A repeat press during processing is ignored. Today, completely silently; the user
  presses the shortcut again and doesn't understand why there's no response. This
  needs a solution.
- A run in progress currently cannot be cancelled (see 6.3).

### 4.10. Errors that actually happen

The full set of failure states. Each needs its own wording and, where possible, a
way out:

| Situation | What happened |
|---|---|
| No system permission | The product can neither read nor insert text. |
| Couldn't read the selection | The copy didn't land: the app is too slow, or doesn't hand over its selection. |
| Nothing selected | The user pressed the shortcut with nothing selected, and the template requires text. |
| No key set | The action ran before the provider was connected. |
| Key rejected by the provider | Wrong, expired, revoked, or quota exceeded. The provider's error text arrives verbatim. |
| Invalid model identifier | The user typed a model in by hand and got it wrong. |
| The model refused to answer | The request or the response was blocked by the provider's safety filters, or the answer came back empty. |
| Network error or timeout | No internet, or the provider didn't answer within 30 seconds. |
| Provider malfunction | The response is technically unreadable. |

Separately: inserting the result can **fail silently** — if the cursor ends up
somewhere non-editable (a read-only page, certain terminals, apps with their own
paste handling). The product cannot detect this: from its point of view everything
succeeded. The user sees a success confirmation and no change to their text. At
minimum, the product must not mislead them.

### 4.11. Persistent presence and getting into settings

The app lives in the background and does not occupy the workspace: it has no
ordinary window to keep open, and it does not take part in switching between
applications. Even so, the user needs to be able to:

- **Tell that the app is running and ready** — otherwise they cannot distinguish
  "the product isn't installed / isn't working" from "wrong shortcut".
- **See that processing is happening right now** — independently of notifications.
- **See that something needs their attention** (no permission, no key) — a state
  that can arise at any moment, not just at startup.
- **Get into settings** at any time, from any application.
- **Quit the app.**

Where and how this exists is the designer's decision. The functional requirement:
access must not depend on any window of the product being open, and must not
interrupt what the user is currently doing.

Additionally: launching the app (by double-clicking it) while it is already running
in the background must produce a visible response. Otherwise the person clicks the
icon again and concludes the app is broken.

### 4.12. First run

The user's state right after installing: no key, no permission, one preseeded
action ("fix grammar") that has **no** shortcut. At this point the product can do
nothing useful.

Three steps that must be completed, all three of them outside the product or inside
the system:

1. Grant the system permission (in System Settings).
2. Get an API key on the provider's site and paste it in.
3. Assign a shortcut to at least one action.

Plus a hidden fourth step: **understand the scenario itself** — that you select
text in another application and press the shortcut. Without that understanding, even
a fully configured product goes unused.

The job is to carry the user from install to their first successful result. The
order of the steps, their form, and whether there is a dedicated onboarding at all
are the designer's decisions. This is the highest-value part of the project.

Separately: when installing from open sources, macOS shows an unidentified-developer
warning and the app can only be opened via its context menu. Some users are lost
before the first launch even happens.

### 4.13. Empty states

- No actions at all (the user deleted every one) — the product is useless in this
  state, and that should be said out loud, alongside an offer to create one or take
  a starter. Today one preseeded action silently comes back on the next launch; that
  behavior is open to reconsideration.
- Actions exist, but none has a shortcut — everything looks configured while
  nothing actually works. The product's most treacherous state.
- The model list hasn't been loaded.
- Nothing has ever been run — the user has no idea whether any of this works.

### 4.14. Data-safety promises

The product uses the system clipboard as transport: it copies the selection and
pastes the result. It is obliged to **return the user's clipboard to its original
state** — including when the request failed. If the user copied something of their
own while processing was under way, their copy is not clobbered.

This is invisible machinery, but it bears directly on trust: the product constantly
touches both the selected text and the clipboard. Worth deciding whether and how to
communicate it.

---

## 5. Technical constraints that cannot be designed around

Take these as given conditions of the problem:

1. **A feedback surface cannot take keyboard focus** — otherwise the result gets
   inserted into the wrong application (see 4.9).
2. **The product cannot see the contents of other applications.** It doesn't know
   what is selected until it performs the copy, doesn't know whether the field is
   editable, and cannot highlight or preview a change inside the user's document.
3. **Insertion is irreversible as far as the product is concerned.** Undo is
   available only through the user's own application (⌘Z), and not always even
   there.
4. **The wait for the model cannot be removed.** 1–10 seconds is normal, up to 30
   seconds is the ceiling. The result arrives whole; it does not stream in pieces.
5. **Whether a shortcut works cannot be verified in advance.** A conflict with a
   third-party app is discovered only empirically.
6. **The system permission is granted by hand and outside the product**, across
   several steps.

---

## 6. Functional gaps — these need closing

Below is what the set of functions above is **missing**. This is part of the brief,
not background reading. Solutions are deliberately not proposed.

**6.1. There is no way to see the result before it is inserted, and no way back.**
A model is unpredictable: it can return the wrong thing, add a preamble, lose
formatting. In replace mode the user's original text is already destroyed by then.

**6.2. An action without a shortcut cannot be triggered.** The hotkey is the only
trigger. For rarely used actions this is awkward, and people don't have many free
combinations to spare.

**6.3. A run in progress cannot be cancelled.** Press the wrong shortcut with a
large fragment selected and all you can do is wait.

**6.4. There is no history.** What was asked, what came back, what was inserted —
none of it is stored anywhere. Returning to a result inserted a minute ago is
impossible.

**6.5. The set of actions has no structure.** No reordering, no grouping, no
search. At 15 actions this is already a problem.

**6.6. An action cannot be tried without applying it.** To learn what a template
does, you have to select real text in a real document and run it — risking that
document.

**6.7. The user doesn't understand which model to pick.** A list of technical names
with no explanation of the differences in speed, quality and cost.

**6.8. A repeat trigger during processing is silently ignored** (see 4.9).

**6.9. Insertion fails silently** in a non-editable context (see 4.10).

**6.10. Shortcut conflicts inside the product are permitted** rather than prevented
(see 4.5).

**6.11. There is no launch at login.** A product that lives in the background stops
working after a reboot, and the user finds out when the shortcut does nothing.

---

## 7. What a good solution will be judged on

1. **First successful result.** How many people fail to get from install to their
   first working action — and exactly which step lost them.
2. **The cost of repetition.** The main scenario runs dozens of times a day inside
   someone else's application. It should demand close to zero attention.
3. **Diagnosability.** When something doesn't work, the user understands why and
   knows the next step — without reading documentation and without contacting
   support.
4. **No irreversible damage.** The user must not lose their text because they hit
   the wrong shortcut or because the model returned something bad.
5. **Setup is done once** and doesn't need revisiting. But states that break on
   their own (a revoked permission, an exhausted quota) must be noticeable
   immediately.
6. **Trust.** The product reads everything the person selects and holds their key.
   The user must understand what happens to their text.

---

## 8. Out of scope

- Model providers other than the one named, and local models.
- Working with images, files, or voice.
- Collaboration, cross-device sync, accounts.
- Processing text without the user present (on a schedule, by a rule).
- Platforms other than macOS.
- A multilingual interface.

---

## 9. What we need from the designer

A complete product solution covering every function in section 4 and closing the
gaps in section 6, within the constraints of section 5.

The number, composition and arrangement of surfaces is the designer's call. We are
not fixing the navigation structure, the element names, or which functions live
together. If some function from section 4 turns out to be unnecessary in your
solution, or is replaced by different mechanics, that is acceptable — provided the
main scenario (section 3) and the criteria in section 7 still hold, and the
reasoning is stated.
