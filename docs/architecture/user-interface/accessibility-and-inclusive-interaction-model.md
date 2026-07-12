# Accessibility and Inclusive Interaction Model

> **Document status:** Normative cross-platform user-interface architecture.
>
> **Implementation status:** Accessibility must be implemented and validated by every applicable shared component, module interface, public portal, administrative client, operational workstation, mobile application, generated-content implementation, and supported deployment.
>
> **Conformance status:** No component, deployment, website, application, document, or product may claim accessibility conformance solely because this architecture exists or because an automated scanner reports no errors.

## Purpose

Define requirements for accessible, inclusive, understandable, and independently operable human interaction.

Accessibility is a functional, availability, safety, quality, and governance requirement. It is not:

- A cosmetic enhancement,
- An optional preference,
- A documentation-only claim,
- A final-stage compliance activity,
- A substitute for effective user evaluation.

The Platform must support people with differing:

- Vision,
- Hearing,
- Color perception,
- Mobility and dexterity,
- Speech,
- Cognitive and learning needs,
- Attention and memory needs,
- Input methods,
- Assistive technologies,
- Display sizes and scaling,
- Network conditions,
- Operational environments.

Accessible interaction must remain considered during ordinary, urgent, degraded, emergency, recovery, and shared-workstation conditions.

## Scope

This model applies to human-facing Platform capabilities, including:

- Public websites and applications,
- Mobile applications,
- Citizen and community portals,
- Employee and administrative applications,
- Operational workstations,
- Field and mobile operational interfaces,
- Kiosks and shared terminals,
- Authentication and session interfaces,
- Reports, forms, notices, and correspondence,
- Generated HTML, PDF, spreadsheets, presentations, and documents,
- Dashboards, charts, maps, timelines, and visualizations,
- Email, text, push, and in-application notifications,
- Embedded help, training, recovery, and support material,
- Installation, configuration, and administrative tools,
- Third-party components presented as part of a Platform workflow.

Machine-to-machine APIs are not directly subject to visual and interactive requirements. Their documentation, error descriptions, administrative tools, developer portals, and generated outputs remain in scope when used by people.

## Standards Baseline

The Platform adopts **WCAG 2.1 Level AA** as the minimum baseline for supported web and mobile interfaces.

The substance of that baseline must also inform operational, administrative, desktop, kiosk, generated-document, and other human-facing interfaces where WCAG is not a direct technical fit.

A deployment may require additional or newer standards because of:

- Law,
- Regulation,
- Contract,
- Grant conditions,
- Employment obligations,
- Education obligations,
- Health requirements,
- Public-safety requirements,
- Organizational policy.

Applicable obligations must be represented through governed accessibility profiles and reviewed by the responsible organizational, legal, or compliance authority.

A developer, administrator, product owner, or vendor may not independently declare a legal exception merely because remediation is inconvenient, expensive, or technically difficult.

Adoption of a newer standard must preserve historical assessment scope and version. A component assessed against one standard or version must not be represented as assessed against another without documented mapping and sufficient evaluation.

## Non-Negotiable Principles

1. Accessibility is part of functional correctness.
2. Essential functionality must support independent operation where required.
3. A critical function must not depend on a single sensory characteristic.
4. A critical function must not require a mouse, touchscreen, voice, sound, color distinction, or precise physical movement as its only usable method.
5. Security controls must be accessible without materially weakening assurance.
6. Emergency operation does not suspend accessibility requirements.
7. Degraded operation must not silently remove the only accessible path.
8. Important status, authority, risk, warning, and error information must be programmatically determinable where supported by the technology.
9. Color, position, shape, sound, vibration, animation, and iconography must not be the sole means of communicating critical meaning.
10. Accessibility preferences should follow the authenticated user where practical without requiring disclosure of a diagnosis.
11. Automated test results alone cannot establish conformance.
12. Vendor statements and accessibility conformance reports are assessment inputs, not proof of effective accessibility.
13. Accessibility defects must be recorded, assessed, remediated, governed through a time-bounded exception, or shown to be inapplicable.
14. An exception must not erase the finding or historical record.
15. Supported users must have an accessible method to report barriers.
16. No release may claim conformance without defined scope, standard, version, tested configuration, evaluation method, results, and unresolved limitations.

## Terminology

### Accessible Interaction

An interaction a person can perceive, understand, navigate, operate, and complete using supported input methods and assistive technologies without unnecessary loss of information, functionality, safety, privacy, or independence.

