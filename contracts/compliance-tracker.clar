;; Compliance Tracker Contract
;; Manages international space law compliance and regulatory coordination

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-ENTITY-NOT-FOUND (err u501))
(define-constant ERR-REGULATION-NOT-FOUND (err u502))
(define-constant ERR-INVALID-PARAMETERS (err u503))
(define-constant ERR-COMPLIANCE-NOT-FOUND (err u504))
(define-constant ERR-VIOLATION-NOT-FOUND (err u505))
(define-constant ERR-INVALID-STATUS (err u506))

;; Data Variables
(define-data-var next-entity-id uint u1)
(define-data-var next-regulation-id uint u1)
(define-data-var next-violation-id uint u1)
(define-data-var next-audit-id uint u1)

;; Data Maps
(define-map registered-entities
  { entity-id: uint }
  {
    entity-name: (string-ascii 64),
    entity-type: (string-ascii 32),
    country-code: (string-ascii 3),
    registration-date: uint,
    primary-contact: principal,
    compliance-officer: principal,
    entity-status: (string-ascii 20),
    license-number: (string-ascii 32),
    expiry-date: uint
  }
)

(define-map regulatory-frameworks
  { regulation-id: uint }
  {
    regulation-name: (string-ascii 128),
    regulation-type: (string-ascii 32),
    issuing-authority: (string-ascii 64),
    effective-date: uint,
    compliance-deadline: uint,
    mandatory: bool,
    penalty-amount: uint,
    description: (string-ascii 256)
  }
)

(define-map compliance-records
  { entity-id: uint, regulation-id: uint }
  {
    compliance-status: (string-ascii 20),
    last-assessment: uint,
    next-review: uint,
    compliance-score: uint,
    documentation-complete: bool,
    assessor: principal,
    notes: (string-ascii 256)
  }
)

(define-map compliance-violations
  { violation-id: uint }
  {
    entity-id: uint,
    regulation-id: uint,
    violation-type: (string-ascii 32),
    severity-level: uint,
    discovery-date: uint,
    violation-description: (string-ascii 256),
    penalty-imposed: uint,
    remediation-deadline: uint,
    status: (string-ascii 20),
    resolved-date: uint
  }
)

(define-map compliance-audits
  { audit-id: uint }
  {
    entity-id: uint,
    audit-type: (string-ascii 32),
    auditor: principal,
    audit-date: uint,
    scope: (string-ascii 128),
    findings-count: uint,
    overall-score: uint,
    recommendations: (string-ascii 256),
    follow-up-required: bool,
    next-audit-date: uint
  }
)

(define-map certification-records
  { entity-id: uint, certification-type: (string-ascii 32) }
  {
    certification-name: (string-ascii 64),
    issuing-body: (string-ascii 64),
    issue-date: uint,
    expiry-date: uint,
    certification-level: (string-ascii 20),
    renewal-required: bool,
    status: (string-ascii 20)
  }
)

;; Public Functions

;; Register new entity
(define-public (register-entity
  (entity-name (string-ascii 64))
  (entity-type (string-ascii 32))
  (country-code (string-ascii 3))
  (compliance-officer principal)
  (license-number (string-ascii 32))
  (expiry-date uint))
  (let ((entity-id (var-get next-entity-id)))
    (asserts! (> (len entity-name) u0) ERR-INVALID-PARAMETERS)
    (asserts! (> (len license-number) u0) ERR-INVALID-PARAMETERS)
    (asserts! (> expiry-date block-height) ERR-INVALID-PARAMETERS)

    (map-set registered-entities
      { entity-id: entity-id }
      {
        entity-name: entity-name,
        entity-type: entity-type,
        country-code: country-code,
        registration-date: block-height,
        primary-contact: tx-sender,
        compliance-officer: compliance-officer,
        entity-status: "active",
        license-number: license-number,
        expiry-date: expiry-date
      }
    )

    (var-set next-entity-id (+ entity-id u1))
    (ok entity-id)
  )
)

