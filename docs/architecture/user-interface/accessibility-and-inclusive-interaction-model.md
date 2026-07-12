# Accessibility and Inclusive Interaction Model

> Document status: Normative Platform Foundation architecture.
>
> Implementation status: The Foundation migrations provide reusable structures for control catalogs, compliance profiles, control implementations, assurance artifacts, assessments, findings, remediation, exceptions, risk, client profiles, deployment profiles, governed documents, and operational telemetry. Accessibility is not considered implemented or conformant until applicable interface behavior, generated content, automated tests, manual evaluations, assistive-technology testing, deployment controls, and release acceptance requirements are in place.
>
> Conformance status: No Platform Foundation component, module, deployment, website, mobile application, document, or product may claim accessibility conformance solely because this architecture document exists or because an automated scanner reports no errors.

## Purpose

Define the Platform Foundation requirements for accessible, inclusive, understandable, and independently operable human interaction.

Accessibility is a functional, availability, safety, and governance requirement. It is not a cosmetic enhancement, optional user-interface preference, documentation-only claim, or final-stage compliance activity.

The platform must remain usable by people with differing:

* Vision,
* Hearing,
* Color perception,
* Mobility and dexterity,
* Speech,
* Cognitive and learning needs,
* Attention and memory needs,
* Input devices,
* Assistive technologies,
* Display sizes,
* Network conditions,
* Operational environments.

The platform must support accessible interaction across ordinary, urgent, degraded, emergency, and recovery conditions.

## Scope

This model applies to human-facing platform capabilities, including:

* Public websites and public web applications,
* Mobile applications,
* Citizen and community portals,
* Employee and administrative applications,
* Public-safety operational workstations,
* Dispatch and communications interfaces,
* Field and mobile operational interfaces,
* Kiosks and shared terminals,
* Authentication and session-management interfaces,
* Reports, forms, notices, and correspondence,
* Generated HTML, PDF, spreadsheet, presentation, and document output,
* Dashboards, charts, maps, timelines, and data visualizations,
* Email, text, push, and in-application notifications,
* Embedded help, training, and support materials,
* Installation, configuration, recovery, and administrative tools,
* Third-party components presented as part of a platform workflow.

Machine-to-machine APIs are not directly subject to visual or interactive accessibility requirements. Their documentation, administrative interfaces, error descriptions, developer portals, and generated outputs remain within scope when used by people.

## Legal and Standards Baseline

### United States State and Local Government Deployments

For deployments by United States state or local governments, applicable web content and mobile applications must meet the accessibility obligations imposed by Title II of the Americans with Disabilities Act and other applicable law.

The United States Department of Justice has adopted Web Content Accessibility Guidelines 2.1 Level AA as the technical standard for state and local government web content and mobile applications.

As of the approval of this document, the generally applicable compliance dates are:

* April 26, 2027, for public entities with a total population of 50,000 or more,
* April 26, 2028, for public entities with a total population of fewer than 50,000,
* April 26, 2028, for special district governments.

These dates do not suspend preexisting duties to provide effective communication, reasonable modifications, and equal access before the applicable technical-standard deadline.

The deployment owner must obtain appropriate legal or compliance review when determining:

* Whether a particular interface or item is legally within scope,
* Whether a regulatory exception applies,
* Whether an equivalent alternative is legally sufficient,
* Whether a claimed fundamental alteration or undue burden is valid,
* Whether state, federal, contractual, grant, employment, education, health, or public-safety requirements impose additional obligations.

A developer, product owner, system administrator, or vendor may not independently declare a legal exception merely because accessibility remediation is inconvenient, expensive, or technically difficult.

### Platform-Wide Baseline

The Platform Foundation adopts WCAG 2.1 Level AA as the minimum accessibility baseline for supported web and mobile interfaces.

The platform applies the substance of that baseline more broadly to operational, administrative, desktop, kiosk, generated-document, and other human-facing interfaces, even where a particular regulatory provision does not directly mandate WCAG conformance for that interface.

Newer accessibility standards and guidance may be evaluated and adopted through governed policy versions. Adoption of a newer standard must not silently invalidate historical assessments or alter the standard against which a previous release was evaluated.

A component assessed against one standard or version must not be represented as conformant with another standard or version without a documented mapping and sufficient evaluation.

## Non-Negotiable Principles

1. Accessibility is part of functional correctness.
2. A critical function must not depend on a single sensory characteristic.
3. A critical function must not require a mouse, touchscreen, voice, sound, color distinction, or precise physical movement as its only usable interaction method.
4. Security controls must be accessible without materially weakening their assurance.
5. Emergency operation must not suspend accessibility requirements.
6. Degraded operation must not silently remove the only accessible interaction path.
7. Important status, authority, risk, warning, and error information must be programmatically determinable where the technology supports it.
8. Color, position, shape, sound, vibration, animation, or iconography must not be the sole means of communicating critical meaning.
9. Accessibility preferences must follow the authorized operator where practical and must not require disclosure of a medical diagnosis.
10. An automated test result is not sufficient to establish conformance.
11. A vendor accessibility statement, accessibility conformance report, or voluntary product accessibility template is an input to assessment, not proof of effective accessibility.
12. Accessibility defects must be recorded, assessed, remediated, accepted through a governed exception, or shown to be inapplicable.
13. An exception must not erase the underlying finding or historical record.
14. Public and operational users must have a documented method to report accessibility barriers.
15. No release may claim accessibility conformance without defined scope, standard version, tested configuration, evaluation method, results, and unresolved limitations.

