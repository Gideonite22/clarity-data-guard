;; DataGuard - Decentralized Data Protection System

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-granted (err u101))
(define-constant err-no-permission (err u102))
(define-constant err-invalid-data (err u103))
(define-constant err-expired-access (err u104))

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
        expiry: (optional uint)
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

;; Public Functions

;; Store encrypted data reference
(define-public (store-data (data-hash (string-ascii 64)))
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
                (ok true)
            )
        )
    )
)

;; Grant access to a principal with optional expiry
(define-public (grant-access-with-expiry (to principal) (expiry (optional uint)))
    (let
        (
            (permission-key {owner: tx-sender, accessor: to})
            (current-permission (map-get? access-permissions permission-key))
        )
        (asserts! (is-none current-permission) (err err-already-granted))
        (begin
            (map-set access-permissions
                permission-key
                {
                    granted: true,
                    timestamp: block-height,
                    expiry: expiry
                }
            )
            (add-access-history tx-sender to "" "GRANT")
            (ok true)
        )
    )
)

;; Grant permanent access (backward compatibility)
(define-public (grant-access (to principal))
    (grant-access-with-expiry to none)
)

;; Revoke access
(define-public (revoke-access (from principal))
    (let
        (
            (permission-key {owner: tx-sender, accessor: from})
        )
        (map-delete access-permissions permission-key)
        (add-access-history tx-sender from "" "REVOKE")
        (ok true)
    )
)

;; Check access permission with expiry validation
(define-read-only (check-access (owner principal) (accessor principal))
    (let
        (
            (permission (map-get? access-permissions {owner: owner, accessor: accessor}))
        )
        (if (is-some permission)
            (let
                (
                    (perm (unwrap-panic permission))
                    (expiry-height (get expiry perm))
                )
                (if (and (is-some expiry-height) (> block-height (unwrap-panic expiry-height)))
                    (ok false)
                    (ok (get granted perm))
                )
            )
            (ok false)
        )
    )
)

;; Private Functions

;; Add entry to access history
(define-private (add-access-history (owner principal) (accessor principal) (data-hash (string-ascii 64)) (action (string-ascii 10)))
    (let
        (
            (history (default-to (list ) (map-get? access-history owner)))
        )
        (map-set access-history
            owner
            (append history (list {
                accessor: accessor,
                data-hash: data-hash,
                timestamp: block-height,
                action: action
            }))
        )
    )
)

;; Get user's data
(define-read-only (get-user-data (user principal))
    (ok (default-to (list ) (map-get? data-store user)))
)

;; Get access history
(define-read-only (get-access-history (user principal))
    (ok (default-to (list ) (map-get? access-history user)))
)

;; Get access permission details
(define-read-only (get-access-details (owner principal) (accessor principal))
    (ok (map-get? access-permissions {owner: owner, accessor: accessor}))
)
