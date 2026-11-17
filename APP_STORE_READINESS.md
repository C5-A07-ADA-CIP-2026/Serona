# Serona App Store Readiness

## Current verdict

Serona is suitable for continued physical-device testing and TestFlight preparation, but it is not ready for public App Store submission.

The one-sensor BLE flow builds and runs on a physical iPad. The app receives complete ESP32 payloads, decodes pH and all eight AS7341 channels, captures the first bath reading as its 100% baseline, and preserves that baseline for later readings. Public release remains blocked by unresolved test failures, incomplete hardware validation, missing reviewer access without a sensor, and incomplete privacy, legal, accessibility, and submission preparation.

## Release blockers

- [ ] Audit every failing test and classify it as a real defect, obsolete expectation, or unfinished specification.
- [ ] Fix all valid failures in recipe persistence, water-volume units, dye and soda calculations, repair sequencing, and clean-water calibration.
- [ ] Make the complete test suite pass in the Release candidate.
- [ ] Validate concentration, pH thresholds, and repair calculations against controlled reference samples.
- [ ] Test two physical BLE sensors connected to two baths simultaneously.
- [ ] Prove that measurements never cross between bath sessions.
- [ ] Provide a production demo mode that lets App Review exercise the complete workflow without physical hardware, or coordinate physical review hardware with Apple.
- [ ] Publish a privacy policy and make it accessible inside the app.
- [ ] Complete the privacy-manifest and required-reason API audit.
- [ ] Complete the accessibility audit for all common tasks.
- [ ] Produce a successful App Store Release archive and validate it before upload.

## Code quality and correctness

### Automated validation

- [ ] Run the complete Swift Testing suite with zero unexpected failures.
- [ ] Run UI automation for the primary project, recipe, scanning, warning, repair, and completion flows.
- [ ] Run `swiftformat --lint --swift-version 6.0 --language-mode 6 .` successfully.
- [ ] Run `swiftlint lint --strict` successfully.
- [ ] Run Xcode static analysis on the Release configuration.
- [ ] Build with the Release configuration for a generic App Store device.
- [ ] Treat new compiler warnings as release failures.
- [ ] Add the build, tests, formatting, linting, and analysis checks to CI.

### Runtime reliability

- [ ] Test cold launch with no saved data.
- [ ] Test migration from every previously distributed data schema.
- [ ] Test low-memory termination and subsequent restoration.
- [ ] Test app termination while BLE is connected.
- [ ] Test force quit and relaunch while a bath is active.
- [ ] Test Bluetooth disabled, permission denied, unsupported hardware, and airplane mode.
- [ ] Test ESP32 power loss, reboot, and advertising restart.
- [ ] Test repeated connect and disconnect cycles.
- [ ] Test malformed, empty, fragmented, concatenated, oversized, stale, and out-of-range payloads.
- [ ] Test long-duration measurement streaming and monitor CPU, memory, battery, and thermal behavior.
- [ ] Remove or disable verbose development logging in production builds.
- [ ] Confirm that no fatal errors, force unwraps, or assertion-only recovery paths can be reached by user data.

### Release reproducibility

- [ ] Keep the exact production ESP32 firmware in a versioned, team-controlled repository.
- [ ] Tag the iOS app and matching firmware versions together.
- [ ] Add a BLE protocol version to every payload or characteristic.
- [ ] Reject unsupported firmware versions with a clear recovery message.
- [ ] Document the service UUID, characteristic UUID, payload schema, units, ranges, and compatibility policy.
- [ ] Document how calibration constants are produced and updated.

## BLE and hardware readiness

### Multi-device behavior

- [x] Persist a peripheral UUID for each bath.
- [x] Route BLE callbacks by peripheral UUID.
- [x] Maintain per-peripheral sessions and multiple subscribers.
- [x] Reassemble and validate JSON frames.
- [x] Capture the first successful setup reading as the bath's 100% baseline.
- [x] Preserve the saved baseline after reconnection.
- [ ] Validate two or more physical sensors concurrently.
- [ ] Confirm that deleting or finishing one bath does not disconnect another bath's sensor.
- [ ] Confirm that one sensor cannot be assigned to two active baths.