## Terminology

### Accessible Interaction

An interaction that a user can perceive, understand, navigate, operate, and complete using supported input methods and assistive technologies without an unnecessary loss of information, functionality, safety, privacy, or independence.

### Alternative Representation

A second representation of information or functionality that preserves the material meaning and permits equivalent use.

Examples include:

* A list representation for map information,
* Text and icon severity labels in addition to color,
* Visual alerts in addition to sound,
* Captions and transcripts for audio or video,
* A structured table supporting a chart,
* An accessible HTML form corresponding to a document form.

An alternative representation is not equivalent when it:

* Omits material information,
* Arrives too late for the operational purpose,
* Requires assistance from another person,
* Exposes additional sensitive information,
* Cannot perform the same authorized action,
* Requires a substantially more burdensome process,
* Becomes unavailable during degraded operation.

### Assistive Technology

Hardware, software, or platform functionality used to improve or enable interaction, including screen readers, screen magnifiers, speech input, switch devices, alternate keyboards, refreshable braille displays, hearing-support technology, high-contrast modes, and platform accessibility services.

### Critical Workflow

A workflow whose failure, delay, misunderstanding, or inaccessible operation may materially affect:

* Life safety,
* Emergency response,
* Public access to essential government services,
* Legal rights,
* Financial obligations,
* Privacy,
* Security,
* Evidence integrity,
* Time-sensitive operational decisions,
* Required reporting,
* Employment responsibilities.

### Essential Functionality

Information or functionality required to complete the intended purpose of an interface, service, workflow, report, or document.

### Accessibility Profile

A governed set of accessibility expectations for a client, deployment, application, operational environment, or supported user population.

An accessibility profile may define:

* Applicable standard and version,
* Required conformance level,
* Supported assistive technologies,
* Supported input methods,
* Display and zoom expectations,
* Document-output requirements,
* Operational constraints,
* Evaluation frequency,
* Release-blocking criteria.

An accessibility profile may add requirements but must not weaken a binding legal or contractual obligation.

### Accessibility Assurance Artifact

An assurance artifact supporting an accessibility assessment, such as:

* Automated scan output,
* Manual evaluation results,
* Keyboard test results,
* Screen-reader test recordings or workpapers,
* Contrast measurements,
* Component test results,
* Document inspection results,
* User testing summaries,
* Remediation verification,
* Accessibility conformance reports,
* Configuration exports,
* Release acceptance records.

An artifact is not automatically proof that a component or deployment is conformant.

## Responsibility Model

### Platform Foundation

The Foundation must provide reusable mechanisms for:

* Accessible session and security interaction,
* Client and deployment accessibility profiles,
* Governed standard versions,
* Common accessibility controls,
* Control implementations,
* Assurance artifacts,
* Assessments,
* Findings,
* Remediation,
* Exceptions,
* Risk treatment,
* Release evidence,
* Historical conformance records.

### Shared User-Interface Components

A shared design system or component library must define and test accessible behavior for reusable controls.

Shared components may include:

* Buttons,
* Links,
* Menus,
* Dialogs,
* Alerts,
* Tabs,
* Tables,
* Forms,
* Date and time controls,
* Search controls,
* Navigation,
* Status indicators,
* Notifications,
* Maps,
* Charts,
* Authentication controls.

A component’s accessibility does not guarantee that a page or workflow using it is accessible.

### Modules

Each module remains responsible for:

* Accessible domain workflows,
* Accurate labels and instructions,
* Meaningful focus order,
* Accessible validation,
* Equivalent representations,
* Domain-specific alerts,
* Accessible reports and generated documents,
* Module-specific testing.

A module may inherit shared controls only where the inherited implementation actually covers the module’s use.

### Deployment Owner

The deployment owner is responsible for:

* Identifying applicable legal and contractual obligations,
* Selecting supported configurations,
* Maintaining accessible content,
* Managing third-party dependencies,
* Providing reporting and accommodation channels,
* Reviewing unresolved findings,
* Approving authorized exceptions,
* Preserving assessment evidence,
* Ensuring continuing conformance after deployment.

### Content Authors

People who create or upload content must use supported accessible templates and authoring practices.

The platform should prevent, detect, or clearly warn about common inaccessible content, including:

* Missing alternative text,
* Improper heading structure,
* Unlabeled tables,
* Images containing essential text,
* Uncaptioned media,
* Inaccessible document exports,
* Ambiguous link text,
* Missing language identification.

### External Providers

External providers are responsible for the accessibility of the components and content they supply.

A contract, license, or provider relationship does not remove the deployment owner’s responsibility to evaluate the resulting public or operational experience.

## General Interaction Requirements

### Semantic Structure

Interfaces must use the native semantics of the delivery technology where available.

The platform must expose programmatic information sufficient to determine:

* Element name,
* Element role,
* Current state,
* Current value,
* Relationships,
* Required status,
* Invalid status,
* Expanded or collapsed state,
* Selected state,
* Modal state,
* Live status changes.

Visual appearance must not substitute for semantic meaning.

Headings, landmarks, lists, tables, forms, labels, and navigation regions must use logical structure.

Custom controls must not be created where a standard accessible control can provide the required behavior.

### Keyboard and Alternate Input

All essential functionality must be operable through a keyboard interface except where the underlying function inherently requires a path-dependent or analog input.

