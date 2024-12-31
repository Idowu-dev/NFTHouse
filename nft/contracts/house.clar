(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-bid-too-low (err u102))
(define-constant err-auction-ended (err u103))
(define-constant err-auction-active (err u104))

;; Data structures
(define-map auctions
    { auction-id: uint }
    {
        nft-contract: principal,
        token-id: uint,
        seller: principal,
        minimum-bid: uint,
        highest-bid: uint,
        highest-bidder: (optional principal),
        end-block: uint,
        active: bool
    }
)

(define-map user-bids 
    { auction-id: uint, bidder: principal } 
    { amount: uint }
)

;; Create new auction
(define-public (create-auction (nft-contract principal) 
                             (token-id uint)
                             (minimum-bid uint)
                             (duration uint))
    (let ((auction-id (+ (var-get next-auction-id) u1))
          (end-block (+ block-height duration)))
        
        ;; Transfer NFT to contract
        (try! (contract-call? nft-contract transfer token-id tx-sender (as-contract tx-sender)))
        
        ;; Create auction record
        (map-set auctions
            { auction-id: auction-id }
            {
                nft-contract: nft-contract,
                token-id: token-id,
                seller: tx-sender,
                minimum-bid: minimum-bid,
                highest-bid: u0,
                highest-bidder: none,
                end-block: end-block,
                active: true
            }
        )
        
        (var-set next-auction-id auction-id)
        (ok auction-id)
    )
)

;; Place bid on auction
(define-public (place-bid (auction-id uint) (bid-amount uint))
    (let ((auction (unwrap! (map-get? auctions { auction-id: auction-id }) (err err-not-found)))
          (current-highest-bid (get highest-bid auction)))
        
        ;; Check auction is active and not ended
        (asserts! (get active auction) (err err-auction-ended))
        (asserts! (<= block-height (get end-block auction)) (err err-auction-ended))
        
        ;; Check bid is higher than minimum and current highest
        (asserts! (>= bid-amount (get minimum-bid auction)) (err err-bid-too-low))
        (asserts! (> bid-amount current-highest-bid) (err err-bid-too-low))
        
        ;; Transfer STX from bidder
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        
        ;; Refund previous bidder if exists
        (match (get highest-bidder auction)
            prev-bidder (try! (as-contract (stx-transfer? current-highest-bid (as-contract tx-sender) prev-bidder)))
            none true
        )
        
        ;; Update auction with new bid
        (map-set auctions
            { auction-id: auction-id }
            (merge auction {
                highest-bid: bid-amount,
                highest-bidder: (some tx-sender)
            })
        )
        
        (ok true)
    )
)

;; End auction and transfer NFT to winner
(define-public (end-auction (auction-id uint))
    (let ((auction (unwrap! (map-get? auctions { auction-id: auction-id }) (err err-not-found))))
        
        ;; Check auction can be ended
        (asserts! (get active auction) (err err-auction-ended))
        (asserts! (>= block-height (get end-block auction)) (err err-auction-active))
        
        ;; Transfer NFT to winner
        (match (get highest-bidder auction)
            winner (begin
                (try! (as-contract 
                    (contract-call? 
                        (get nft-contract auction)
                        transfer
                        (get token-id auction)
                        (as-contract tx-sender)
                        winner
                    )
                ))
                ;; Transfer STX to seller
                (try! (as-contract 
                    (stx-transfer? 
                        (get highest-bid auction)
                        (as-contract tx-sender)
                        (get seller auction)
                    )
                ))
            )
            none (begin
                ;; Return NFT to seller if no bids
                (try! (as-contract 
                    (contract-call? 
                        (get nft-contract auction)
                        transfer
                        (get token-id auction)
                        (as-contract tx-sender)
                        (get seller auction)
                    )
                ))
            )
        )
        
        ;; Mark auction as inactive
        (map-set auctions
            { auction-id: auction-id }
            (merge auction { active: false })
        )
        
        (ok true)
    )
)

;; Initialize next auction ID
(define-data-var next-auction-id uint u0)