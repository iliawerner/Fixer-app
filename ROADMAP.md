# Fixer roadmap

Fixer is a free, open-source input utility. The roadmap follows that narrow
purpose: help people put useful text into the app they are already using, with
as little interruption as possible.

The items below are directions, not promised dates. Security, target-focus
safety, and truthful data-flow explanations remain release requirements.

## More API providers

Move text generation and voice transcription behind provider-neutral product
interfaces, then support additional user-owned API credentials beyond Gemini.

- Keep each provider opt-in and explain exactly where text or audio is sent.
- Preserve Action portability where model capabilities overlap.
- Never route user content through a hidden Fixer-operated relay.
- Keep provider-specific errors, limits, and costs visible rather than pretending
  every backend behaves identically.

## Local models

Offer optional on-device backends for users who need offline use or do not want
text and audio to leave their Mac.

- Explore local text generation and local speech recognition independently.
- Make downloads, disk use, memory use, model quality, and hardware requirements
  explicit before installation.
- Keep cloud and local Actions interoperable instead of creating two products.
- Validate Apple Silicon and Intel behavior before promising universal support.

## Quick Insert

Add a privacy-first library for information the user deliberately saves and
reuses: addresses, phone numbers, email signatures, common replies, and other
short text.

Possible entry points include a dedicated Shortcut and a named Prompt token.
The final design must make the selected value and destination unambiguous before
insertion.

Quick Insert is not automatic History. Fixer will not silently retain selected
text, Prompts sent to a model, recordings, or transcripts. Sensitive values need
an explicit storage and export policy, secure-at-rest handling, and protection
from screenshots, logs, and accidental model requests. It is not intended to be
a password manager.

## Current release

Fixer 0.2 adds Gemini-first Dictation and `{voice}` Actions. See
[CHANGELOG.md](CHANGELOG.md) for shipped behavior and
[the 0.2 release notes](.github/releases/v0.2.0.md) for upgrade requirements and
known limitations.