Keyboard users must be able to:

* Reach every interactive control,
* Determine which control has focus,
* Operate the control,
* Exit the control,
* Dismiss overlays and dialogs,
* Navigate repeated structures,
* Reach error messages,
* Complete and submit workflows,
* Recover from mistakes.

The platform must not create keyboard traps.

Keyboard order must follow a logical workflow and must not jump unpredictably between unrelated interface regions.

Mouse hover must not be the only method for revealing essential information or controls.

Pointer gestures requiring multiple contact points, drawing, dragging, or precise movement must have an alternative unless the gesture is essential to the activity.

Drag-and-drop interactions must provide an accessible non-drag alternative.

Single-character shortcuts must be disabled, remappable, or active only while the related control has focus when unintended activation could occur.

### Focus Management

Keyboard focus must remain visible.

Opening a dialog, menu, alert, or workflow step must place focus in a predictable location when moving focus is necessary.

Closing a temporary interface must return focus to an appropriate initiating or contextual control.

Focus must not be moved merely because content updates.

Focus must not be lost when:

* Validation fails,
* A background refresh occurs,
* A record is updated,
* A table is sorted,
* A notification appears,
* A session warning is displayed.

Critical alerts may request or move focus only when required for safety or immediate action and when the behavior is documented and tested.

### Visual Presentation

Text must remain readable under the contrast, zoom, text-spacing, reflow, and orientation requirements of the applicable accessibility profile.

Information must remain usable when:

* Text is enlarged,
* Browser zoom is increased,
* Display scaling is enabled,
* User-defined text spacing is applied,
* The viewport is narrow,
* A screen magnifier shows only part of the interface,
* High-contrast or forced-color mode is active.

Horizontal and vertical scrolling must not unnecessarily be required for ordinary text presentation.

Dense operational interfaces may require two-dimensional layouts where the relationship between rows and columns is essential. Those interfaces must still provide usable focus, navigation, labels, magnification behavior, and alternative representations where needed.

### Color and Contrast

Color must not be the sole method of identifying:

* Priority,
* Severity,
* Unit status,
* Availability,
* Validation result,
* Required fields,
* Selection,
* Warning,
* Success,
* Failure,
* Staleness,
* Authorization state,
* Classification,
* Emergency condition.

Text, icons, patterns, shapes, labels, position, and programmatic state should be combined as appropriate.

Text and meaningful interface components must meet the contrast requirements of the applicable standard.

Focus indicators, control boundaries, chart elements, map symbols, and meaningful status icons must remain distinguishable.

The design system must test component behavior in ordinary, dark, high-contrast, and forced-color presentations when those presentations are supported.

### Text, Language, and Comprehension

Interfaces should use direct, understandable language appropriate to the intended user and operational setting.

The platform must:

* Identify the primary language of content,
* Identify changes in language where required,
* Avoid unexplained abbreviations where they may cause misunderstanding,
* Provide clear field instructions,
* Use consistent control names,
* Use consistent navigation,
* Explain consequences before destructive or high-impact actions,
* Distinguish warnings from informational messages,
* Avoid unnecessary cognitive load.

Plain language must not remove legally, medically, operationally, or technically necessary precision.

Where specialized terminology is necessary, the platform should provide contextual explanation or accessible help.

### Forms and Data Entry

Every form control must have an accessible name.

Instructions must identify:

* Required values,
* Expected format,
* Constraints,
* Units,
* Date and time expectations,
* Validation requirements,
* Consequences where material.

Placeholder text must not be the only label or instruction.

Required fields must not be identified by color alone.

Validation errors must:

* Identify the affected field,
* Explain the problem,
* Preserve previously valid input,
* Provide correction guidance where possible,
* Be programmatically associated with the affected control,
* Be reachable and understandable without relying on visual position alone.

For legal, financial, public-safety, privacy-sensitive, or irreversible submissions, users must be able to review, correct, and confirm information where operationally appropriate.

### Tables and Repeated Data

Data tables must expose:

* Table identity or description where needed,
* Column headers,
* Row headers where needed,
* Header relationships,
* Sort state,
* Selection state,
* Expanded state,
* Pagination or virtual-scroll state.

Keyboard users must be able to navigate interactive tables without losing context.

Virtualized tables must preserve usable assistive-technology semantics and must not expose only the currently visible subset as though it were the complete dataset without clearly communicating that limitation.

Bulk actions must identify:

* The number of affected records,
* The selected records or selection rule,
* The action to be performed,
* Whether the action is reversible,
* Whether partial completion occurred.

### Dialogs, Menus, and Temporary Content

Dialogs must:

* Have an accessible name,
* Identify their purpose,
* Manage focus predictably,
* Prevent unintended interaction with obscured content when modal,
* Provide an accessible closing method,
* Return focus appropriately.

Tooltips, popovers, menus, and content shown on hover or focus must be dismissible, hoverable where required, and persistent long enough to be perceived.

Essential information must not exist only in a transient tooltip.

### Time Limits

Users must be warned before a session, task, form, or authorization state expires when advance warning is operationally possible.

Where allowed by security and operational policy, users must be able to:

* Extend a time limit,
* Request additional time,
* Preserve entered data,
* Reauthenticate without losing work,
* Resume an interrupted process safely.

A security-based time limit must be justified by the security policy and must not be shortened merely to avoid implementing accessible continuation behavior.

