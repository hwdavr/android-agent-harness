# Release Checklist

## Purpose
Final checklist before declaring a feature or bug fix ready for production.

---

## Backward Compatibility

- [ ] Old app versions still work with the new backend response (if API changed)
- [ ] Old backend responses still work with the new app code (if API changed)
- [ ] No DTO fields assumed non-null that might be missing from older server versions
- [ ] Room schema migration added if database schema changed

---

## Feature Flag

- [ ] Feature flag required: yes / no
- If yes:
  - [ ] Flag is defined and tested in both on and off states
  - [ ] Flag name follows existing convention

---

## Force Update

- [ ] Force update required: yes / no / unknown
- If yes:
  - [ ] Backend team notified
  - [ ] Min version enforcement planned

---

## Staged Rollout

- [ ] Staged rollout required: yes / no
- If yes:
  - [ ] Rollout percentage defined
  - [ ] Monitoring period defined

---

## Backend Deployment Dependency

- [ ] This change depends on a backend deployment: yes / no
- If yes:
  - [ ] Backend is deployed and stable before mobile release
  - [ ] Rollback plan defined if backend reverts

---

## Monitoring

- [ ] Error rate monitoring in place for affected API endpoints
- [ ] Crash monitoring configured
- [ ] Analytics events firing correctly (verify in staging/debug)

---

## Final Build Verification

- [ ] `./gradlew assembleDebug` (or `assembleRelease`) passes
- [ ] All tests pass: `./gradlew testDebugUnitTest`
- [ ] Coverage thresholds met
- [ ] No regressions in existing test suite