### Connection lifecycle

- [ ] Verify connect, discovery, notification subscription, and initial read on all supported devices.
- [ ] Verify automatic reconnect after unexpected disconnection.
- [ ] Verify state restoration after app relaunch where supported.
- [ ] Verify stale-data detection when notifications stop without a BLE disconnect.
- [ ] Verify that connection timeouts always complete and leave the UI recoverable.
- [ ] Verify advertising restarts after an iPad disconnects.
- [ ] Provide a discoverable manual retry and device-reselection flow.
- [ ] Explain whether a bath can continue operating when its sensor is unavailable.

### Protocol integrity and security

- [ ] Give every manufactured sensor a stable, distinguishable identity.
- [ ] Add firmware and protocol version fields.
- [ ] Add message sequence or timestamp information for stale and reordered readings.
- [ ] Define integrity or authenticity controls if an unrelated BLE peripheral could impersonate a Serona sensor.
- [ ] Document whether pairing, bonding, or application-level authentication is required.
- [ ] Avoid placing personal or confidential information in advertisements or unencrypted payloads.
- [ ] Threat-model unauthorized connection, spoofed measurements, replayed readings, and denial of service.

### Hardware product work

- [ ] Validate sensor accuracy, repeatability, drift, warm-up time, and operating range.
- [ ] Define calibration and recalibration procedures.
- [ ] Document probe cleaning, storage, maintenance, and replacement.
- [ ] Test enclosure safety around water, chemicals, heat, and industrial environments.
- [ ] Validate electrical, battery, charging, and power-supply safety.
- [ ] Complete applicable Bluetooth SIG qualification or listing work.
- [ ] Complete applicable radio, electrical, environmental, labeling, import, and consumer-product compliance for every sales region.
- [ ] Prepare a hardware user guide, warnings, warranty, support policy, and compatibility list.
- [ ] Do not use MFi or “Made for iPhone/iPad” branding without authorization.

Serona uses Bluetooth Low Energy through Core Bluetooth. BLE-only accessories generally do not require MFi participation unless they use another licensed Apple technology, such as HomeKit or an MFi hearing-aid technology. Confirm the final hardware design against current Apple and Bluetooth requirements before manufacture.

## Measurement and operational safety

- [ ] Define the intended use of the app and sensor in precise, non-medical terms.
- [ ] Verify every formula used for concentration, dilution, dye, soda, water, and pH adjustment.
- [ ] Validate formulas with a qualified dyeing or chemical-process specialist.
- [ ] State measurement units everywhere they are displayed or entered.
- [ ] Reject impossible values instead of silently substituting defaults.
- [ ] Distinguish unavailable, stale, invalid, and below-limit measurements.
- [ ] Prevent a repair recommendation when its required inputs are missing or stale.
- [ ] Add safety warnings for chemical handling where appropriate.
- [ ] Avoid claims of laboratory, safety, or regulatory accuracy unless independently substantiated.
- [ ] Document calibration limitations and expected uncertainty.
- [ ] Obtain legal review for product claims and operational instructions.

## UI and UX readiness

### Primary workflows

- [ ] A new user can understand that compatible Serona hardware is required.
- [ ] Onboarding explains device selection, sensor placement, automatic baseline capture, and current readings.
- [ ] Creating a recipe is complete and understandable.
- [ ] Creating a bath clearly associates one recipe and one sensor.
- [ ] Initial baseline capture gives visible confirmation.
- [ ] Live concentration and pH display their units and freshness.
- [ ] Disconnect, reconnect, stale-data, and failure states are understandable and recoverable.
- [ ] Warnings identify whether concentration, pH, or both are outside project limits.
- [ ] Repair instructions are reviewable before the user applies them.
- [ ] Finishing a bath requires confirmation when data is incomplete.
- [ ] Users can review inactive baths and understand stored final readings.
- [ ] Destructive actions have confirmation and recovery where practical.