Public-safety workflows may require strict operational time limits. Such limits must be documented, tested with assistive technologies, and designed to avoid unnecessary loss of work or authority context.

### Motion, Animation, and Flashing

The platform must not use flashing content that exceeds applicable safety thresholds.

Motion and animation must not be required to understand critical information.

Nonessential animation should respect supported reduced-motion preferences.

Content triggered by motion must have an alternative unless motion is essential.

Animation must not delay or obstruct urgent operational action.

## Alerts, Notifications, and Status Changes

Alerts and status changes must provide an accessible representation appropriate to urgency.

A critical alert must not depend solely on:

* Sound,
* Color,
* Flashing,
* Vibration,
* Screen position,
* A transient visual banner.

Alerts may combine:

* Text,
* Severity labels,
* Icons,
* Sound,
* Vibration,
* Visual emphasis,
* Programmatic announcements.

High-frequency systems must prevent assistive technologies from being overwhelmed by constant low-value announcements.

The notification architecture must support:

* Severity,
* Priority,
* Source,
* Affected resource,
* Time,
* Age,
* Acknowledgment state,
* Expiration,
* Suppression rules,
* Escalation,
* Accessible announcement behavior.

The platform must distinguish:

* New information,
* Changed information,
* Repeated information,
* Stale information,
* Acknowledged information,
* Cleared information.

Acknowledging an alert must not silently mean that the underlying condition has been resolved.

Critical acknowledgments must remain keyboard operable and must expose the alert being acknowledged.

## Authentication, Sessions, and Security Controls

Security controls must be designed for accessible completion.

Authentication must not rely exclusively on:

* A biometric characteristic,
* Visual pattern recognition,
* Audio recognition,
* Fine motor movement,
* Memorization of a complex transient value,
* A CAPTCHA without an accessible alternative,
* A mobile-device interaction that is inaccessible to the operator.

Where multiple authentication methods provide equivalent assurance, the platform should allow an authorized accessible method.

An accessibility alternative must not silently reduce:

* Authentication strength,
* Device binding,
* Session binding,
* Replay protection,
* Approval independence,
* Auditability,
* Attribution.

Authentication and session interfaces must provide accessible:

* Identity-provider selection,
* Credential entry,
* MFA prompts,
* Device-trust status,
* Step-up requests,
* Session-expiration warnings,
* Lock messages,
* Revocation messages,
* Recovery instructions,
* Error messages.

A user must not lose unsaved work merely because reauthentication is required when work can be safely preserved.

Session warnings must identify:

* What is expiring,
* When expiration will occur,
* Whether work is preserved,
* Whether extension is permitted,
* What action is required.

Break-glass and emergency-access workflows must remain accessible. Emergency status is not permission to require an inaccessible control.

## Public-Safety and Operational Workstation Requirements

### Operational Safety

An accessible operational interface must preserve speed, precision, awareness, and accountability.

Accessibility must not be implemented by removing necessary operational information. The platform should instead provide adaptable presentation, predictable navigation, equivalent representations, and operator-selectable detail.

### Dispatch and Communications Workstations

Dispatch and communications interfaces must support:

* Complete keyboard operation for essential workflows,
* Predictable focus movement,
* Configurable but governed keyboard commands,
* Programmatically exposed unit, incident, priority, and alert states,
* Non-color-only status indicators,
* Visual equivalents for audible alerts,
* Audible or programmatic equivalents for visual-only alerts where appropriate,
* Accessible timers and elapsed-time indicators,
* Accessible queue and pending-action representations,
* Persistent critical alerts until acknowledged or resolved according to policy.

The interface must clearly distinguish:

* Selected record,
* Active incident,
* Current unit,
* Pending action,
* Queued action,
* Failed action,
* Stale information,
* Unconfirmed information,
* Lost connectivity.

### Maps and Geospatial Information

A map must not be the only means of obtaining essential operational information.

Essential mapped information must have an accessible representation that may include:

* Unit identifier,
* Unit type,
* Unit status,
* Location description,
* Coordinates where appropriate,
* Assignment,
* Incident,
* Direction of travel,
* Last update time,
* Age of location,
* Confidence or accuracy,
* Priority,
* Proximity,
* Jurisdiction or Governed Scope.

Map symbols must not rely on color alone.

Keyboard users must be able to reach and inspect meaningful map objects or use an equivalent synchronized list or table.

Selecting an item in the map and selecting the corresponding item in an alternative representation should produce consistent context.

Location age and staleness must be exposed as information, not only through fading, color, or animation.

### High-Density Displays

Operational interfaces may contain more simultaneous information than ordinary public interfaces.

High density does not waive accessibility.

High-density interfaces must support:

* Logical region navigation,
* Stable landmarks,
* Predictable reading order,
* User-controlled panel visibility where safe,
* Magnification without loss of essential controls,
* Accessible summaries,
* Keyboard shortcuts with documented behavior,
* Nonvisual identification of active context,
* Clear differentiation between view state and committed operational state.

The platform must not assume that every operator uses multiple monitors or a specific screen resolution unless the deployment profile expressly requires and provides that configuration.

### Multi-Modal Alerts

Urgent operational alerts should support multiple presentation channels.

A sound should have a visible and programmatically determinable counterpart.

A visual emergency state should have a text or programmatic counterpart.

Vibration or haptic feedback must not be the only indicator.

