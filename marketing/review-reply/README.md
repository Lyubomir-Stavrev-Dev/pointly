# Resubmission kit — rejection 3a09b983 (Guideline 3.1.2c)

Everything needed to answer Apple's rejection, in the order to do it.

## 1. Update the App Description
ASC → My Apps → Pointly Annotate → version 1.0 page → Description →
paste the full description from `marketing/app-store-listing.md` (it now ends with the
subscription disclosure + Privacy Policy + Terms of Use links Apple asked for).

## 2. Add the Review Notes
Same page → App Review Information → Notes → paste:

> Terms of Use (EULA): we use the standard Apple EULA; a functional link is included at the
> end of the App Description (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/).
> Privacy Policy: https://trypointly.com/privacy (also in the Privacy Policy field).
> In-app: the upgrade screen shows the subscription title (Pointly Pro), length (annual),
> price ($12.99/year, or $39.99 one-time lifetime), and functional Terms of Use and
> Privacy Policy links at the bottom of the sheet.

## 3. Select build 5
Build 5 (1.0) fixes a bug where the paywall's Terms of Use / Privacy Policy links could be
pushed out of view. `build_appstore.sh` produces `build/appstore/Pointly.pkg` — upload via
Transporter, wait for processing, then select it on the version page (replacing build 4).

## 4. Reply in the App Review thread
ASC → App Review (Resolution Center) → reply with the text below and attach
`paywall-compliance-recording.mp4` (in this folder):

> Hello, thank you for the review. We have updated the App Store metadata: the App
> Description now includes a functional link to the standard Apple Terms of Use (EULA)
> (https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) alongside our Privacy
> Policy link, plus the subscription title, length, and price. The app's purchase screen
> displays the subscription title, length, price, and functional Privacy Policy and Terms of
> Use links — see the attached screen recording. We also uploaded build 5, which fixes a
> layout issue so these in-app links are always visible. This information has been added to
> the App Review notes as requested.

## 5. Resubmit
Save the version page and resubmit for review.

## Files here
- `paywall-compliance-recording.mp4` — 30s screen recording: paywall opens, both plans and
  prices shown, Terms of Use click opens Apple's EULA, Privacy Policy click opens
  trypointly.com/privacy. Recorded 2026-07-09 on the fixed build.