;; Create regulatory framework
(define-public (create-regulatory-framework
  (regulation-name (string-ascii 128))
  (regulation-type (string-ascii 32))
  (issuing-authority (string-ascii 64))
  (effective-date uint)
  (compliance-deadline uint)
  (mandatory bool)
  (penalty-amount uint)
  (description (string-ascii 256)))
  (let ((regulation-id (var-get next-regulation-id)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> (len regulation-name) u0) ERR-INVALID-PARAMETERS)
    (asserts! (>= effective-date block-height) ERR-INVALID-PARAMETERS)
    (asserts! (> compliance-deadline effective-date) ERR-INVALID-PARAMETERS)

    (map-set regulatory-frameworks
      { regulation-id: regulation-id }
      {
        regulation-name: regulation-name,
        regulation-type: regulation-type,
        issuing-authority: issuing-authority,
        effective-date: effective-date,
        compliance-deadline: compliance-deadline,
        mandatory: mandatory,
        penalty-amount: penalty-amount,
        description: description
      }
    )

    (var-set next-regulation-id (+ regulation-id u1))
    (ok regulation-id)
  )
)

;; Update compliance status
(define-public (update-compliance-status
  (entity-id uint)
  (regulation-id uint)
  (compliance-status (string-ascii 20))
  (compliance-score uint)
  (documentation-complete bool)
  (notes (string-ascii 256)))
  (let ((entity (unwrap! (map-get? registered-entities { entity-id: entity-id }) ERR-ENTITY-NOT-FOUND))
        (regulation (unwrap! (map-get? regulatory-frameworks { regulation-id: regulation-id }) ERR-REGULATION-NOT-FOUND)))
    (asserts! (or (is-eq tx-sender (get compliance-officer entity))
                  (is-eq tx-sender CONTRACT-OWNER)) ERR-NOT-AUTHORIZED)
    (asserts! (<= compliance-score u100) ERR-INVALID-PARAMETERS)

    (map-set compliance-records
      { entity-id: entity-id, regulation-id: regulation-id }
      {
        compliance-status: compliance-status,
        last-assessment: block-height,
        next-review: (+ block-height u4320), ;; ~30 days
        compliance-score: compliance-score,
        documentation-complete: documentation-complete,
        assessor: tx-sender,
        notes: notes
      }
    )
    (ok true)
  )
)

