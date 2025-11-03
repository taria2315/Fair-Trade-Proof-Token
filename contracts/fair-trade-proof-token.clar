;; Fair Trade Proof Token
;; A Clarity smart contract for verifying and tracking fair trade products
;; Implements SIP-010 fungible token standard with enhanced fair trade features

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-OWNER-ONLY (err u100))
(define-constant ERR-NOT-AUTHORIZED (err u101))
(define-constant ERR-INVALID-AMOUNT (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-PRODUCT-NOT-FOUND (err u104))
(define-constant ERR-CERTIFICATION-EXPIRED (err u105))
(define-constant ERR-INVALID-CERTIFIER (err u106))
(define-constant ERR-SUPPLY-EXCEEDED (err u107))

;; Token configuration
(define-fungible-token fair-trade-token)
(define-constant TOKEN-NAME "Fair Trade Proof Token")
(define-constant TOKEN-SYMBOL "FTPT")
(define-constant TOKEN-DECIMALS u6)
(define-constant MAX-SUPPLY u1000000000000) ;; 1 million tokens with 6 decimals

;; Data maps and variables
(define-data-var token-uri (optional (string-utf8 256)) none)
(define-data-var contract-owner principal CONTRACT-OWNER)
(define-data-var total-supply uint u0)

;; Product certification tracking
(define-map product-certifications 
  { product-id: (string-ascii 32) }
  {
    producer: principal,
    certifier: principal,
    certification-date: uint,
    expiry-date: uint,
    certification-hash: (buff 32),
    is-active: bool
  }
)

;; Certified producers registry
(define-map certified-producers 
  { producer: principal }
  {
    certification-level: (string-ascii 16),
    registration-date: uint,
    is-verified: bool,
    total-products-certified: uint
  }
)

;; Authorized certifiers
(define-map authorized-certifiers
  { certifier: principal }
  {
    organization-name: (string-ascii 64),
    authorization-date: uint,
    is-active: bool
  }
)

;; Product supply chain tracking
(define-map supply-chain-records
  { record-id: (string-ascii 32) }
  {
    product-id: (string-ascii 32),
    stage: (string-ascii 16), ;; "production", "processing", "transport", "retail"
    location: (string-ascii 32),
    timestamp: uint,
    handler: principal,
    quality-score: uint ;; 1-100 quality rating
  }
)

;; SIP-010 Standard Functions

(define-read-only (get-name)
  (ok TOKEN-NAME)
)

(define-read-only (get-symbol)
  (ok TOKEN-SYMBOL)
)

(define-read-only (get-decimals)
  (ok TOKEN-DECIMALS)
)

(define-read-only (get-balance (who principal))
  (ok (ft-get-balance fair-trade-token who))
)

(define-read-only (get-total-supply)
  (ok (var-get total-supply))
)

(define-read-only (get-token-uri)
  (ok (var-get token-uri))
)

;; Transfer function with fair trade verification
(define-public (transfer (amount uint) (from principal) (to principal) (memo (optional (buff 34))))
  (begin
    (asserts! (or (is-eq from tx-sender) (is-eq from (var-get contract-owner))) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (ft-get-balance fair-trade-token from) amount) ERR-INSUFFICIENT-BALANCE)
    (try! (ft-transfer? fair-trade-token amount from to))
    (match memo to-print (print to-print) 0x)
    (ok true)
  )
)

;; Administrative Functions

(define-public (set-token-uri (value (optional (string-utf8 256))))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-OWNER-ONLY)
    (var-set token-uri value)
    (ok true)
  )
)

(define-public (mint (amount uint) (to principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-OWNER-ONLY)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (<= (+ (var-get total-supply) amount) MAX-SUPPLY) ERR-SUPPLY-EXCEEDED)
    (try! (ft-mint? fair-trade-token amount to))
    (var-set total-supply (+ (var-get total-supply) amount))
    (ok true)
  )
)

;; Fair Trade Specific Functions