### Device and window support

- [ ] Decide whether Serona is iPad-only or supports both iPhone and iPad.
- [ ] Remove unsupported device families from the target and App Store metadata.
- [ ] Test every supported iPhone and iPad size.
- [ ] Test portrait and landscape orientations declared by the app.
- [ ] Test iPad Split View, Stage Manager, and runtime window resizing.
- [ ] Decide whether the iPad app should be available on Apple silicon Macs and Apple Vision Pro.
- [ ] Verify layouts with the smallest supported window and the largest accessibility text size.

### Visual and interaction quality

- [ ] Remove placeholder copy, temporary assets, debug controls, and preview-only behavior from production paths.
- [ ] Verify all buttons have clear labels and enabled/disabled explanations.
- [ ] Verify progress indicators for operations that may take noticeable time.
- [ ] Use text and icons in addition to color for every status.
- [ ] Verify Light, Dark, and Increase Contrast appearances.
- [ ] Avoid hard-coded backgrounds or foreground colors that break Dark Mode.
- [ ] Use consistent Indonesian terminology, punctuation, units, and capitalization.
- [ ] Localize all user-facing strings if more than one storefront language is claimed.

## Accessibility readiness

Identify the app's common tasks first, then verify that each claimed accessibility feature supports all of those tasks.

- [ ] Complete every common task using VoiceOver.
- [ ] Ensure controls have concise, human-readable accessibility labels.
- [ ] Ensure status icons include accessible meaning or are hidden when decorative.
- [ ] Verify correct traits for buttons, headings, selected states, alerts, and adjustable controls.
- [ ] Verify logical VoiceOver focus order after sheets, alerts, reconnects, and navigation.
- [ ] Complete every common task using Voice Control.
- [ ] Verify all text scales through the largest accessibility Dynamic Type size.
- [ ] Ensure layouts reflow rather than clip or truncate essential content.
- [ ] Meet a minimum 4.5:1 contrast ratio for normal text and 3:1 for qualifying large or bold text.
- [ ] Verify sufficient non-text contrast for meaningful controls and indicators.
- [ ] Respect Reduce Motion where animations are not essential.
- [ ] Ensure warnings do not rely on color, sound, or haptics alone.
- [ ] Test with Bold Text, Button Shapes, Increase Contrast, and Differentiate Without Color.
- [ ] Enter only accessibility claims that have been validated for all common tasks.
- [ ] Add an accessibility support URL if useful.

## Privacy and data governance

### Data inventory

- [ ] Inventory all data processed by the app, including customer names, project names, recipes, peripheral identifiers, sensor measurements, timestamps, diagnostics, and support information.
- [ ] Identify which data remains only on-device.
- [ ] Identify anything transmitted to Apple, a backend, analytics, crash reporting, support, or another third party.
- [ ] Document retention, deletion, backup, restore, export, and migration behavior.
- [ ] Re-audit the inventory whenever an SDK or online service is added.

### Privacy policy and in-app disclosure

- [ ] Publish a publicly accessible privacy-policy webpage.
- [ ] Add an easily accessible privacy-policy link inside the app.
- [ ] Identify all data collected, how it is collected, and every use.
- [ ] Identify third parties with access to data and their protections.
- [ ] Explain retention and deletion policies.
- [ ] Explain how users withdraw consent or request deletion where applicable.
- [ ] Provide support contact information for privacy requests.
- [ ] Ensure the policy matches actual code and App Store answers.

### App Store privacy disclosures

- [ ] Complete App Privacy answers in App Store Connect.
- [ ] Include third-party SDK behavior in the answers.
- [ ] Distinguish on-device processing from data transmitted off-device.
- [ ] Declare tracking only if the app or an integrated partner performs tracking as Apple defines it.
- [ ] Update the disclosures whenever data practices change.

### Privacy manifest

