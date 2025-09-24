# 🌱 Fair Trade Proof Token

A blockchain-based smart contract system for certifying and tracking fair trade practices, built on the Stacks blockchain using Clarity.

## 📋 Overview

The Fair Trade Proof Token system enables producers, certifiers, and consumers to participate in a transparent fair trade ecosystem. Producers can register their products, obtain certifications from authorized certifiers, and sell certified fair trade goods while being rewarded for ethical practices.

## ✨ Key Features

- 🏭 **Producer Registration**: Producers can register with their name and location
- 🏅 **Certification System**: Authorized certifiers can issue time-bound certifications
- 📦 **Product Tracking**: Create and track certified fair trade products
- 💰 **Token Economics**: Built-in fungible token for transactions and rewards
- ⚖️ **Governance**: Owner-controlled authorization and system parameters
- 🔒 **Verification**: On-chain certification validation

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/clarinet) installed
- Node.js for testing (optional)

### Installation

1. Clone the repository
2. Navigate to project directory
3. Run contract check:
```bash
clarinet check
```

### Testing

```bash
npm install
npm test
```

## 📊 Contract Architecture

### Core Components

1. **Fair Trade Token** - Fungible token for ecosystem transactions
2. **Producer Registry** - Database of registered fair trade producers
3. **Certification System** - Time-bound certifications with expiry
4. **Product Catalog** - Certified products with batch tracking
5. **Authorization System** - Controlled access for certifiers

### Data Structures

- **Producers**: Name, location, registration date, certification level, status
- **Certifications**: Producer, certifier, issue/expiry dates, type, verification status
- **Products**: Producer, name, batch ID, certification, quantity, pricing, sale status

## 🔧 Core Functions

### 👥 Producer Functions

```clarity
(register-producer "Producer Name" "Location")
```
Register as a fair trade producer in the system.

### 🏅 Certification Functions

```clarity
(issue-certification producer-principal "Organic")
```
Issue a certification to a producer (certifiers only).

```clarity
(verify-certification certification-id)
```
Verify if a certification is valid and not expired.

### 📦 Product Functions

```clarity
(create-product "Product Name" "BATCH001" certification-id u100 u50)
```
Create a certified product with quantity and pricing.

```clarity
(purchase-product product-id buyer-principal)
```
Purchase a fair trade product using tokens.

### 💰 Token Functions

```clarity
(transfer amount from-principal to-principal memo)
(mint amount recipient-principal)
(burn amount)
```
Standard fungible token operations.

### ⚙️ Admin Functions

```clarity
(add-authorized-certifier certifier-principal)
(reward-fair-trade-practices producer-principal amount)
(update-certification-fee new-fee)
```
System administration (owner only).

## 🎯 Usage Examples

### Register as Producer
```clarity
(contract-call? .fair-trade-proof-token register-producer "Green Farm Co" "Costa Rica")
```

### Issue Certification
```clarity
(contract-call? .fair-trade-proof-token issue-certification 'SP123...PRODUCER "Fair Trade Certified")
```

### Create Product
```clarity
(contract-call? .fair-trade-proof-token create-product "Organic Coffee" "BATCH2024001" u1 u1000 u25)
```

### Purchase Product
```clarity
(contract-call? .fair-trade-proof-token purchase-product u1 'SP456...BUYER)
```

## 📝 Error Codes

- `u100` - Owner only operation
- `u101` - Not authorized  
- `u102` - Insufficient balance
- `u103` - Producer not found
- `u104` - Already certified
- `u105` - Certification expired
- `u106` - Invalid certification
- `u107` - Product not found
- `u108` - Product already sold

## 🔍 Read-Only Functions

Query contract state without making changes:

- `(get-balance account)` - Get token balance
- `(get-producer principal)` - Get producer info
- `(get-certification id)` - Get certification details
- `(get-product id)` - Get product information
- `(is-authorized-certifier principal)` - Check certifier status

## 🏗️ Development

### Contract Structure

The contract implements:
- SIP-010 compliant fungible token
- Producer registration and management
- Time-bound certification system
- Product creation and sales
- Authorization and access control

### Testing

Run comprehensive tests:
```bash
clarinet test
```

### Deployment

Deploy to testnet:
```bash
clarinet integrate
```


## 📄 License

This project is open source. See LICENSE file for details.

## 🌍 Impact

This system promotes:
- ✅ Transparency in fair trade certification
- ✅ Direct producer-to-consumer connections
- ✅ Immutable certification records
- ✅ Incentivized ethical practices
- ✅ Reduced certification fraud

---

Built with 💚 for a more equitable global trade system
