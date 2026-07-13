# CAD Client Experience Model

> **Document status:** Normative CAD user-interface architecture.
>
> **Implementation status:** Each applicable CAD interface, client, workstation surface, mobile client, and generated-content implementation must apply and validate these principles within its own role and operating context.

## Purpose

Define the shared experience requirements for human-facing CAD interfaces.

The interface must help a person perform an authorized role safely, efficiently, accurately, and with as little unnecessary friction as practical.

The interface is not the user's job. It is a tool used to perform the job.

## Governing Statement

> **A user interface must complement the user's role and workflow. It must not get in the way of completing authorized work.**

A successful interface becomes predictable enough that the user can focus on:

- The information being evaluated,
- The caller, responder, agency, or community being served,
- The decision that must be made,
- The condition being managed,
- The responsibility being fulfilled,
- The outcome that must be reached,

rather than focusing on the mechanics, internal structure, or limitations of the software.

## Scope

This model applies to human-facing CAD capabilities, including:

- Call-taker and dispatcher workspaces,
- Supervisor workspaces,
- Field and mobile CAD clients,
- CAD administrative and configuration applications,
- Shared dispatch terminals,
- Authentication, session, lock, and handoff interfaces,
- Dashboards, maps, queues, tables, timelines, alerts, and visualizations,
- Reports, forms, notices, messages, and generated documents,
- Support, recovery, installation, and maintenance tools,
- Third-party interfaces presented as part of a CAD workflow.

Machine-to-machine APIs are not user interfaces. Their documentation, administrative clients, error presentation, and generated outputs are within scope when people use them.

## Role-Centered Design

Interfaces must be designed around the responsibilities, knowledge, environment, urgency, and constraints of the people who use them.

An interface should present:

- Information relevant to the current responsibility,
- Actions appropriate to the user's authorized role,
- Necessary context at the point of use,
- A clear path through common work,
- Status and consequences that can be understood without guesswork,
- Recovery guidance when normal work cannot continue.

A role should not be forced to navigate unrelated capabilities merely because those capabilities exist elsewhere in the Platform.

The interface should use the language of the supported role where that language is necessary and understood. It should not expose internal database names, service names, implementation details, provider terminology, or protocol mechanics unless the user is performing an administrative or technical role that requires them.

### Authorization Boundary

Role-centered presentation does not grant authority.

The appearance of a button, menu item, keyboard command, route, panel, or workstation component does not establish that an action is allowed. Protected actions remain subject to Platform identity, session, device, scope, purpose, policy, applicable Approval Request and Approval Action continuity, authorization, and audit requirements.

The interface may:

- Hide clearly inapplicable actions,
- Explain why an action is unavailable,
- Guide the user through required Foundation Approval Request participation or session step-up processes,
- Prevent accidental submission of incomplete work.

The interface must not:

- Treat hidden controls as a security boundary,
- Perform a protected action only because the client believes it is allowed,
- Represent a local assumption as a server-authoritative decision,
- Bypass policy to reduce user friction.


### Approval and Authorization Vocabulary

The interface must distinguish:

- Approval Action Record recorded.
- Approval stage satisfied.
- Approval Request finalized.
- Authorization Decision allowed or denied.
- Authorization Lease current or invalid.
- CAD operation committed.
- External delivery acknowledged.

A generic `Approved` label must not be used where it could hide which state actually exists. A retryable serialization or deadlock result must not be presented as a policy denial.

## Preserve Attention

User attention is a limited operational resource.

The interface must avoid competing with the work through unnecessary:

- Alerts,
- Notifications,
- Animation,
- Pop-ups,
- Color changes,
- Sound,
- Repeated confirmation,
- Navigation,
- Status messages,
- Visual density without hierarchy.

Information should be prioritized according to relevance, urgency, age, consequence, and required action.

Urgent information must be distinguishable from routine information. Routine information must not be presented with the same prominence as a condition requiring immediate action.

CAD interfaces should avoid alerting the user merely because an internal event occurred. A notification should normally exist because the user must know, decide, acknowledge, investigate, or act.

Acknowledgment of an alert must not silently mean that the underlying condition has been resolved.

## Preserve Context

The interface should preserve useful working context across:

- Navigation,
- Related workflows,
- Temporary interruptions,
- Safe retries,
- Reauthentication,
- Supported session continuation,
- Workstation-component recovery,
- Display or layout changes,
- Degraded and resynchronizing conditions.

Context may include:

- The selected record or work item,
- Current position in a workflow,
- Valid entered data,
- Search and filter state,
- User-selected views,
- Draft work,
- Accessibility and interaction preferences,
- The reason a warning, Foundation Approval Request, or session step-up was required.

Context preservation must not:

- Expose one user's information to another user,
- Preserve authority after it has expired or been revoked,
- Present stale information as current,
- Present a draft as committed,
- Reissue a protected action without a valid authorization decision,
- Conceal that recovery altered or discarded part of the user's work.

When context cannot be preserved, the interface must explain what was lost, what remains valid, and what the user must do next.

## Reduce Unnecessary Work

The Platform should automate, prepopulate, correlate, or simplify work when doing so is safe, understandable, attributable, and governed.

The interface should not require a user to:

- Re-enter information the Platform already possesses and can safely reuse,
- Memorize internal identifiers without an operational reason,
- Understand internal service or database boundaries,
- Repeat completed steps without a valid reason,
- Manually reconcile information that the Platform can safely correlate,
- Dismiss recurring messages that require no decision,
- Search multiple unrelated screens for information needed by one workflow,
- Reconstruct the meaning of an unexplained status or code,
- Restart an entire application to recover one failed capability when narrower recovery is possible.

Automation must remain understandable. The user must be able to determine:

- What the Platform did,
- Which information it used,
- What remains pending,
- What requires human judgment,
- Whether the result is authoritative,
- How to correct or challenge an incorrect result.

## Workflow Design

Common workflows should have a direct, understandable path.

The interface should:

- Present prerequisites before they prevent completion,
- Group related information and actions,
- Keep high-frequency actions readily available,
- Avoid unnecessary mode changes,
- Preserve valid input after validation failures,
- Permit review before high-consequence commitment,
- Provide safe cancellation where cancellation is supported,
- Clearly identify the point at which an action becomes committed or irreversible.

The shortest workflow is not always the safest workflow. Additional steps are justified when they provide necessary:

- Verification,
- An independent Foundation Approval Request and eligible Approval Action when policy requires it,
- Identity proof,
- Safety confirmation,
- Legal acknowledgment,
- Conflict resolution,
- Protection against irreversible harm.

Additional steps must not exist merely because the implementation is fragmented or the underlying data model is inconvenient.

## Information Hierarchy

The interface must make important information discoverable without making everything appear equally important.

Presentation should distinguish:

- Primary work from supporting context,
- Current conditions from historical information,
- Confirmed facts from estimates or inferences,
- Authoritative state from local or cached state,
- Required actions from optional actions,
- Warnings from informational messages,
- Security denials from technical failures,
- New information from repeated information.

The interface must not rely solely on position, color, size, iconography, sound, animation, or visual style to communicate critical meaning.

Dense interfaces may be necessary for some roles. Density must be intentional, structured, and testable. High density does not justify unpredictable navigation, hidden status, unreadable text, inaccessible interaction, or indiscriminate alerts.

## Clear State

The interface must clearly communicate the state and freshness of information.

Where applicable, the interface must distinguish conditions such as:

- Current,
- Delayed,
- Stale,
- Cached,
- Resynchronizing,
- Partially available,
- Unavailable,
- Unknown.

A component must not appear normally operational when it is failed, disconnected, stale, or recovering.

A blank, frozen, or partially rendered region must not be allowed to resemble a valid empty result.

The user should be able to determine:

- When the information was last confirmed,
- Whether the source is available,
- Whether displayed data may be incomplete,
- Whether the Platform is attempting recovery,
- Whether another method of work is required.

## Clear Action Outcomes

Information state and action-delivery state are related but not interchangeable.

Where applicable, the interface must distinguish action states such as:

- Draft,
- Pending,
- Queued,
- Transmitting,
- Committed,
- Rejected,
- Conflicted,
- Cancelled,
- Outcome unknown.

The interface must not:

- Present a submitted action as committed before authoritative confirmation,
- Present an uncertain result as definite success or failure,
- Encourage an unsafe retry when the original action may already have committed,
- Lose a pending action without informing the user,
- Represent local persistence as server acceptance.

When the outcome is unknown, the interface must say so plainly and provide a safe recovery path.

## Understandable Actions

Controls must use language meaningful to the intended user and appropriate to the role.

The interface should make clear:

- What action will occur,
- What information or people will be affected,
- Whether the action is reversible,
- Whether a Foundation Approval Request, independent Approval Action, session step-up, or other proof is required,
- Whether the action has completed,
- What the user should do when it does not complete.

Destructive, irreversible, security-sensitive, privacy-sensitive, or high-consequence actions require protection appropriate to their risk.