;; Register authorized certifier
(define-public (register-certifier (certifier principal) (org-name (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-OWNER-ONLY)
    (map-set authorized-certifiers
      { certifier: certifier }
      {
        organization-name: org-name,
        authorization-date: block-height,
        is-active: true
      }
    )
    (ok true)
  )
)

;; Register certified producer
(define-public (register-producer (producer principal) (level (string-ascii 16)))
  (let ((certifier-info (unwrap! (map-get? authorized-certifiers { certifier: tx-sender }) ERR-INVALID-CERTIFIER)))
    (asserts! (get is-active certifier-info) ERR-INVALID-CERTIFIER)
    (map-set certified-producers
      { producer: producer }
      {
        certification-level: level,
        registration-date: block-height,
        is-verified: true,
        total-products-certified: u0
      }
    )
    (ok true)
  )
)

;; Certify product with comprehensive tracking
(define-public (certify-product 
  (product-id (string-ascii 32))
  (producer principal)
  (expiry-blocks uint)
  (cert-hash (buff 32))
)
  (let (
    (certifier-info (unwrap! (map-get? authorized-certifiers { certifier: tx-sender }) ERR-INVALID-CERTIFIER))
    (producer-info (unwrap! (map-get? certified-producers { producer: producer }) ERR-NOT-AUTHORIZED))
  )
    (asserts! (get is-active certifier-info) ERR-INVALID-CERTIFIER)
    (asserts! (get is-verified producer-info) ERR-NOT-AUTHORIZED)
    
    ;; Create product certification
    (map-set product-certifications
      { product-id: product-id }
      {
        producer: producer,
        certifier: tx-sender,
        certification-date: block-height,
        expiry-date: (+ block-height expiry-blocks),
        certification-hash: cert-hash,
        is-active: true
      }
    )
    
    ;; Update producer stats
    (map-set certified-producers
      { producer: producer }
      (merge 
        producer-info
        { total-products-certified: (+ (get total-products-certified producer-info) u1) }
      )
    )
    
    ;; Mint tokens as reward for certification
    (try! (ft-mint? fair-trade-token u1000000 producer)) ;; 1 token with 6 decimals
    (var-set total-supply (+ (var-get total-supply) u1000000))
    
    (ok true)
  )
)

;; NEW INDEPENDENT FEATURE: Supply Chain Quality Tracking System
;; This feature allows comprehensive tracking of products through the supply chain
;; with quality scoring and stage-based verification

(define-public (add-supply-chain-record
  (record-id (string-ascii 32))
  (product-id (string-ascii 32))
  (stage (string-ascii 16))
  (location (string-ascii 32))
  (quality-score uint)
)
  (let (
    (product-cert (unwrap! (map-get? product-certifications { product-id: product-id }) ERR-PRODUCT-NOT-FOUND))
    (producer-info (unwrap! (map-get? certified-producers { producer: (get producer product-cert) }) ERR-NOT-AUTHORIZED))
  )
    (asserts! (get is-active product-cert) ERR-PRODUCT-NOT-FOUND)
    (asserts! (< block-height (get expiry-date product-cert)) ERR-CERTIFICATION-EXPIRED)
    (asserts! (<= quality-score u100) ERR-INVALID-AMOUNT) ;; Quality score must be 1-100
    (asserts! (> quality-score u0) ERR-INVALID-AMOUNT)
    
    ;; Only certified producers or contract owner can add records
    (asserts! (or 
      (is-eq tx-sender (get producer product-cert))
      (is-eq tx-sender (var-get contract-owner))
    ) ERR-NOT-AUTHORIZED)
    
    ;; Add supply chain record
    (map-set supply-chain-records
      { record-id: record-id }
      {
        product-id: product-id,
        stage: stage,
        location: location,
        timestamp: block-height,
        handler: tx-sender,
        quality-score: quality-score
      }
    )
    
    ;; Reward high quality scores with additional tokens
    (if (>= quality-score u90)
      (begin
        (try! (ft-mint? fair-trade-token u500000 (get producer product-cert))) ;; 0.5 bonus tokens
        (var-set total-supply (+ (var-get total-supply) u500000))
      )
      true
    )
    
    (ok true)
  )
)

;; Get quality score for a specific supply chain record
(define-read-only (get-record-quality-score (record-id (string-ascii 32)))
  (match (map-get? supply-chain-records { record-id: record-id })
    record-info (ok (get quality-score record-info))
    ERR-PRODUCT-NOT-FOUND
  )
)

;; Check if product has high quality throughout supply chain
(define-read-only (is-high-quality-product (product-id (string-ascii 32)))
  (match (map-get? product-certifications { product-id: product-id })
    cert-info (and 
      (get is-active cert-info)
      (< block-height (get expiry-date cert-info))
    )
    false
  )
)

;; Read-only functions for data retrieval

(define-read-only (get-product-certification (product-id (string-ascii 32)))
  (map-get? product-certifications { product-id: product-id })
)

(define-read-only (get-producer-info (producer principal))
  (map-get? certified-producers { producer: producer })
)

(define-read-only (get-certifier-info (certifier principal))
  (map-get? authorized-certifiers { certifier: certifier })
)

(define-read-only (get-supply-chain-record (record-id (string-ascii 32)))
  (map-get? supply-chain-records { record-id: record-id })
)

(define-read-only (is-product-certified (product-id (string-ascii 32)))
  (match (map-get? product-certifications { product-id: product-id })
    cert-info (and 
      (get is-active cert-info)
      (< block-height (get expiry-date cert-info))
    )
    false
  )
)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

;; Initialize contract
(begin
  (try! (ft-mint? fair-trade-token u10000000000 CONTRACT-OWNER)) ;; Mint 10,000 initial tokens
  (var-set total-supply u10000000000)
)