- [ ] Audit the app and dependencies for required-reason APIs.
- [ ] Add a valid `PrivacyInfo.xcprivacy` when declarations are required.
- [ ] Use only Apple's approved reasons that accurately match the app's behavior.
- [ ] Verify that every included third-party SDK provides required signatures and manifests.
- [ ] Generate and inspect Xcode's privacy report from the Release archive.
- [ ] Fix every App Store Connect privacy-manifest warning before submission.

### Permissions

- [x] Provide a Bluetooth purpose string.
- [ ] Confirm the Bluetooth purpose string clearly explains the user benefit and compatible hardware.
- [ ] Request permission only when the user starts a related workflow, where practical.
- [ ] Handle denial without trapping or misleading the user.
- [ ] Remove unused permission declarations.
- [ ] Add purpose strings before introducing any additional protected resource.

## Legal and business readiness

- [ ] Confirm the legal entity that owns the app, source code, firmware, brand, hardware design, and collected data.
- [ ] Ensure the Apple Developer account and App Store Connect record belong to the correct entity.
- [ ] Confirm all contributors have assigned or licensed necessary intellectual-property rights.
- [ ] Confirm licenses for icons, fonts, images, libraries, sample data, and other assets.
- [ ] Perform trademark clearance for “Serona,” its icon, and product branding.
- [ ] Publish terms of use.
- [ ] Publish hardware warranty and return terms where applicable.
- [ ] Publish customer support and security-reporting contact details.
- [ ] Review consumer-protection, privacy, radio, product-safety, chemical-workplace, and e-commerce obligations in every target country.
- [ ] Review whether Indonesian or other local registration, certification, labeling, or data-protection obligations apply.
- [ ] Obtain qualified legal advice before relying on this checklist as legal compliance.

## App Review access

Apple must be able to exercise the app's core functionality during review.

### Preferred: production demo mode

- [ ] Include a discoverable or review-instruction-accessible demo mode in the submitted binary.
- [ ] Simulate at least two independent BLE sensors.
- [ ] Demonstrate device assignment, initial baseline capture, current measurements, warnings, disconnect, reconnect, stale data, repair, and completion.
- [ ] Ensure demo mode does not mix simulated data with real production records unexpectedly.
- [ ] Explain demo mode in App Review notes.

### If physical hardware is required

- [ ] Contact App Review in advance when appropriate.
- [ ] Supply working review hardware and all required accessories.
- [ ] Provide charging, pairing, calibration, and reset instructions.
- [ ] Provide a direct support contact available during review.
- [ ] Keep any required backend or coordination service available throughout review.

### Review notes

- [ ] Explain that Serona communicates with a dedicated ESP32 BLE sensor.
- [ ] Explain the exact steps to create a recipe and bath.
- [ ] Explain that the first successful setup reading becomes 100%.
- [ ] Explain how subsequent readings are calculated against the persisted baseline.
- [ ] Explain all non-obvious warning and repair behaviors.
- [ ] Describe supported firmware and hardware versions.
- [ ] Include demo credentials or demo-mode steps if applicable.
- [ ] Include specific changes for every submitted version.

## App identity, signing, and distribution

- [ ] Use an organization-controlled bundle identifier.
- [ ] Confirm App ID, capabilities, certificates, and provisioning profiles.
- [ ] Use the intended production development team for every configuration.
- [ ] Set the marketing version and increment the build number for every upload.
- [ ] Confirm the minimum deployment target is intentional.
- [ ] Consider lowering the current iOS/iPadOS 27 minimum if no required API prevents it.
- [ ] Confirm supported platforms and device families.
- [ ] Complete export-compliance answers, including encryption usage.
- [ ] Verify no development entitlements or debug-only settings ship in Release.
- [ ] Archive using the final Xcode release required by App Store Connect.
- [ ] Validate and upload the archive through Xcode or an approved upload workflow.

## App Store Connect and product page

