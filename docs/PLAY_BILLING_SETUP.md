# Kadd — Google Play Billing setup

## Subscription product

Create a Google Play subscription with:

- Product ID: kadd_premium_monthly
- Base plan ID: monthly
- Type: auto-renewing subscription
- Entitlement: Kadd Premium
- Price and billing period are configured in Play Console.

The Flutter client uses the official Flutter in_app_purchase package. It listens
to purchase updates early, completes pending purchases, and exposes Restore
purchases.

## Internal testing order

1. Create the subscription in Play Console.
2. Create the monthly base plan and activate it for the internal-test track.
3. Add a license tester.
4. Upload a signed AAB to the internal-test track.
5. Install from Google Play, not by sideloading the APK.
6. Open Kadd > Settings > Kadd Premium.
7. Verify the product price loads.
8. Purchase with the license tester.
9. Kill/relaunch Kadd and verify Premium remains active.
10. Use Restore purchases on a clean install signed into the same tester account.
11. Test cancellation/expiry using Play test subscription controls.

## Production rule

The app never treats a local boolean or hidden flag as a Premium purchase.
Premium is granted only from Google Play purchase/restoration events.

For a later server-backed entitlement system, add backend verification before
introducing Family or cross-device entitlements. The current MVP keeps the
working core local and does not require an account.
