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
(define-constant max-grants-per-user u10)

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

;; Events
(define-data-var last-event-id uint u0)

(define-public (store-data (data-hash (string-ascii 64)))
    (begin
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
                        }))
                    )
                    (emit-event "store" tx-sender data-hash)
                    (ok true)
                )
            )
        )
    )
)

;; Grant access with emergency revocation option
(define-public (grant-access-with-expiry (to principal) (expiry (optional uint)) (emergency-revocable bool))
    (begin
        (asserts! (not (is-eq to tx-sender)) (err err-invalid-principal))
        (let
            (
                (permission-key {owner: tx-sender, accessor: to})
                (current-permission (map-get? access-permissions permission-key))
                (current-grants (default-to u0 (map-get? grant-counts tx-sender)))
            )
            (asserts! (is-none current-permission) (err err-already-granted))
            (asserts! (< current-grants max-grants-per-user) (err err-max-grants-reached))
            (begin
                (map-set access-permissions
                    permission-key
                    {
                        granted: true,
                        timestamp: block-height,
                        expiry: expiry,
                        emergency-revocable: emergency-revocable
                    }
                )
                (map-set grant-counts tx-sender (+ current-grants u1))
                (add-access-history tx-sender to "" "GRANT")
                (emit-event "grant" tx-sender to)
                (ok true)
            )
        )
    )
)

;; Emergency revocation (only for emergency-revocable permissions)
(define-public (emergency-revoke (owner principal) (from principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err err-not-authorized))
        (let
            (
                (permission-key {owner: owner, accessor: from})
                (permission (unwrap! (map-get? access-permissions permission-key) (err err-no-permission)))
            )
            (asserts! (get emergency-revocable permission) (err err-not-authorized))
            (map-delete access-permissions permission-key)
            (map-set grant-counts owner (- (default-to u0 (map-get? grant-counts owner)) u1))
            (add-access-history owner from "" "EMERGENCY")
            (emit-event "emergency-revoke" owner from)
            (ok true)
        )
    )
)

;; Private helper functions
(define-private (emit-event (event-type (string-ascii 20)) (subject principal) (target (optional principal)))
    (begin
        (var-set last-event-id (+ (var-get last-event-id) u1))
        (print {
            event-id: (var-get last-event-id),
            event-type: event-type,
            subject: subject,
            target: target,
            timestamp: block-height
        })
    )
)

;; Include all existing functions...