Confirmation must be meaningful. Repeated confirmation for ordinary low-risk actions trains users to approve prompts without evaluating them.

Where a confirmation is required, it should identify the actual consequence rather than using a generic question such as "Are you sure?"

## Data Entry and Review

Data-entry interfaces should:

- Use clear labels and instructions,
- Identify required information,
- Explain format and units,
- Provide suitable defaults without concealing assumptions,
- Validate as early as practical without interrupting entry unnecessarily,
- Preserve valid information after an error,
- Associate errors with the affected field or record,
- Support review and correction before material commitment,
- Prevent duplicate submission where practical,
- Distinguish local draft storage from authoritative submission.

The interface should not use placeholder text as the only label or instruction.

For legal, financial, privacy-sensitive, security-sensitive, public-safety, or otherwise irreversible submissions, the user must be able to review and correct material information where operationally appropriate.

## Responsiveness and Feedback

The interface must acknowledge user input promptly and provide visible progress for work that cannot complete immediately.

A user must not be left uncertain whether:

- Input was received,
- An action is processing,
- The system is waiting for another dependency,
- Work is queued,
- Work completed,
- Recovery is occurring,
- Additional action is required.

Visual responsiveness must not be achieved by falsely presenting incomplete work as complete.

Role-specific implementations must define measurable response budgets for critical workflows. Terms such as "fast," "responsive," or "within a few seconds" are not sufficient acceptance criteria without a defined measurement method and workload.

Performance must be evaluated under representative:

- Data volumes,
- Concurrent activity,
- Display configurations,
- Input methods,
- Network conditions,
- Assistive technologies,
- Degraded conditions,
- Hardware profiles.

## Error Behavior

An error message must help the user understand the operational situation.

Where safe and applicable, it should state:

- What failed,
- What remains available,
- Whether entered or submitted information was preserved,
- Whether the action may already have completed,
- Whether retry is safe,
- Whether recovery is automatic,
- What the user should do next,
- How support can correlate the problem.

Errors must not expose secrets, sensitive data, internal security details, stack traces, or implementation details unnecessarily.

The interface must not blame the user for conditions caused by the Platform, infrastructure, integration, provider, or deployment.

Technical support identifiers should be copyable and attributable without requiring the user to transcribe a long opaque code manually.

## Degraded Operation

When a service, workstation component, integration, network path, or data source is degraded, the interface must clearly communicate:

- What is affected,
- What remains available,
- The freshness of displayed information,
- Which actions remain safe,
- Which actions are unavailable,
- Which actions are queued,
- Whether recovery is automatic,
- Whether an alternate procedure is required.

A degraded condition must not unnecessarily prevent unrelated work.

The interface must not conceal degradation in order to appear available.

Fallback, offline, recovery, and alternate procedures are user interfaces and must meet the same principles where applicable.

## Recovery and Continuation

The Platform should favor safe, bounded recovery over forcing the user to repeat an entire workflow or restart an entire client.

Where appropriate, users should be able to:

- Correct mistakes before commitment,
- Cancel safely cancellable operations,
- Return to a known state,
- Resume preserved work,
- Reauthenticate without losing safe draft state,
- Understand what recovery restored,
- Understand what recovery could not restore,
- Obtain support without losing relevant diagnostic context.

Recovery must not silently replay an operation whose prior result is uncertain.

## Consistency and Predictability

Equivalent concepts should behave predictably across CAD interfaces.

Shared terminology, status representation, interaction patterns, controls, keyboard behavior, and error language should remain consistent when the underlying meaning is the same.

Consistency must not force unrelated roles into one unsuitable interface.

A call taker, dispatcher, supervisor, responder, CAD administrator, and support engineer may require different presentations even when they consume shared Platform services.

Consistency means equivalent meaning is expressed predictably. It does not mean every person receives the same screen.

## Personalization

Personalization may improve effectiveness when it remains governed and safe.

Supported preferences may include:

- Text size,
- Contrast or theme,
- Reduced motion,
- Notification presentation,
- Keyboard configuration,
- Panel arrangement,
- Density,
- Language,
- Time and date presentation.

Preferences must not:

- Grant authority,
- Suppress mandatory warnings without a controlled policy exception and current Authorization Decision,
- Expose one user's private information to another,
- Change the meaning of committed records,
- Conceal required information,
- Weaken security controls,
- Make a supported workflow inaccessible.

## Accessibility and Independent Operation

Interfaces must support accessible, inclusive, understandable, and independently operable interaction.

Accessibility is part of functional correctness and must be considered throughout design, implementation, testing, deployment, and maintenance.

