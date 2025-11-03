(define-data-var owner principal tx-sender)

(define-constant ERR_UNAUTHORIZED u100)
(define-constant ERR_ALREADY_HAS_ROLE u101)
(define-constant ERR_DOES_NOT_HAVE_ROLE u102)
(define-constant DEFAULT_ADMIN "DEFAULT_ADMIN_ROLE")

(define-map role-admins 
  {role: (string-ascii 32)} 
  {admin: (string-ascii 32)}
)

(define-map memberships 
  {role: (string-ascii 32), member: principal} 
  {has: bool}
)

(define-read-only (get-owner) 
  (var-get owner)
)

(define-read-only (get-role-admin (role (string-ascii 32)))
  (match (map-get? role-admins {role: role})
    admin-data (get admin admin-data)
    DEFAULT_ADMIN
  )
)

(define-read-only (has-role (role (string-ascii 32)) (account principal))
  (match (map-get? memberships {role: role, member: account})
    data (get has data)
    false
  )
)

(define-read-only (authorized? (role (string-ascii 32)) (sender principal))
  (let (
    (current-owner (var-get owner))
    (admin-role (get-role-admin role))
  )
    (or (is-eq sender current-owner) (has-role admin-role sender))
  )
)

(define-public (grant-role (role (string-ascii 32)) (account principal))
  (if (authorized? role tx-sender)
    (if (has-role role account)
      (err ERR_ALREADY_HAS_ROLE)
      (begin
        (map-set memberships {role: role, member: account} {has: true})
        (ok true)
      )
    )
    (err ERR_UNAUTHORIZED)
  )
)

(define-public (revoke-role (role (string-ascii 32)) (account principal))
  (if (or (authorized? role tx-sender) (is-eq tx-sender account))
    (if (has-role role account)
      (begin
        (map-set memberships {role: role, member: account} {has: false})
        (ok true)
      )
      (err ERR_DOES_NOT_HAVE_ROLE)
    )
    (err ERR_UNAUTHORIZED)
  )
)

(define-public (renounce-role (role (string-ascii 32)))
  (if (has-role role tx-sender)
    (begin
      (map-set memberships {role: role, member: tx-sender} {has: false})
      (ok true)
    )
    (err ERR_DOES_NOT_HAVE_ROLE)
  )
)

(define-public (set-role-admin (role (string-ascii 32)) (admin-role (string-ascii 32)))
  (if (is-eq tx-sender (var-get owner))
    (begin
      (map-set role-admins {role: role} {admin: admin-role})
      (ok true)
    )
    (err ERR_UNAUTHORIZED)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (if (is-eq tx-sender (var-get owner))
    (begin
      (var-set owner new-owner)
      (ok true)
    )
    (err ERR_UNAUTHORIZED)
  )
)