User preferences may adjust nonessential presentation but must not suppress mandatory life-safety alerts without governed authorization.

### Shared Workstations

Accessibility preferences should follow the authenticated operator where practical.

Preferences may include:

* Text size,
* Contrast mode,
* Reduced motion,
* Notification presentation,
* Keyboard configuration,
* Panel arrangement,
* Announcement verbosity.

The platform should record functional interaction preferences without requiring the user to disclose a disability or medical diagnosis.

Preferences must not override mandatory security, life-safety, or data-handling controls.

A shared workstation must not expose one operator’s confidential preferences, private information, drafts, or session context to another operator.

## Mobile and Touch Requirements

Mobile applications must support the accessibility services of their supported operating systems.

Essential actions must not require:

* Precise touch,
* Multi-finger gestures without alternatives,
* Device motion without alternatives,
* A fixed device orientation unless essential,
* Dragging without an alternative,
* Small or tightly packed targets where avoidable.

Control names exposed to assistive technology must correspond to visible labels.

Mobile content must remain usable with:

* Screen readers,
* Display magnification,
* Increased text size,
* Reduced motion,
* Alternative input,
* Portrait and landscape orientation where not operationally restricted.

Loss of connectivity must be clearly communicated.

Queued, unsent, synchronized, conflicting, rejected, and committed records must be distinguishable without relying only on color or icons.

## Documents, Reports, and Generated Content

Accessibility requirements apply to content generated by the platform.

Generated documents must use accessible source structures before conversion.

Where applicable, generated documents must provide:

* A meaningful title,
* Identified document language,
* Logical heading structure,
* Correct reading order,
* Tagged lists,
* Tagged tables with headers,
* Alternative text,
* Descriptive links,
* Accessible form controls,
* Bookmarks for long documents where appropriate,
* Sufficient contrast,
* Selectable and searchable text,
* Appropriate metadata.

A scanned image of text is not an accessible document merely because optical character recognition can sometimes interpret it.

A public-facing PDF should have an accessible HTML alternative when the PDF format cannot provide an equivalent accessible experience.

Generated charts must provide the material values or conclusions through an accessible table, summary, or equivalent representation.

Generated spreadsheets must use meaningful sheet names, table headings, reading order, instructions, and formatting that does not rely solely on color.

Document templates must be versioned and governed. A previously accessible template must not silently become inaccessible through an uncontrolled template change.

The platform must record which template and rendering version produced a material governed document.

## Media Requirements

Prerecorded synchronized media must provide captions and other alternatives required by the applicable standard.

Live media must provide required real-time accessibility support when within the applicable scope.

Audio-only content must have an equivalent transcript or text representation where required.

Video must not communicate critical instructions solely through visual action.

Captions must identify meaningful speakers and sounds when necessary for understanding.

Automatically generated captions must be reviewed when errors could materially alter meaning.

## Degraded, Offline, and Recovery Conditions

Accessible behavior must be evaluated during:

* Slow network conditions,
* Intermittent connectivity,
* Offline operation,
* Failover,
* Read-only operation,
* Queued delivery,
* Partial service outage,
* Authentication-provider outage,
* Map-provider outage,
* Notification-provider outage,
* Disaster recovery,
* Emergency operation.

A degraded interface must communicate:

* Which capability is degraded,
* Which information may be stale,
* Which actions remain available,
* Which actions are queued,
* Which actions failed,
* Whether retry is safe,
* How the user will know when normal operation returns.

An accessible primary interaction must not disappear merely because the platform enters degraded mode.

Fallback interfaces, emergency forms, recovery consoles, and offline procedures must themselves be evaluated for accessibility.

## User Preferences and Privacy

Accessibility preferences must be treated as functional configuration.

The platform should not require storage of:

* Disability diagnoses,
* Medical history,
* Accommodation justification,
* Sensitive personal explanations.

The minimum information necessary to provide the selected interaction should be stored.

Accessibility preferences may reveal sensitive characteristics by inference. Access, logging, analytics, export, and retention must therefore be limited to what is operationally necessary.

Telemetry must not identify or fingerprint an assistive-technology user unless the collection is necessary, disclosed, authorized, and governed.

Accessibility analytics should focus on interface failures and workflow barriers rather than identifying individual users.

## External Components and Procurement

Third-party components must be evaluated in the context in which they are used.

Relevant components may include:

* Identity-provider pages,
* Payment systems,
* Mapping systems,
* Document viewers,
* Scheduling tools,
* Chat systems,
* Video systems,
* Embedded dashboards,
* Form builders,
* CAPTCHA providers,
* Notification portals,
* Support portals.

Procurement and integration requirements should require:

* Applicable accessibility standard,
* Supported conformance level,
* Known exceptions,
* Accessibility conformance documentation,
* Testing rights,
* Defect-remediation obligations,
* Notification of material accessibility changes,
* Continued compatibility commitments,
* Accessible support channels,
* Exit and replacement provisions.

A vendor-provided accessibility conformance report must be assessed for:

* Scope,
* Product version,
* Test date,
* Evaluation method,
* Unsupported criteria,
* Partially supported criteria,
* Assumptions,
* Third-party exclusions,
* Deployment differences.

The platform must not inherit a provider’s accessibility claim without evaluating whether the claim covers the actual integrated workflow.

## Accessibility Testing Model

### Automated Evaluation

Automated accessibility testing should run against:

* Shared components,
* Representative pages,
* Critical workflows,
* Generated HTML,
* Supported viewport sizes,
* Supported themes,
* Public interfaces,
* Administrative interfaces,
* Operational interfaces where technically possible.

Automated testing may detect issues such as:

* Missing names,
* Invalid relationships,
* Missing landmarks,
* Some contrast failures,
* Duplicate identifiers,
* Invalid ARIA use,
* Some form-label failures,
* Some document-structure failures.

Passing automated tests does not establish conformance.

### Manual Evaluation

Manual evaluation must include applicable testing of:

* Keyboard-only operation,
* Focus order,
* Focus visibility,
* Keyboard traps,
* Dialog behavior,
* Error recovery,
* Status announcements,
* Zoom and reflow,
* Text spacing,
* High-contrast or forced-color mode,
* Non-color-only meaning,
* Motion and flashing,
* Time limits,
* Alternative representations,
* Generated documents,
* Degraded operation.

### Assistive-Technology Evaluation

Accessibility profiles must identify a representative test matrix.

The matrix should include applicable combinations of:

* Screen reader and browser,
* Screen magnifier and browser,
* Mobile screen reader and operating system,
* Voice or alternate input,
* Keyboard-only interaction,
* High-contrast or forced-color presentation,
* Reduced-motion settings.

The profile should identify supported current or recent stable versions without permanently binding the architecture to one vendor or version.

### User Evaluation

Critical public and operational workflows should be evaluated with users with disabilities.

User evaluation complements but does not replace standards-based conformance testing.

Testing must avoid requiring participants to disclose unnecessary medical information.

Operational user testing should use representative:

* Workstations,
* Displays,
* Input devices,
* Network conditions,
* Lighting,
* Noise,
* Alert volume,
* Workflow pressure,
* Degraded conditions.

### Document Evaluation

Generated documents must be evaluated separately from the application that generates them.

Document evaluation should inspect:

* Tags and structure,
* Reading order,
* Tables,
* Alternative text,
* Forms,
* Metadata,
* Language,
* Contrast,
* Link purpose,
* Keyboard navigation,
* Assistive-technology output.

### Regression Testing

A defect that has been remediated must receive a regression test when the behavior can be tested reliably.

Shared-component defects require evaluation of dependent modules and workflows.

A design-system change must not be accepted solely because the component demonstration page passes. Representative consuming workflows must also be tested.

## Assessment and Assurance

An accessibility assessment must identify:

* Assessment scope,
* Component or deployment,
* Product and release version,
* Applicable accessibility profile,
* Standard and version,
* Conformance level,
* Supported technologies,
* Test environment,
* Tools used,
* Assistive technologies used,
* Manual procedures,
* Evaluators,
* Evaluation dates,
* Findings,
* Limitations,
* Exclusions,
* Retest results,
* Final determination.

Assessment artifacts must retain sufficient provenance to support later review.

Screenshots alone are not sufficient assurance for dynamic behavior.

A clean automated report must not override a contradictory manual or user finding.

Stale assurance artifacts must not silently satisfy a current release assessment.

## Findings and Severity

Accessibility findings must be recorded through governed finding and remediation structures.

Severity should consider:

* Whether essential functionality is blocked,
* Whether a critical workflow is affected,
* Whether an accessible alternative exists,
* Whether the user requires assistance from another person,
* Whether the issue affects safety,
* Whether privacy or independence is reduced,
* Number of affected users,
* Frequency of the workflow,
* Legal deadline,
* Public exposure,
* Operational consequence,
* Remediation complexity.

Suggested severity interpretation:

### Blocker

Essential or life-safety functionality cannot be completed by an affected user and no timely equivalent accessible path exists.

### Critical

A critical workflow is materially inaccessible, unreliable, unsafe, or dependent on assistance, even though limited workarounds may exist.

### Major

A required accessibility criterion is not met and the barrier materially impairs independent use, but essential work can still be completed through a reasonable accessible path.

### Minor

The issue creates avoidable difficulty or inconsistency but does not materially prevent completion of the workflow.

Severity does not determine legal compliance by itself.

## Release Acceptance

A release containing human-facing functionality must not be considered accessibility-accepted until:

1. The applicable accessibility profile is identified.
2. Applicable standard versions are recorded.
3. Shared components used by the release have current assurance.
4. Critical workflows have been manually evaluated.
5. Applicable keyboard testing has passed.
6. Applicable assistive-technology testing has passed.
7. Applicable zoom, reflow, contrast, and text-spacing testing has passed.
8. Generated documents have been evaluated.
9. Degraded and error behavior has been evaluated where material.
10. Automated testing has completed.
11. Findings are recorded.
12. Remediation has been verified.
13. Remaining exceptions are authorized, time-bounded, and supported by an accessible alternative where required.
14. Release evidence is retained.
15. Public accessibility statements accurately describe the evaluated scope and known limitations.

Open blocker findings prevent release.

Open critical findings affecting essential functionality normally prevent release.

A Level A or Level AA failure within a binding conformance scope normally prevents a conformance claim unless an authorized determination establishes that the criterion is inapplicable or a legally valid exception applies.

A release may not describe itself as fully conformant while silently excluding known affected workflows.

## Exception Governance

An accessibility exception must identify:

