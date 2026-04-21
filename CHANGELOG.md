## 0.1.0

- Rebuilt the package as a headless IAP service on top of `in_app_purchase`
- Added normalized public models for products, purchases, errors, and state
- Added support for consumables, non-consumables, and subscriptions
- Added a `BillingGateway` abstraction for testability
- Added restore handling, entitlement resolution, and pluggable purchase verification
- Added internal purchase acknowledgement logic
- Replaced placeholder tests and documentation with package-quality coverage and usage guidance