### Essential Functionality

Information or functionality required to complete the intended purpose of an interface, workflow, service, report, or document.

### Critical Workflow

A workflow whose failure, delay, misunderstanding, or inaccessible operation may materially affect:

- Life safety,
- Emergency response,
- Public access to essential services,
- Legal rights,
- Financial obligations,
- Privacy,
- Security,
- Evidence integrity,
- Time-sensitive decisions,
- Required reporting,
- Employment responsibilities.

### Alternative Representation

A second representation that preserves material meaning and permits equivalent use.

Examples include:

- A structured list for map information,
- Text and icon severity labels in addition to color,
- Visible and programmatic alerts in addition to sound,
- Captions and transcripts for media,
- A data table and summary supporting a chart,
- Accessible HTML corresponding to a document form.

An alternative is not equivalent when it:

- Omits material information,
- Arrives too late for the operational purpose,
- Requires assistance from another person when independent use is required,
- Exposes additional sensitive information,
- Cannot perform the same authorized action,
- Creates a substantially more burdensome process,
- Becomes unavailable during degraded operation.

### Accessibility Profile

A governed set of expectations for a client, deployment, application, operational environment, or supported user population.

A profile may define:

- Applicable standard and version,
- Required conformance level,
- Supported assistive technologies,
- Supported input methods,
- Display, scaling, and zoom expectations,
- Document-output requirements,
- Operational constraints,
- Evaluation frequency,
- Release-blocking criteria.

A profile may add requirements but must not weaken a binding obligation.

### Accessibility Assurance Artifact

Evidence supporting an accessibility assessment, such as:

- Automated scan output,
- Manual evaluation results,
- Keyboard test results,
- Screen-reader test records,
- Contrast measurements,
- Component test results,
- Document inspection results,
- User evaluation summaries,
- Remediation verification,
- Configuration records,
- Release acceptance records.

An artifact is not automatically proof that a component or deployment is conformant.

## Responsibility Model

### Platform Governance

Domain-neutral Platform governance should provide reusable mechanisms for:

- Governed standards and policy versions,
- Accessibility profiles,
- Common controls,
- Control implementations,
- Assurance artifacts,
- Assessments,
- Findings,
- Remediation,
- Exceptions,
- Risk treatment,
- Release evidence,
- Historical conformance records.

The existence of those structures does not establish interface accessibility.

### Shared User-Interface Components

A shared component library must define and test accessible behavior for reusable controls, including applicable:

- Buttons,
- Links,
- Menus,
- Dialogs,
- Alerts,
- Tabs,
- Tables,
- Forms,
- Date and time controls,
- Search controls,
- Navigation,
- Status indicators,
- Notifications,
- Maps,
- Charts,
- Authentication controls.

A component's accessibility does not guarantee that a page or workflow using it is accessible.

### Modules and Clients

Each module and client remains responsible for:

- Accessible role-specific workflows,
- Accurate labels and instructions,
- Meaningful focus order,
- Accessible validation,
- Equivalent representations,
- Domain-specific alerts,
- Accessible reports and documents,
- Module-specific testing,
- Degraded and recovery behavior.

### Deployment Owner

The deployment owner is responsible for:

- Identifying applicable obligations,
- Selecting supported configurations,
- Maintaining accessible content,
- Managing third-party dependencies,
- Providing reporting and accommodation channels,
- Reviewing unresolved findings,
- Approving authorized exceptions,
- Preserving assessment evidence,
- Ensuring continuing conformance after deployment.

### Content Authors

People who create or upload content must use supported accessible templates and authoring practices.

The Platform should prevent, detect, or clearly warn about common inaccessible content, including:

- Missing alternative text,
- Improper heading structure,
- Unlabeled tables,
- Images containing essential text,
- Uncaptioned media,
- Inaccessible document exports,
- Ambiguous link text,
- Missing language identification.

### External Providers

External providers are responsible for the accessibility of what they supply. A contract or provider relationship does not remove the deployment owner's responsibility to evaluate the actual integrated experience.

## Semantic Structure

Interfaces must use native semantics of the delivery technology where available.

The interface must expose programmatic information sufficient to determine applicable:

- Name,
- Role,
- State,
- Value,
- Relationships,
- Required status,
- Invalid status,
- Expanded or collapsed state,
- Selected state,
- Modal state,
- Live status changes.

