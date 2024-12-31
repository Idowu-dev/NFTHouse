(define-non-fungible-token nft-auction uint)

(define-trait nft-trait
  ((transfer (uint principal principal) (response bool uint)))
)

(define-constant err-not-found (err u101))
(define-constant err-bid-too-low (err u102))
(define-constant err-auction-ended (err u103))
(define-constant err-invalid-duration (err u104))
(define-constant err-invalid-bid (err u105))

(define-map auctions
    { auction-id: uint }
    {
        nft-contract: principal,
        token-id: uint,
        seller: principal,
        minimum-bid: uint,
        current_price: uint,
        winner: (optional principal),
        end-block: uint,
        active: bool
    }
)

(define-data-var next-auction-id uint u0)

(define-read-only (get-auction (auction-id uint))
    (map-get? auctions { auction-id: auction-id })
)

(define-read-only (is-valid-duration (duration uint))
    (and (> duration u0) (<= duration u10000))
)

(define-public (create-auction (nft-contract <nft-trait>) (token-id uint) (minimum-bid uint) (duration uint))
    (let ((auction-id (+ (var-get next-auction-id) u1))
          (end-block (+ block-height duration)))
        
        (asserts! (is-valid-duration duration) err-invalid-duration)
        (asserts! (> minimum-bid u0) err-invalid-bid)
        (asserts! (is-eq tx-sender (contract-of nft-contract)) err-not-found)
        
        (try! (contract-call? nft-contract transfer token-id tx-sender (as-contract tx-sender)))
        
        (map-set auctions { auction-id: auction-id }
            {
                nft-contract: (contract-of nft-contract),
                token-id: token-id,
                seller: tx-sender,
                minimum-bid: minimum-bid,
                current_price: minimum-bid,
                winner: none,
                end-block: end-block,
                active: true
            })
        
        (var-set next-auction-id auction-id)
        (ok auction-id)))

(define-read-only (validate-auction-id (auction-id uint))
    (is-some (map-get? auctions { auction-id: auction-id }))
)

(define-public (place-bid (auction-id uint))
    (let ((auction (unwrap! (map-get? auctions { auction-id: auction-id }) err-not-found)))
        
        (asserts! (validate-auction-id auction-id) err-not-found)
        (asserts! (get active auction) err-auction-ended)
        (asserts! (<= block-height (get end-block auction)) err-auction-ended)
        
        (map-set auctions { auction-id: auction-id }
            (merge auction {
                winner: (some tx-sender),
                current_price: (+ (get current_price auction) u1)
            }))
        
        (ok true)))

(define-public (end-auction (auction-id uint) (nft-contract <nft-trait>))
    (let ((auction (unwrap! (map-get? auctions { auction-id: auction-id }) err-not-found)))
        
        (asserts! (validate-auction-id auction-id) err-not-found)
        (asserts! (get active auction) err-auction-ended)
        (asserts! (>= block-height (get end-block auction)) err-auction-ended)
        (asserts! (is-eq (contract-of nft-contract) (get nft-contract auction)) err-not-found)
        
        (try! (as-contract (contract-call? nft-contract transfer 
            (get token-id auction)
            (as-contract tx-sender)
            (unwrap! (get winner auction) err-not-found))))
        
        (map-set auctions { auction-id: auction-id }
            (merge auction { active: false }))
        
        (ok true)))