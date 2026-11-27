# Attendance Management System (Flutter · Android + iOS)

Selfie + GPS attendance with admin approval workflow, Indian holiday calendar, reports and audit log.
Backend: Firebase Auth + Cloud Firestore (security rules in `firestore.rules`).

**Employee:** sign up / login / forgot password · dashboard · selfie check-in & check-out with map preview ·
history · manual attendance & leave requests · holiday calendar · profile.
**Admin:** fixed admin login · overview · employee management · attendance records (selfies, map, correction with audit) ·
approval panel · holiday management · 8 report types with CSV/Excel export and print/PDF · settings · audit log.

See **[SETUP.md](SETUP.md)** to configure Firebase, create the admin account and build for Android/iPhone.

```
lib/
  main.dart            app entry, auth gate, role routing
  auth/                login, admin login, sign-up, forgot password
  user/                dashboard, punch, history, requests, holidays, profile
  admin/               dashboard, employees, records, approvals, holidays, reports, settings
  core/                models, Firestore repo + live store, capture (camera/GPS/map), IST helpers, UI kit
firestore.rules        security rules (tested: tools/rules-test)
tools/seed_admin.js    creates the fixed admin from environment variables
```