Visual appearance must not substitute for semantic meaning.

Headings, landmarks, lists, tables, forms, labels, and navigation regions must use logical structure.

Custom controls should not be created where a standard accessible control can provide the required behavior.

## Keyboard and Alternate Input

All essential functionality must be operable through a keyboard interface except where the underlying function inherently requires path-dependent or analog input.

Keyboard users must be able to:

- Reach interactive controls,
- Determine which control has focus,
- Operate controls,
- Exit controls,
- Dismiss overlays and dialogs,
- Navigate repeated structures,
- Reach and understand errors,
- Complete and submit workflows,
- Recover from mistakes.

The interface must not create keyboard traps.

Keyboard order must follow a logical workflow and must not jump unpredictably between unrelated regions.

Mouse hover must not be the only way to reveal essential information or actions.

Gestures requiring multiple contact points, drawing, dragging, or precise movement must have an alternative unless the gesture is essential to the underlying activity.

Single-character shortcuts must be disabled, remappable, or active only within an appropriate focus context when unintended activation could occur.

## Focus Management

Keyboard focus must remain visible.

Opening a dialog, menu, alert, or workflow step must place focus predictably when moving focus is necessary. Closing temporary content must return focus to an appropriate initiating or contextual control.

Focus must not be lost because:

- Validation fails,
- A background refresh occurs,
- A record is updated,
- A table is sorted,
- A notification appears,
- A session warning is displayed,
- A component recovers.

Content updates must not move focus merely because new content exists.

Critical alerts may request or move focus only when required for safety or immediate action and when the behavior is documented and tested.

## Visual Presentation

Text and essential controls must remain usable under the contrast, zoom, text-spacing, reflow, orientation, and display-scaling expectations of the applicable profile.

Information must remain usable when:

- Text is enlarged,
- Browser or application zoom is increased,
- Display scaling is enabled,
- User-defined text spacing is applied,
- The viewport is narrow,
- A screen magnifier shows only part of the interface,
- High-contrast or forced-color mode is active.

Dense operational interfaces may require two-dimensional layouts. They must still provide usable focus, navigation, labels, magnification behavior, and alternative representations where required.

## Color and Contrast

Color must not be the sole means of identifying:

- Priority,
- Severity,
- Status,
- Availability,
- Validation result,
- Required fields,
- Selection,
- Warning,
- Success,
- Failure,
- Staleness,
- Authorization state,
- Classification,
- Emergency condition.

Text, icons, patterns, shapes, labels, and programmatic state should be combined as appropriate.

Text and meaningful controls must meet the contrast requirements of the applicable profile.

Focus indicators, control boundaries, chart elements, map symbols, and meaningful status indicators must remain distinguishable.

## Text, Language, and Comprehension

Interfaces should use direct, understandable language appropriate to the intended user and context.

The interface must:

- Identify the primary language where required,
- Identify language changes where required,
- Avoid unexplained abbreviations that may cause misunderstanding,
- Provide clear instructions,
- Use consistent control names,
- Explain consequences before destructive or high-impact actions,
- Distinguish warnings from informational messages,
- Avoid unnecessary cognitive load.

Plain language must not remove legally, medically, operationally, or technically necessary precision.

Where specialized terminology is necessary, the interface should provide contextual explanation or accessible help.

## Forms and Data Entry

Every form control must have an accessible name.

Instructions must identify applicable:

- Required values,
- Expected format,
- Constraints,
- Units,
- Date and time expectations,
- Validation requirements,
- Material consequences.

Placeholder text must not be the only label or instruction.

Required fields must not be identified by color alone.

Validation errors must:

- Identify the affected field or record,
- Explain the problem,
- Preserve previously valid input,
- Provide correction guidance where possible,
- Be programmatically associated with the affected control,
- Be reachable and understandable without relying on visual position alone.

For legal, financial, privacy-sensitive, security-sensitive, public-safety, or irreversible submissions, users must be able to review, correct, and confirm information where operationally appropriate.

## Tables and Repeated Data

Data tables must expose applicable:

- Table identity or description,
- Column headers,
- Row headers,
- Header relationships,
- Sort state,
- Selection state,
- Expanded state,
- Pagination or virtual-scroll state.

Keyboard and assistive-technology users must be able to navigate interactive tables without losing context.

