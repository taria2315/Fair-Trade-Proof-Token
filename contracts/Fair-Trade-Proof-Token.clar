(define-fungible-token fair-trade-token)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-producer-not-found (err u103))
(define-constant err-already-certified (err u104))
(define-constant err-certification-expired (err u105))
(define-constant err-invalid-certification (err u106))
(define-constant err-product-not-found (err u107))
(define-constant err-product-already-sold (err u108))

(define-data-var total-supply uint u0)
(define-data-var certification-fee uint u100)
(define-data-var certification-duration uint u52560)

(define-map producers
    principal
    {
        name: (string-ascii 50),
        location: (string-ascii 100),
        registered-at: uint,
        certification-level: uint,
        active: bool,
    }
)

(define-map certifications
    uint
    {
        producer: principal,
        certifier: principal,
        issued-at: uint,
        expires-at: uint,
        certification-type: (string-ascii 30),
        verified: bool,
    }
)

(define-map products
    uint
    {
        producer: principal,
        name: (string-ascii 50),
        batch-id: (string-ascii 30),
        certification-id: uint,
        quantity: uint,
        price-per-unit: uint,
        created-at: uint,
        sold: bool,
    }
)

(define-map authorized-certifiers
    principal
    bool
)

(define-data-var next-certification-id uint u1)
(define-data-var next-product-id uint u1)

(define-public (transfer
        (amount uint)
        (from principal)
        (to principal)
        (memo (optional (buff 34)))
    )
    (begin
        (asserts! (or (is-eq from tx-sender) (is-eq from contract-caller))
            err-not-authorized
        )
        (ft-transfer? fair-trade-token amount from to)
    )
)

(define-public (mint
        (amount uint)
        (recipient principal)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (ft-mint? fair-trade-token amount recipient))
        (var-set total-supply (+ (var-get total-supply) amount))
        (ok true)
    )
)

(define-public (burn (amount uint))
    (begin
        (try! (ft-burn? fair-trade-token amount tx-sender))
        (var-set total-supply (- (var-get total-supply) amount))
        (ok true)
    )
)

(define-public (register-producer
        (name (string-ascii 50))
        (location (string-ascii 100))
    )
    (let ((current-block u1))
        (map-set producers tx-sender {
            name: name,
            location: location,
            registered-at: current-block,
            certification-level: u0,
            active: true,
        })
        (ok true)
    )
)

(define-public (add-authorized-certifier (certifier principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-certifiers certifier true)
        (ok true)
    )
)

(define-public (remove-authorized-certifier (certifier principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete authorized-certifiers certifier)
        (ok true)
    )
)

(define-public (issue-certification
        (producer principal)
        (certification-type (string-ascii 30))
    )
    (let (
            (certification-id (var-get next-certification-id))
            (current-block u1)
            (expires-at (+ current-block (var-get certification-duration)))
        )
        (begin
            (asserts!
                (default-to false (map-get? authorized-certifiers tx-sender))
                err-not-authorized
            )
            (asserts! (is-some (map-get? producers producer))
                err-producer-not-found
            )
            (try! (ft-transfer? fair-trade-token (var-get certification-fee) producer
                contract-owner
            ))
            (map-set certifications certification-id {
                producer: producer,
                certifier: tx-sender,
                issued-at: current-block,
                expires-at: expires-at,
                certification-type: certification-type,
                verified: true,
            })
            (var-set next-certification-id (+ certification-id u1))
            (ok certification-id)
        )
    )
)

(define-read-only (verify-certification (certification-id uint))
    (match (map-get? certifications certification-id)
        certification (if (and
                (get verified certification)
                (< u1 (get expires-at certification))
            )
            (ok true)
            err-certification-expired
        )
        err-invalid-certification
    )
)

(define-public (create-product
        (name (string-ascii 50))
        (batch-id (string-ascii 30))
        (certification-id uint)
        (quantity uint)
        (price-per-unit uint)
    )
    (let ((product-id (var-get next-product-id)))
        (begin
            (asserts! (is-some (map-get? producers tx-sender))
                err-producer-not-found
            )
            (asserts! (is-ok (verify-certification certification-id))
                err-invalid-certification
            )
            (map-set products product-id {
                producer: tx-sender,
                name: name,
                batch-id: batch-id,
                certification-id: certification-id,
                quantity: quantity,
                price-per-unit: price-per-unit,
                created-at: u1,
                sold: false,
            })
            (var-set next-product-id (+ product-id u1))
            (ok product-id)
        )
    )
)

(define-public (purchase-product
        (product-id uint)
        (buyer principal)
    )
    (match (map-get? products product-id)
        product (let ((total-cost (* (get quantity product) (get price-per-unit product))))
            (begin
                (asserts! (not (get sold product)) err-product-already-sold)
                (try! (ft-transfer? fair-trade-token total-cost buyer
                    (get producer product)
                ))
                (map-set products product-id (merge product { sold: true }))
                (ok true)
            )
        )
        err-product-not-found
    )
)

(define-public (update-certification-fee (new-fee uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set certification-fee new-fee)
        (ok true)
    )
)

(define-public (update-certification-duration (new-duration uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set certification-duration new-duration)
        (ok true)
    )
)

(define-public (deactivate-producer (producer principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? producers producer)
            current-producer (begin
                (map-set producers producer
                    (merge current-producer { active: false })
                )
                (ok true)
            )
            err-producer-not-found
        )
    )
)

(define-public (reward-fair-trade-practices
        (producer principal)
        (reward-amount uint)
    )
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (is-some (map-get? producers producer)) err-producer-not-found)
        (try! (ft-mint? fair-trade-token reward-amount producer))
        (var-set total-supply (+ (var-get total-supply) reward-amount))
        (ok true)
    )
)

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance fair-trade-token account))
)

(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

(define-read-only (get-producer (producer principal))
    (ok (map-get? producers producer))
)

(define-read-only (get-certification (certification-id uint))
    (ok (map-get? certifications certification-id))
)

(define-read-only (get-product (product-id uint))
    (ok (map-get? products product-id))
)

(define-read-only (get-certification-fee)
    (ok (var-get certification-fee))
)

(define-read-only (get-certification-duration)
    (ok (var-get certification-duration))
)

(define-read-only (is-authorized-certifier (certifier principal))
    (ok (default-to false (map-get? authorized-certifiers certifier)))
)

(define-read-only (get-contract-owner)
    (ok contract-owner)
)
