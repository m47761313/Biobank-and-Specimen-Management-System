;; Biobank Core Contract
;; Manages biological specimen collection, storage, and basic operations

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SPECIMEN-NOT-FOUND (err u101))
(define-constant ERR-SPECIMEN-ALREADY-EXISTS (err u102))
(define-constant ERR-INVALID-STATUS (err u103))
(define-constant ERR-INVALID-INPUT (err u104))

;; Data Variables
(define-data-var next-specimen-id uint u1)
(define-data-var biobank-name (string-ascii 100) "Default Biobank")
(define-data-var total-specimens uint u0)

;; Data Maps
(define-map specimens
  { specimen-id: uint }
  {
    donor-id: (string-ascii 50),
    specimen-type: (string-ascii 50),
    collection-date: uint,
    storage-location: (string-ascii 100),
    status: (string-ascii 20),
    collector: principal,
    volume-ml: uint,
    temperature-c: int,
    ph-level: uint,
    created-at: uint,
    updated-at: uint
  }
)

(define-map authorized-collectors principal bool)
(define-map specimen-metadata
  { specimen-id: uint }
  {
    collection-method: (string-ascii 100),
    processing-notes: (string-ascii 500),
    special-handling: (string-ascii 200),
    expiration-date: uint
  }
)

;; Authorization Functions
(define-public (add-authorized-collector (collector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-collectors collector true))
  )
)

(define-public (remove-authorized-collector (collector principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-collectors collector))
  )
)

;; Core Specimen Functions
(define-public (collect-specimen
  (donor-id (string-ascii 50))
  (specimen-type (string-ascii 50))
  (storage-location (string-ascii 100))
  (volume-ml uint)
  (temperature-c int)
  (ph-level uint)
  (collection-method (string-ascii 100))
  (processing-notes (string-ascii 500))
)
  (let
    (
      (specimen-id (var-get next-specimen-id))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len donor-id) u0) ERR-INVALID-INPUT)
    (asserts! (> (len specimen-type) u0) ERR-INVALID-INPUT)
    (asserts! (> volume-ml u0) ERR-INVALID-INPUT)
    (asserts! (and (>= temperature-c -80) (<= temperature-c 37)) ERR-INVALID-INPUT)
    (asserts! (<= ph-level u14) ERR-INVALID-INPUT)

    (map-set specimens
      { specimen-id: specimen-id }
      {
        donor-id: donor-id,
        specimen-type: specimen-type,
        collection-date: current-time,
        storage-location: storage-location,
        status: "collected",
        collector: tx-sender,
        volume-ml: volume-ml,
        temperature-c: temperature-c,
        ph-level: ph-level,
        created-at: current-time,
        updated-at: current-time
      }
    )

    (map-set specimen-metadata
      { specimen-id: specimen-id }
      {
        collection-method: collection-method,
        processing-notes: processing-notes,
        special-handling: "",
        expiration-date: (+ current-time u31536000) ;; 1 year from collection
      }
    )

    (var-set next-specimen-id (+ specimen-id u1))
    (var-set total-specimens (+ (var-get total-specimens) u1))
    (ok specimen-id)
  )
)

(define-public (update-specimen-status (specimen-id uint) (new-status (string-ascii 20)))
  (let
    (
      (specimen (unwrap! (map-get? specimens { specimen-id: specimen-id }) ERR-SPECIMEN-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (or
      (is-eq new-status "collected")
      (is-eq new-status "processed")
      (is-eq new-status "stored")
      (is-eq new-status "allocated")
      (is-eq new-status "consumed")
      (is-eq new-status "disposed")
    ) ERR-INVALID-STATUS)

    (ok (map-set specimens
      { specimen-id: specimen-id }
      (merge specimen { status: new-status, updated-at: current-time })
    ))
  )
)

(define-public (update-storage-location (specimen-id uint) (new-location (string-ascii 100)))
  (let
    (
      (specimen (unwrap! (map-get? specimens { specimen-id: specimen-id }) ERR-SPECIMEN-NOT-FOUND))
      (current-time (unwrap-panic (get-block-info? time (- block-height u1))))
    )
    (asserts! (default-to false (map-get? authorized-collectors tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (> (len new-location) u0) ERR-INVALID-INPUT)

    (ok (map-set specimens
      { specimen-id: specimen-id }
      (merge specimen { storage-location: new-location, updated-at: current-time })
    ))
  )
)

;; Read-only Functions
(define-read-only (get-specimen (specimen-id uint))
  (map-get? specimens { specimen-id: specimen-id })
)

(define-read-only (get-specimen-metadata (specimen-id uint))
  (map-get? specimen-metadata { specimen-id: specimen-id })
)

(define-read-only (get-total-specimens)
  (var-get total-specimens)
)

(define-read-only (get-biobank-info)
  {
    name: (var-get biobank-name),
    total-specimens: (var-get total-specimens),
    next-id: (var-get next-specimen-id)
  }
)

(define-read-only (is-authorized-collector (collector principal))
  (default-to false (map-get? authorized-collectors collector))
)
