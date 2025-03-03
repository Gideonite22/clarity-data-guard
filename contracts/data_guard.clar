;; DataGuard - Decentralized Data Protection System

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-granted (err u101))
(define-constant err-no-permission (err u102))
(define-constant err-invalid-data (err u103))
(define-constant err-expired-access (err u104))
(define-constant err-max-grants-reached (err u105))
(define-constant err-invalid-principal (err u106))
(define-constant err-invalid-hash-length (err u107))
(define-constant err-rate-limit-exceeded (err u108))
(define-constant max-grants-per-user u10)
(define-constant rate-limit-window u144) ;; ~24 hours in blocks

;; Data Maps
(define-map data-store
    principal
    (list 200 {
        data-hash: (string-ascii 64),
        timestamp: uint
    })
)

(define-map access-permissions
    {owner: principal, accessor: principal}
    {
        granted: bool,
        timestamp: uint,
        expiry: (optional uint),
        emergency-revocable: bool
    }
)

(define-map access-history
    principal
    (list 200 {
        accessor: principal,
        data-hash: (string-ascii 64),
        timestamp: uint,
        action: (string-ascii 10)
    })
)

(define-map grant-counts
    principal
    uint
)

(define-map operation-counts
    {principal: principal, operation: (string-ascii 10)}
    {count: uint, window-start: uint}
)

;; Events
(define-data-var last-event-id uint u0)

;; Private Functions
(define-private (check-rate-limit (caller principal) (operation (string-ascii 10)) (limit uint))
    (let
        (
            (current-window (/ block-height rate-limit-window))
            (op-data (default-to
                {count: u0, window-start: u0}
                (map-get? operation-counts {principal: caller, operation: operation})))
        )
        (if (is-eq (/ (get window-start op-data) rate-limit-window) current-window)
            (if (< (get count op-data) limit)
                (begin
                    (map-set operation-counts
                        {principal: caller, operation: operation}
                        {count: (+ (get count op-data) u1), window-start: (get window-start op-data)})
                    true)
                false)
            (begin
                (map-set operation-counts
                    {principal: caller, operation: operation}
                    {count: u1, window-start: block-height})
                true))
    )
)

(define-private (validate-permission (permission {granted: bool, timestamp: uint, expiry: (optional uint), emergency-revocable: bool}))
    (match (get expiry permission)
        expiry-height (and
            (get granted permission)
            (>= expiry-height block-height))
        true
    )
)

;; Public Functions
(define-public (store-data (data-hash (string-ascii 64)))
    (begin
        (asserts! (check-rate-limit tx-sender "store" u10) (err err-rate-limit-exceeded))
        (asserts! (is-eq (len data-hash) u64) (err err-invalid-hash-length))
        (let
            (
                (existing-data (default-to (list ) (map-get? data-store tx-sender)))
            )
            (if (is-eq (len existing-data) u200)
                (err err-invalid-data)
                (begin
                    (map-set data-store
                        tx-sender
                        (append existing-data (list {
                            data-hash: data-hash,
                            timestamp: block-height
                        })))
                    (emit-event "store" tx-sender data-hash)
                    (ok true)
                )
            )
        )
    )
)

(define-public (delete-data (data-hash (string-ascii 64)))
    (begin
        (asserts! (check-rate-limit tx-sender "delete" u10) (err err-rate-limit-exceeded))
        (let
            (
                (existing-data (default-to (list ) (map-get? data-store tx-sender)))
                (filtered-data (filter not-data-hash existing-data))
            )
            (map-set data-store tx-sender filtered-data)
            (emit-event "delete" tx-sender data-hash)
            (ok true)
        )
    )
)

;; Include all existing functions with rate limiting...