* The exact requirement,
* Affected component and version,
* Affected workflow,
* Affected population,
* Reason the requirement is not currently met,
* Legal and compliance analysis where applicable,
* Available alternative,
* Whether the alternative is timely and equivalent,
* Compensating controls,
* Risk owner,
* Remediation owner,
* Approval authority,
* Approval date,
* Expiration date,
* Review schedule,
* Remediation target,
* Conditions requiring immediate reconsideration.

An exception must be:

* Narrowly scoped,
* Time bounded,
* Reviewable,
* Historically retained,
* Visible to authorized governance personnel,
* Linked to the underlying finding.

An exception must not:

* Delete the finding,
* Change failed evidence into passing evidence,
* Falsely create a conformance claim,
* Rely solely on vendor assurance,
* Remain indefinitely active without review,
* Require an affected user to disclose unnecessary medical information,
* Replace an accessible product function with routine human assistance when independent equivalent access is required.

Claims of fundamental alteration, undue burden, technical infeasibility, or legal exception require authorization by the appropriate public entity or organizational authority. They may not be declared by the implementation team alone.

## Accessibility Issue Reporting

Supported deployments must provide an accessible method to report a barrier.

The reporting path must:

* Be discoverable,
* Be usable without the inaccessible function where possible,
* Accept sufficient context,
* Protect sensitive information,
* Provide acknowledgment,
* Support status tracking,
* Route urgent operational barriers appropriately.

Reports must be triaged into the governed finding process when they identify a product or deployment defect.

Public reporting channels must not require the reporter to identify a diagnosis.

## Observability

Accessibility telemetry may include:

* Failed client-side validations,
* Repeated workflow abandonment,
* Focus failures detected by tests,
* Document-generation accessibility failures,
* Unsupported component usage,
* Missing accessible names detected during build,
* Accessibility regression-test results,
* Open finding counts,
* Remediation age,
* Exception age,
* Assessment freshness.

Telemetry must not claim to measure conformance where it measures only automated rule results.

Accessibility telemetry must be attributable to:

* Product version,
* Component version,
* Deployment,
* Test configuration,
* Collection period.

Operational dashboards must distinguish:

* Automated results,
* Manual results,
* User-reported barriers,
* Unverified reports,
* Confirmed findings,
* Remediated findings,
* Accepted exceptions.

## Performance and Accessibility

Performance degradation can create accessibility barriers.

The platform must consider:

* Delayed focus changes,
* Delayed status announcements,
* Repeated announcements,
* Input loss,
* Focus loss during refresh,
* Timeouts caused by assistive-technology interaction,
* Excessive document-object complexity,
* Large inaccessible virtualized tables,
* Slow alternative representations,
* Delayed captions or transcripts.

An alternative representation must be available within a timeframe suitable for the operational purpose.

Critical accessibility paths must be included in performance profiles and workload testing.

## SQL Implementation Mapping

The Foundation should reuse existing domain-neutral governance structures rather than create a disconnected accessibility-compliance silo.

Relevant migrations include:

* `086_governed_documents_and_policy_versions.sql` for governed accessibility policies, standards references, templates, and versions,
* `087_common_control_catalog.sql` for reusable accessibility controls,
* `088_compliance_profiles_and_requirement_mappings.sql` for accessibility profiles and requirement mappings,
* `089_control_implementations_and_assurance_artifacts.sql` for implementation descriptions and accessibility assurance artifacts,
* `090_assessments_findings_remediation_exceptions_and_risk.sql` for assessments, findings, remediation, exceptions, and risk,
* `094_client_and_deployment_performance_profiles.sql` for client, device, display, input, accessibility, and deployment expectations,
* `095_observability_health_and_operational_telemetry.sql` for governed accessibility-related operational telemetry where appropriate.

These migrations provide structural capabilities. Their existence does not prove that accessibility requirements are enforced or that any interface conforms.

Additional migrations should be introduced only when a requirement cannot be represented soundly through existing Foundation concepts.

Operator interaction preferences may require a future controlled data model. Any such model must:

* Avoid storing unnecessary medical information,
* Separate operator preferences from device-global settings,
* Apply least-privileged access,
* Preserve change history where material,
* Support safe defaults,
* Prevent one operator’s preferences from affecting another operator’s session.

## Validation Expectations

The Foundation SQL test framework should validate accessibility governance properties that exist at the database boundary, including:

* Accessibility standard versions cannot be silently overwritten,
* Profile mappings preserve historical versions,
* Assessment scope is attributable,
* Assurance artifacts retain provenance and integrity fields,
* Stale artifacts do not silently satisfy current assessment requirements,
* Findings remain historically available after remediation,
* Exceptions require ownership, scope, approval, and expiration,
* Expired exceptions do not silently remain effective,
* Release evidence references the evaluated component and version,
* Accessibility preferences cannot be changed through unauthorized write paths when such preferences are implemented.

Interface behavior must be tested in the client, service, document-rendering, deployment, and operational layers where that behavior exists.

Database tests cannot establish:

* Keyboard usability,
* Screen-reader compatibility,
* Contrast,
* Focus behavior,
* Reflow,
* Document reading order,
* Alert perception,
* Cognitive clarity,
* Effective user operation.

## Implementation Sequence

Accessibility implementation should proceed in the following order:

1. Adopt this normative architecture.
2. Register the applicable accessibility standards and governed policy versions.
3. Define initial common accessibility controls.
4. Define public, administrative, operational, mobile, and generated-document accessibility profiles.
5. Establish accessible shared design-system components.
6. Establish automated component and workflow testing.
7. Establish manual keyboard and visual evaluation procedures.
8. Establish representative assistive-technology test matrices.
9. Establish generated-document accessibility validation.
10. Establish finding, remediation, exception, and release-acceptance workflows.
11. Validate one complete operational vertical slice.
12. Validate one complete public-facing vertical slice.
13. Retain assurance artifacts for accepted release boundaries.
14. Obtain independent accessibility review before production claims.
15. Include users with disabilities in representative usability evaluation.
16. Reassess after material component, browser, operating-system, assistive-technology, or workflow changes.

## Minimum Initial Vertical Slices

### Operational Vertical Slice

The first operational accessibility proof should include:

* Accessible authentication,
* Session establishment,
* Step-up authentication,
* Keyboard navigation,
* Incident or work-item selection,
* Status review,
* Map alternative,
* Critical alert presentation,
* Form entry,
* Validation,
* Controlled submission,
* Result confirmation,
* Session-expiration behavior,
* Degraded-operation behavior,
* Decision Record or attributable audit result.

### Public Vertical Slice

The first public accessibility proof should include:

* Accessible navigation,
* Accessible authentication where required,
* Form instructions,
* Data entry,
* Validation and correction,
* Document attachment,
* Review and confirmation,
* Submission,
* Status tracking,
* Generated confirmation document,
* Accessible error and support path.

## Conformance Claims

A conformance claim must identify:

* Product or platform component,
* Version,
* Deployment configuration,
* Pages, screens, workflows, documents, or applications included,
* Standard and version,
* Conformance level,
* Supported technologies,
* Test date,
* Evaluation method,
* Known limitations,
* Excluded content,
* Third-party dependencies.

The following statements are prohibited unless supported by the applicable assessment:

* “Fully accessible,”
* “ADA compliant,”
* “WCAG compliant,”
* “Meets all accessibility requirements,”
* “Certified accessible.”

A partial assessment may be described only as a partial assessment.

An accessibility conformance report must not be treated as a permanent product characteristic. Conformance may change when:

* The product changes,
* Content changes,
* A provider changes,
* A browser changes,
* An operating system changes,
* A document template changes,
* A deployment configuration changes,
* A previously unknown barrier is confirmed.

## Change Discipline

A change affecting human interaction should normally update:

1. The governing architecture or design-system requirement,
2. The applicable accessibility profile,
3. The interface or generated-content implementation,
4. Automated tests,
5. Manual test procedures,
6. Assistive-technology test coverage,
7. Assurance artifacts,
8. Findings and remediation records,
9. User and administrator documentation,
10. Deployment requirements where supported configurations change.

A shared-component change must identify dependent workflows requiring regression evaluation.

A standard-version change must preserve the historical standard and assessment version used for prior releases.

## Relationship to Client Experience

Accessibility and client experience are related but not interchangeable.

Performance, responsiveness, clarity, low-bandwidth operation, and degraded behavior can materially affect accessibility. However, a responsive interface may still be inaccessible, and an interface that passes selected accessibility checks may still be confusing or operationally unsafe.

`client-experience-and-accessibility-model.md` should be revised to focus on:

* Responsiveness,
* Client profiles,
* Low-bandwidth behavior,
* Error behavior,
* Degraded-state presentation,
* General experience expectations.

That document should reference this model as the authoritative accessibility and inclusive-interaction architecture.

## Related Documents

* `README.md`
* `platform-boundaries.md`
* `foundation-terminology-and-domain-neutrality.md`
* `authentication-and-authorization-evaluation.md`
* `session-establishment-step-up-and-lifecycle-model.md`
* `authorization-evaluation-contract.md`
* `decision-record-repository.md`
* `data-classification-and-information-governance-model.md`
* `governed-document-and-policy-versioning-model.md`
* `compliance-and-control-framework.md`
* `common-security-control-catalog-model.md`
* `compliance-profile-versioning-model.md`
* `control-implementation-and-assurance-artifact-model.md`
* `security-finding-exception-and-remediation-model.md`
* `risk-assessment-and-treatment-model.md`
* `resilience-availability-and-recovery-model.md`
* `performance-efficiency-and-resource-governance-model.md`
* `client-experience-and-accessibility-model.md`
* `observability-health-and-operational-telemetry-model.md`

## External Standards and Guidance

The implementation and assessment process should review the current authoritative versions of:

* Americans with Disabilities Act Title II regulations and Department of Justice web and mobile application accessibility guidance,
* Web Content Accessibility Guidelines 2.1,
* W3C WCAG supporting understanding and technique documents,
* W3C guidance for applying WCAG to mobile applications,
* W3C guidance for applying WCAG to non-web documents and software,
* Applicable federal, state, contractual, grant, procurement, education, employment, health, and public-safety accessibility requirements.

Supporting guidance may explain how to satisfy a requirement but does not replace the normative standard or applicable law.

## Final Architectural Position

The platform must not ask a government, employee, resident, responder, dispatcher, student, patient, customer, or member of the public to choose between accessibility and:

* Security,
* Privacy,
* Safety,
* Independence,
* Timeliness,
* Accuracy,
* Equal participation,
* Access to government services.

Accessibility is part of whether the platform works.

A workflow that exists but cannot be independently perceived, understood, navigated, or operated by an affected authorized user is not a complete workflow.

An accessibility claim without defined scope, repeatable evaluation, attributable findings, remediation history, and retained assurance is not a trustworthy platform claim.