Detailed requirements are defined in:

- [Accessibility and Inclusive Interaction Model](accessibility-and-inclusive-interaction-model.md)

An interface is not successful when an authorized person cannot independently perform the role because of an avoidable interaction barrier.

## Security Without Needless Friction

Security controls must protect the Platform without transferring avoidable complexity to the user.

The interface should:

- Explain security requirements in understandable terms,
- Request additional proof only when required,
- Preserve safe work during reauthentication where practical,
- Distinguish denied authority from technical failure,
- Explain Foundation Approval Request, Approval Action, or session step-up requirements without revealing protected policy details,
- Prevent accidental high-consequence actions,
- Avoid repeated prompts that provide no additional assurance.

Security must not be weakened merely to improve convenience.

Usability problems in security workflows must be treated as design problems rather than accepted as unavoidable.

## Privacy and Data Minimization

The interface should display and collect only the information necessary for the supported work and authorized context.

It must consider:

- Shoulder viewing,
- Shared displays,
- Screen sharing,
- Notifications appearing outside the active context,
- Clipboard use,
- Browser or client history,
- Local drafts and caches,
- Print and export,
- Session handoff,
- Support access,
- Diagnostic capture.

Privacy controls must not make the interface misleading. Redacted, masked, unavailable, or restricted information must be represented honestly.

## Technology Neutrality

This model does not require a specific implementation technology.

The same experience requirements apply whether the interface uses:

- Native controls,
- Web technology,
- Embedded rendering,
- Mobile frameworks,
- Terminal interaction,
- Generated documents,
- Assistive technology,
- Third-party components.

Technology choice is acceptable only when the resulting interface can meet the applicable role, accessibility, security, performance, reliability, deployment, and support requirements.

## Validation

Interface quality must be evaluated by observing whether people can successfully perform their responsibilities.

Validation should include applicable evaluation of:

- Task completion,
- Accuracy,
- Time and effort,
- Error frequency,
- Recovery from mistakes,
- Understanding of state and outcome,
- Alert and interruption burden,
- Accessibility,
- Performance,
- Degraded operation,
- Privacy,
- Security workflows,
- User confidence in the represented result.

Visual appearance alone does not establish that an interface is usable.

A feature is not complete merely because its controls render successfully or its happy-path automated test passes.

### Representative Conditions

Testing should use representative:

- Roles,
- Permissions,
- Workloads,
- Data volumes,
- Devices,
- Displays,
- Input methods,
- Assistive technologies,
- Network conditions,
- Interruptions,
- Failure conditions,
- Recovery conditions,
- Time pressure where appropriate.

### Release Acceptance

A release containing material interface changes should not be accepted until the responsible owner has retained evaluation results demonstrating that:

- Critical workflows remain completable,
- State and outcomes are represented accurately,
- Accessibility requirements are met or governed findings exist,
- Performance budgets are met,
- Failure and recovery behavior is understandable,
- Security decisions remain server-authoritative,
- Known limitations are documented,
- Regression testing covers affected shared components and workflows.

## Responsibility

Shared interface components are responsible for consistent, secure, and accessible interaction behavior within their defined scope.

CAD client and workstation implementations remain responsible for:

- Role-specific workflow design,
- Domain terminology,
- Information priority,
- Operational validation,
- Performance,
- Error handling,
- Degraded behavior,
- Accessibility,
- User evaluation,
- Release acceptance.

Platform governance may record standards, controls, assessments, findings, remediation, exceptions, risk, and Assurance Artifacts. Those records do not independently prove that an interface is effective, usable, accessible, or appropriate for its role.

## Change Discipline

A material change to human interaction should identify:

- The roles and workflows affected,
- The reason for the change,
- Changed state or outcome representation,
- Changed keyboard or assistive-technology behavior,
- Changed performance or degraded-operation behavior,
- Required regression testing,
- Updated help or training,
- Known limitations,
- Release Assurance Artifacts.

A shared-component change must identify consuming workflows that require regression evaluation.

## Non-Goals

This model does not:

- Define a universal screen layout,
- Require every role to use the same workflow,
- Select a frontend framework,
- Define workstation process isolation,
- Define local IPC or workstation-component supervision,
- Replace domain-specific workflow architecture,
- Replace accessibility evaluation,
- Treat interface visibility as authorization,
- Guarantee that automation is correct merely because it reduces effort.

## Final Principle

> **The best interface is not the one with the most visible functionality. It is the one that allows an authorized person to understand the situation, complete the required work, recognize the result, and continue without unnecessary interference from the software.**