- [ ] Create the App Store Connect app record under the correct legal entity.
- [ ] Reserve the final app name.
- [ ] Choose the primary and secondary categories.
- [ ] Provide final subtitle, description, keywords, promotional text, and release notes.
- [ ] Clearly state that compatible Serona BLE hardware is required for live measurements.
- [ ] List compatible hardware and firmware versions.
- [ ] Provide an accurate support URL.
- [ ] Provide the required privacy-policy URL.
- [ ] Complete the age-rating questionnaire.
- [ ] Complete App Privacy disclosures.
- [ ] Complete Accessibility Nutrition Label answers.
- [ ] Provide copyright and contact information.
- [ ] Upload the final app icon.
- [ ] Capture accurate screenshots for every required iPhone and iPad display class that remains supported.
- [ ] Ensure screenshots show the submitted app and do not imply unsupported functionality.
- [ ] Add an app preview video only if it accurately shows real app behavior.
- [ ] Configure storefront availability and pricing.
- [ ] Decide Mac and Apple Vision Pro availability for the iPad app.

## TestFlight gate

- [ ] Upload a release-configured build to TestFlight.
- [ ] Complete internal testing with the development team.
- [ ] Complete external testing with representative dyeing operators.
- [ ] Test with supported iPhone and iPad hardware, if both remain supported.
- [ ] Test with each supported ESP32 firmware and sensor revision.
- [ ] Collect crash, hang, battery, disconnect, and usability feedback.
- [ ] Run a multi-hour active measurement session.
- [ ] Run repeated project creation and deletion cycles.
- [ ] Verify upgrades preserve recipes, projects, peripheral assignments, and baselines.
- [ ] Resolve all release-blocking feedback before App Review submission.

## Final submission gate

Do not submit until every item below is true:

- [ ] The full automated test suite passes.
- [ ] The Release archive builds and validates without blocking warnings.
- [ ] Core calculations have reference-sample validation.
- [ ] Two-sensor isolation is proven on physical hardware.
- [ ] Disconnect, reconnect, restoration, and stale-data flows are proven.
- [ ] Privacy policy, in-app privacy access, App Privacy answers, and manifest audit are complete.
- [ ] Accessibility claims are backed by common-task testing.
- [ ] App Review can use the complete core workflow without ambiguity.
- [ ] Hardware, firmware, protocol, calibration, and safety documentation are available.
- [ ] Product-page metadata and screenshots accurately match the submitted build.
- [ ] TestFlight feedback has been resolved.
- [ ] Legal and business owners approve the release.

## Current Serona evidence

- [x] Physical build, installation, and launch succeeded on `iPad (4)`.
- [x] A physical ESP32 sent complete 126-byte JSON BLE notifications.
- [x] iOS decoded pH values around 8.08–8.09 and all eight AS7341 channels.
- [x] Per-bath peripheral UUID persistence is implemented.
- [x] Per-peripheral sessions and callback routing are implemented.
- [x] Initial setup automatically captures and saves the 100% color baseline.
- [x] Reconnection logic retains the saved baseline in automated tests.
- [x] BLE routing, fan-out, framing, and validation tests pass.
- [ ] A second physical sensor has not yet been tested.
- [ ] The complete test suite is not currently passing.
- [ ] SwiftFormat and SwiftLint release gates have not run successfully in the current environment.
- [ ] No privacy policy was found in the app.
- [ ] No `PrivacyInfo.xcprivacy` file was found during the readiness review.
- [ ] A production App Review demo mode is not implemented.
- [ ] A complete accessibility audit has not been performed.

## Apple references

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Submitting apps to the App Store](https://developer.apple.com/app-store/submitting/)
- [App privacy details](https://developer.apple.com/app-store/app-privacy-details/)
- [Adding a privacy manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [Accessibility Nutrition Labels](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/)
- [Apple Bluetooth development](https://developer.apple.com/bluetooth/)
- [Apple accessory development](https://developer.apple.com/accessories/)
- [MFi frequently asked questions](https://mfi.apple.com/en/faqs.html)