Virtualized tables must preserve usable semantics and must not expose only the visible subset as though it were the complete dataset without communicating the limitation.

Bulk actions must identify:

- The number of affected records,
- The selection or selection rule,
- The action to be performed,
- Whether the action is reversible,
- Whether partial completion occurred.

## Dialogs and Temporary Content

Dialogs must:

- Have an accessible name,
- Identify their purpose,
- Manage focus predictably,
- Prevent unintended interaction with obscured content when modal,
- Provide an accessible closing method,
- Return focus appropriately.

Tooltips, popovers, menus, and hover or focus content must be dismissible and persistent long enough to be perceived where required.

Essential information must not exist only in a transient tooltip.

## Alerts, Notifications, and Status Changes

Alerts and status changes must provide an accessible representation appropriate to urgency.

A critical alert must not depend solely on:

- Sound,
- Color,
- Flashing,
- Vibration,
- Screen position,
- A transient banner.

Alerts may combine:

- Text,
- Severity labels,
- Icons,
- Sound,
- Vibration,
- Visual emphasis,
- Programmatic announcements.

High-frequency systems must prevent assistive technologies and users from being overwhelmed by constant low-value announcements.

The notification design must distinguish:

- New information,
- Changed information,
- Repeated information,
- Stale information,
- Acknowledged information,
- Cleared information.

Acknowledging an alert must not silently mean the underlying condition has been resolved.

## Maps, Charts, and Visualizations

Maps, charts, timelines, diagrams, and other visualizations must provide an alternative representation when the visualization carries essential information or functionality.

An alternative may include:

- A structured list,
- A data table,
- A textual summary,
- Searchable records,
- Keyboard-operable controls,
- Programmatic relationships,
- A nonvisual action path.

The alternative must preserve material meaning, timeliness, authorized actions, status, and privacy.

Map and chart state must not be communicated through color or visual position alone.

A failed or stale visualization must not appear as a valid empty result.

## Time Limits and Sessions

Users must be warned before a session, task, form, or authorization state expires when advance warning is operationally possible.

Where security and policy allow, users should be able to:

- Extend a time limit,
- Request additional time,
- Preserve entered data,
- Reauthenticate without losing safe work,
- Resume an interrupted process.

A security-based time limit must be justified by policy and must not be shortened merely to avoid accessible continuation behavior.

Strict operational time limits must be documented and tested with supported assistive technologies.

## Motion, Animation, and Flashing

The Platform must not use flashing content that exceeds applicable safety thresholds.

Motion and animation must not be required to understand critical information.

Nonessential animation should respect supported reduced-motion preferences.

Animation must not delay, obscure, or obstruct urgent work.

## Authentication and Security Controls

Security controls must be designed for accessible completion.

Authentication must not rely exclusively on:

- A biometric characteristic,
- Visual pattern recognition,
- Audio recognition,
- Fine motor movement,
- Memorization of a complex transient value,
- An inaccessible CAPTCHA,
- An inaccessible secondary-device interaction.

Where multiple methods provide equivalent assurance, an authorized accessible method should be available.

An accessibility alternative must not silently weaken:

- Authentication strength,
- Device binding,
- Session binding,
- Replay protection,
- Approval independence,
- Auditability,
- Attribution.

Authentication and session interfaces must provide accessible:

- Identity-provider selection,
- Credential entry,
- Multifactor prompts,
- Device-trust status,
- Step-up requests,
- Expiration warnings,
- Lock and revocation messages,
- Recovery instructions,
- Error messages.

Break-glass and emergency-access workflows must remain accessible.

## Shared Workstations and User Preferences

Accessibility preferences should follow the authenticated user where practical.

Preferences may include:

- Text size,
- Contrast or theme,
- Reduced motion,
- Notification presentation,
- Keyboard configuration,
- Panel arrangement,
- Announcement verbosity.

The Platform should store functional preferences without requiring disclosure of a disability or diagnosis.

Preferences must not override mandatory security, life-safety, privacy, or data-handling controls.

A shared workstation must not expose one user's:

- Preferences,
- Private information,
- Drafts,
- Search context,
- Notifications,
- Session state,

to another user.

## Mobile and Touch Interaction

Mobile applications must support the accessibility services of their supported operating systems.

Essential actions must not require:

- Precise touch,
- Multi-finger gestures without alternatives,
- Device motion without alternatives,
- A fixed orientation unless essential,
- Dragging without an alternative,
- Unnecessarily small or tightly packed targets.