;; Report compliance violation
(define-public (report-violation
  (entity-id uint)
  (regulation-id uint)
  (violation-type (string-ascii 32))
  (severity-level uint)
  (violation-description (string-ascii 256))
  (penalty-imposed uint)
  (remediation-deadline uint))
  (let ((violation-id (var-get next-violation-id))
        (entity (unwrap! (map-get? registered-entities { entity-id: entity-id }) ERR-ENTITY-NOT-FOUND))
        (regulation (unwrap! (map-get? regulatory-frameworks { regulation-id: regulation-id }) ERR-REGULATION-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= severity-level u10) ERR-INVALID-PARAMETERS)
    (asserts! (> remediation-deadline block-height) ERR-INVALID-PARAMETERS)

    (map-set compliance-violations
      { violation-id: violation-id }
      {
        entity-id: entity-id,
        regulation-id: regulation-id,
        violation-type: violation-type,
        severity-level: severity-level,
        discovery-date: block-height,
        violation-description: violation-description,
        penalty-imposed: penalty-imposed,
        remediation-deadline: remediation-deadline,
        status: "open",
        resolved-date: u0
      }
    )

    (var-set next-violation-id (+ violation-id u1))
    (ok violation-id)
  )
)

;; Conduct compliance audit
(define-public (conduct-compliance-audit
  (entity-id uint)
  (audit-type (string-ascii 32))
  (scope (string-ascii 128))
  (findings-count uint)
  (overall-score uint)
  (recommendations (string-ascii 256))
  (follow-up-required bool))
  (let ((audit-id (var-get next-audit-id))
        (entity (unwrap! (map-get? registered-entities { entity-id: entity-id }) ERR-ENTITY-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= overall-score u100) ERR-INVALID-PARAMETERS)

    (map-set compliance-audits
      { audit-id: audit-id }
      {
        entity-id: entity-id,
        audit-type: audit-type,
        auditor: tx-sender,
        audit-date: block-height,
        scope: scope,
        findings-count: findings-count,
        overall-score: overall-score,
        recommendations: recommendations,
        follow-up-required: follow-up-required,
        next-audit-date: (+ block-height (if follow-up-required u2160 u8640)) ;; 15 or 60 days
      }
    )

    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

;; Issue certification
(define-public (issue-certification
  (entity-id uint)
  (certification-type (string-ascii 32))
  (certification-name (string-ascii 64))
  (issuing-body (string-ascii 64))
  (expiry-date uint)
  (certification-level (string-ascii 20)))
  (let ((entity (unwrap! (map-get? registered-entities { entity-id: entity-id }) ERR-ENTITY-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> expiry-date block-height) ERR-INVALID-PARAMETERS)

    (map-set certification-records
      { entity-id: entity-id, certification-type: certification-type }
      {
        certification-name: certification-name,
        issuing-body: issuing-body,
        issue-date: block-height,
        expiry-date: expiry-date,
        certification-level: certification-level,
        renewal-required: (< (- expiry-date block-height) u4320), ;; renewal needed if < 30 days
        status: "active"
      }
    )
    (ok true)
  )
)

;; Resolve violation
(define-public (resolve-violation (violation-id uint))
  (let ((violation (unwrap! (map-get? compliance-violations { violation-id: violation-id }) ERR-VIOLATION-NOT-FOUND)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status violation) "open") ERR-INVALID-STATUS)

    (map-set compliance-violations
      { violation-id: violation-id }
      (merge violation {
        status: "resolved",
        resolved-date: block-height
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get registered entity
(define-read-only (get-registered-entity (entity-id uint))
  (map-get? registered-entities { entity-id: entity-id })
)

;; Get regulatory framework
(define-read-only (get-regulatory-framework (regulation-id uint))
  (map-get? regulatory-frameworks { regulation-id: regulation-id })
)

;; Get compliance record
(define-read-only (get-compliance-record (entity-id uint) (regulation-id uint))
  (map-get? compliance-records { entity-id: entity-id, regulation-id: regulation-id })
)

;; Get compliance violation
(define-read-only (get-compliance-violation (violation-id uint))
  (map-get? compliance-violations { violation-id: violation-id })
)

;; Get compliance audit
(define-read-only (get-compliance-audit (audit-id uint))
  (map-get? compliance-audits { audit-id: audit-id })
)

;; Get certification record
(define-read-only (get-certification-record (entity-id uint) (certification-type (string-ascii 32)))
  (map-get? certification-records { entity-id: entity-id, certification-type: certification-type })
)

;; Check entity compliance status
(define-read-only (check-entity-compliance (entity-id uint))
  (let ((entity (map-get? registered-entities { entity-id: entity-id })))
    (match entity
      entity-data (and (is-eq (get entity-status entity-data) "active")
                       (> (get expiry-date entity-data) block-height))
      false
    )
  )
)

;; Get entities requiring review
(define-read-only (get-entities-requiring-review)
  (filter needs-compliance-review (list
    u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
    u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
  ))
)

;; Get open violations
(define-read-only (get-open-violations)
  (filter is-open-violation (list
    u1 u2 u3 u4 u5 u6 u7 u8 u9 u10
    u11 u12 u13 u14 u15 u16 u17 u18 u19 u20
  ))
)

;; Get total registered entities
(define-read-only (get-total-entities)
  (- (var-get next-entity-id) u1)
)

;; Get total regulations
(define-read-only (get-total-regulations)
  (- (var-get next-regulation-id) u1)
)

;; Private Functions

;; Check if entity needs compliance review
(define-private (needs-compliance-review (entity-id uint))
  (match (map-get? registered-entities { entity-id: entity-id })
    entity (< (get expiry-date entity) (+ block-height u4320)) ;; expires within 30 days
    false
  )
)

;; Check if violation is open
(define-private (is-open-violation (violation-id uint))
  (match (map-get? compliance-violations { violation-id: violation-id })
    violation (is-eq (get status violation) "open")
    false
  )
)
