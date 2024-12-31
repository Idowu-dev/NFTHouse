# NFT Auction Contract

## Features
- Create NFT auctions with customizable duration and minimum bid
- Incremental bidding system
- Automated NFT transfer on auction completion
- Built-in security checks and validations

## Contract Functions

### Read-Only
- `get-auction`: Retrieves auction details
- `is-valid-duration`: Validates auction duration
- `validate-auction-id`: Verifies auction existence

### Public
- `create-auction`: Start new NFT auction
- `place-bid`: Place bid on active auction
- `end-auction`: Complete auction and transfer NFT

## Security
- Duration constraints
- Minimum bid requirements
- Contract ownership verification
- Auction state validation
- Protected NFT transfers

## Usage Example
```clarity
;; Create auction
(contract-call? .nft-auction create-auction nft-contract token-id u100 u1000)

;; Place bid
(contract-call? .nft-auction place-bid u1)

;; End auction
(contract-call? .nft-auction end-auction u1 nft-contract)
```

## Error Codes
- u101: Not found
- u102: Bid too low
- u103: Auction ended
- u104: Invalid duration
- u105: Invalid bid