Control names exposed to assistive technology must correspond to visible labels where visible labels exist.

Loss of connectivity must be communicated. Queued, unsent, synchronized, conflicting, rejected, and committed records must be distinguishable without relying only on color or icons.

## Documents and Generated Content

Accessibility requirements apply to content generated by the Platform.

Generated content must use accessible source structures before conversion.

Where applicable, generated documents must provide:

- A meaningful title,
- Identified language,
- Logical heading structure,
- Correct reading order,
- Tagged lists,
- Tagged tables with headers,
- Alternative text,
- Descriptive links,
- Accessible form controls,
- Bookmarks for long documents where appropriate,
- Sufficient contrast,
- Selectable and searchable text,
- Appropriate metadata.

A scanned image of text is not accessible merely because optical character recognition may interpret it.

Charts must provide material values or conclusions through an accessible table, summary, or equivalent representation.

Document templates must be versioned and governed. The Platform should retain the template and renderer version that produced material governed content.

## Media

Prerecorded synchronized media must provide required captions and alternatives.

Audio-only content must provide an equivalent transcript or text representation where required.

Video must not communicate critical instructions solely through visual action.

Captions must identify meaningful speakers and sounds when necessary for understanding.

Automatically generated captions must be reviewed when errors could materially alter meaning.

## Degraded, Offline, and Recovery Conditions

Accessible behavior must be evaluated during applicable:

- Slow network conditions,
- Intermittent connectivity,
- Offline operation,
- Failover,
- Read-only operation,
- Queued delivery,
- Partial outage,
- Authentication-provider outage,
- Map-provider outage,
- Notification-provider outage,
- Disaster recovery,
- Emergency operation.

A degraded interface must communicate:

- Which capability is degraded,
- Which information may be stale,
- Which actions remain available,
- Which actions are queued,
- Which actions failed,
- Whether retry is safe,
- How normal operation will be recognized.

An accessible primary interaction must not disappear merely because the Platform enters degraded mode.

Fallback interfaces, recovery consoles, emergency forms, and offline procedures must themselves be evaluated for accessibility.

## Privacy

Accessibility preferences must be treated as functional configuration and potentially sensitive by inference.

The Platform should not require storage of:

- Disability diagnoses,
- Medical history,
- Accommodation justification,
- Sensitive personal explanation.

Only the information necessary to provide the selected interaction should be stored.

Access, logging, analytics, export, and retention must be limited to operational need.

Telemetry must not identify or fingerprint an assistive-technology user unless collection is necessary, disclosed, authorized, and governed.

## External Components and Procurement

Third-party components must be evaluated in the context in which they are used.

Procurement and integration requirements should address:

- Applicable accessibility standard,
- Supported conformance level,
- Known limitations,
- Accessibility documentation,
- Testing rights,
- Defect-remediation obligations,
- Notification of material changes,
- Continued compatibility,
- Accessible support channels,
- Exit and replacement provisions.

A provider's accessibility claim must not be inherited without evaluating the actual integrated workflow, version, configuration, and deployment.

## Testing Model

### Automated Evaluation

Automated accessibility testing should cover applicable:

- Shared components,
- Representative pages,
- Critical workflows,
- Generated HTML,
- Supported viewports,
- Supported themes,
- Public interfaces,
- Administrative interfaces,
- Operational interfaces.

Passing automated tests does not establish conformance.

### Manual Evaluation

Manual evaluation must include applicable testing of:

- Keyboard-only operation,
- Focus order and visibility,
- Keyboard traps,
- Dialog behavior,
- Error recovery,
- Status announcements,
- Zoom and reflow,
- Text spacing,
- High-contrast or forced-color modes,
- Non-color-only meaning,
- Motion and flashing,
- Time limits,
- Alternative representations,
- Generated documents,
- Degraded operation.

### Assistive-Technology Evaluation

Accessibility profiles must define a representative test matrix containing applicable combinations of:

- Screen reader and browser or client,
- Screen magnifier and browser or client,
- Mobile screen reader and operating system,
- Voice or alternate input,
- Keyboard-only operation,
- High-contrast or forced-color presentation,
- Reduced-motion settings.

The architecture must not permanently bind to one vendor or version. Profiles should identify supported current or recent stable combinations.

### User Evaluation

Critical public and operational workflows should be evaluated with users with disabilities.

