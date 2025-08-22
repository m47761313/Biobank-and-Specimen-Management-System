;; Compliance Tracker Contract
;; Manages regulatory compliance and audit trails

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-EVENT-NOT-FOUND (err u501))
(define-constant ERR-INVALID-COMPLIANCE-SCORE (err u502))
(define-constant ERR-INVALID-INPUT (err u503))

;; Data Variables
(define-data-var next-event-id uint u1)
(define-data-var total-compliance-events uint u0)
(define-data-var compliance-violations uint u0)
(define-data-var overall-compliance-score uint u100)

;; Data Maps
(define-map compliance-events
  { event-id: uint }
  {
    event-type: (string-ascii 50),
    description: (string-ascii 300),
    compliance-score: uint,
    severity: (string-ascii 20),
    affected-specimens: (list 10 uint),
    reported-by: principal,
    event-date: uint,
    resolution-status: (string-ascii 20),
    resolution-date: uint,
    resolution-notes: (string-ascii 300),
    created-at: uint,
    updated-at: uint
  }
)

(define-map audit-logs
  { specimen-id: uint }
  (list 50 {
    action: (string-ascii 50),
    actor: principal,
    timestamp: uint,
    details: (string-ascii 200),
    compliance-impact: (string-ascii 100)
  })
)

(define-map authorized-compliance-officers principal bool)
(define-map regulatory-requirements
  { requirement-id: (string-ascii 50) }
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    compliance-threshold: uint,
    last-audit-date: uint,
    next-audit-due: uint,
    status: (string-ascii 20)
  }
)

;; Authorization Functions
(define-public (add-compliance-officer (officer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-compliance-officers officer true))
  )
)

;; Core Compliance Functions
(define-public (record-compliance-event
  (event-type (string-ascii 50))
  (description (string-ascii 300))
  (compliance-score uint)
  (severity (string-ascii 20))
  (affected-specimens (list 10 uint))
)
  (let
    (
      (event-id (var-get next-event-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (default-to false (map-get? authorized-compliance-officers tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len event-type) u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (<= compliance-score u100) ERR-INVALID-COMPLIANCE-SCORE)
    (asserts! (or
      (is-eq severity "low")
      (is-eq severity "medium")
      (is-eq severity "high")
      (is-eq severity "critical")
    ) ERR-INVALID-INPUT)

    (map-set compliance-events
      { event-id: event-id }
      {
        event-type: event-type,
        description: description,
        compliance-score: compliance-score,
        severity: severity,
        affected-specimens: affected-specimens,
        reported-by: tx-sender,
        event-date: current-time,
        resolution-status: "open",
        resolution-date: u0,
        resolution-notes: "",
        created-at: current-time,
        updated-at: current-time
      }
    )

    ;; Update audit logs for affected specimens
    (fold add-compliance-audit-entry affected-specimens { event-id: event-id, current-time: current-time })

    (if (< compliance-score u70)
      (var-set compliance-violations (+ (var-get compliance-violations) u1))
      true
    )

    (var-set next-event-id (+ event-id u1))
    (var-set total-compliance-events (+ (var-get total-compliance-events) u1))
    (update-overall-compliance-score)
    (ok event-id)
  )
)

(define-private (add-compliance-audit-entry (specimen-id uint) (context { event-id: uint, current-time: uint }))
  (let
    (
      (existing-log (default-to (list) (map-get? audit-logs { specimen-id: specimen-id })))
      (new-entry {
        action: "compliance-event",
        actor: tx-sender,
        timestamp: (get current-time context),
        details: (unwrap-panic (as-max-len? (concat "Event ID: " (int-to-ascii (to-int (get event-id context)))) u200)),
        compliance-impact: "recorded"
      })
    )
    (map-set audit-logs
      { specimen-id: specimen-id }
      (unwrap-panic (as-max-len? (append existing-log new-entry) u50))
    )
    context
  )
)

(define-public (resolve-compliance-event (event-id uint) (resolution-notes (string-ascii 300)))
  (let
    (
      (event (unwrap! (map-get? compliance-events { event-id: event-id }) ERR-EVENT-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (default-to false (map-get? authorized-compliance-officers tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get resolution-status event) "open") ERR-INVALID-INPUT)
    (asserts! (> (len resolution-notes) u0) ERR-INVALID-INPUT)

    (ok (map-set compliance-events
      { event-id: event-id }
      (merge event {
        resolution-status: "resolved",
        resolution-date: current-time,
        resolution-notes: resolution-notes,
        updated-at: current-time
      })
    ))
  )
)

(define-public (add-regulatory-requirement
  (requirement-id (string-ascii 50))
  (title (string-ascii 100))
  (description (string-ascii 300))
  (compliance-threshold uint)
  (next-audit-due uint)
)
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (default-to false (map-get? authorized-compliance-officers tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len requirement-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (len title) u0) ERR-INVALID-INPUT)
    (asserts! (<= compliance-threshold u100) ERR-INVALID-COMPLIANCE-SCORE)
    (asserts! (> next-audit-due current-time) ERR-INVALID-INPUT)

    (ok (map-set regulatory-requirements
      { requirement-id: requirement-id }
      {
        title: title,
        description: description,
        compliance-threshold: compliance-threshold,
        last-audit-date: u0,
        next-audit-due: next-audit-due,
        status: "active"
      }
    ))
  )
)

(define-public (log-specimen-action
  (specimen-id uint)
  (action (string-ascii 50))
  (details (string-ascii 200))
  (compliance-impact (string-ascii 100))
)
  (let
    (
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
      (existing-log (default-to (list) (map-get? audit-logs { specimen-id: specimen-id })))
      (new-entry {
        action: action,
        actor: tx-sender,
        timestamp: current-time,
        details: details,
        compliance-impact: compliance-impact
      })
    )
    (asserts! (> specimen-id u0) ERR-INVALID-INPUT)
    (asserts! (> (len action) u0) ERR-INVALID-INPUT)

    (ok (map-set audit-logs
      { specimen-id: specimen-id }
      (unwrap-panic (as-max-len? (append existing-log new-entry) u50))
    ))
  )
)

;; Compliance Analysis Functions
(define-private (update-overall-compliance-score)
  (let
    (
      (total-events (var-get total-compliance-events))
      (violations (var-get compliance-violations))
    )
    (if (> total-events u0)
      (var-set overall-compliance-score (- u100 (/ (* violations u100) total-events)))
      (var-set overall-compliance-score u100)
    )
  )
)

;; Read-only Functions
(define-read-only (get-compliance-event (event-id uint))
  (map-get? compliance-events { event-id: event-id })
)

(define-read-only (get-audit-log (specimen-id uint))
  (map-get? audit-logs { specimen-id: specimen-id })
)

(define-read-only (get-regulatory-requirement (requirement-id (string-ascii 50)))
  (map-get? regulatory-requirements { requirement-id: requirement-id })
)

(define-read-only (get-compliance-stats)
  {
    total-events: (var-get total-compliance-events),
    violations: (var-get compliance-violations),
    overall-score: (var-get overall-compliance-score),
    violation-rate: (if (> (var-get total-compliance-events) u0)
      (/ (* (var-get compliance-violations) u100) (var-get total-compliance-events))
      u0
    )
  }
)

(define-read-only (is-compliance-officer (officer principal))
  (default-to false (map-get? authorized-compliance-officers officer))
)