User evaluation complements but does not replace standards-based assessment.

Testing should use representative devices, displays, input methods, network conditions, lighting, noise, workflow pressure, and degraded conditions.

### Document Evaluation

Generated documents must be evaluated separately from the application that produces them.

### Regression Testing

A remediated defect should receive a regression test when the behavior can be tested reliably.

A shared-component defect or change requires evaluation of affected consuming workflows.

## Assessment and Assurance

An accessibility assessment must identify applicable:

- Scope,
- Component or deployment,
- Product and release version,
- Accessibility profile,
- Standard and version,
- Conformance level,
- Supported technologies,
- Test environment,
- Tools and procedures,
- Assistive technologies,
- Evaluators,
- Dates,
- Findings,
- Limitations,
- Exclusions,
- Retest results,
- Final determination.

Evidence must remain attributable to the tested version and configuration.

Stale evidence must not silently establish current conformance.

## Findings, Remediation, and Exceptions

Accessibility findings must be recorded with:

- Affected workflow,
- User impact,
- Severity,
- Applicable requirement,
- Reproduction information,
- Affected versions and configurations,
- Owner,
- Remediation plan,
- Target date,
- Verification result.

An exception must be:

- Authorized by the appropriate owner,
- Scoped,
- Justified,
- Time bounded,
- Reviewed,
- Linked to the underlying finding,
- Accompanied by an interim measure where practical.

An exception must not:

- Delete the finding,
- Change failed evidence into passing evidence,
- Falsely create a conformance claim,
- Rely solely on vendor assurance,
- Remain indefinitely active without review,
- Require unnecessary medical disclosure,
- Replace independent equivalent access with routine human assistance where independent access is required.

## Barrier Reporting

Supported deployments must provide an accessible method to report a barrier.

The reporting path must:

- Be discoverable,
- Be usable without the inaccessible function where possible,
- Accept sufficient context,
- Protect sensitive information,
- Provide acknowledgment,
- Support status tracking,
- Route urgent barriers appropriately.

Reports identifying a product or deployment defect must enter the governed finding process.

## Performance and Accessibility

Performance degradation can create accessibility barriers.

The Platform must consider:

- Delayed focus changes,
- Delayed or repeated announcements,
- Input loss,
- Focus loss during refresh,
- Timeouts caused by assistive-technology interaction,
- Excessive document-object complexity,
- Large virtualized tables,
- Slow alternative representations,
- Delayed captions or transcripts.

Critical accessibility paths must be included in performance profiles and workload testing.

## Release Acceptance

A release must not claim accessibility conformance without:

- Defined scope,
- Applicable standard and version,
- Tested release and configuration,
- Automated evaluation,
- Manual evaluation,
- Applicable assistive-technology evaluation,
- Applicable document evaluation,
- Recorded findings,
- Verified remediation,
- Governed unresolved limitations and exceptions,
- Retained assurance evidence.

The following claims are prohibited unless supported by an applicable assessment:

- "Fully accessible,"
- "ADA compliant,"
- "WCAG compliant,"
- "Meets all accessibility requirements,"
- "Certified accessible."

A partial assessment may be described only as partial.

Conformance can change when the product, content, provider, browser, operating system, assistive technology, template, or deployment configuration changes.

## Change Discipline

A material change affecting human interaction should update applicable:

1. Governing requirements,
2. Accessibility profile,
3. Interface or generated-content implementation,
4. Automated tests,
5. Manual procedures,
6. Assistive-technology coverage,
7. Assurance evidence,
8. Findings and remediation records,
9. User and administrator documentation,
10. Deployment requirements.

A shared-component change must identify dependent workflows requiring regression evaluation.

## Relationship to Client Experience

Accessibility and client experience are related but not interchangeable.

Performance, clarity, responsiveness, low-bandwidth behavior, state presentation, and degraded operation can materially affect accessibility. However:

- A responsive interface may still be inaccessible,
- An interface that passes selected accessibility checks may still be confusing,
- An accessible control does not guarantee an accessible workflow,
- A visually simple interface may still prevent independent operation.

The [Client Experience Model](client-experience-model.md) defines the shared role-centered experience contract. This document is the authoritative accessibility and inclusive-interaction contract.

## Final Principle

> **An interface is not complete when it merely displays the required information. It is complete only when supported people can perceive, understand, operate, and complete the required work with appropriate independence, safety, privacy, and assurance.**
