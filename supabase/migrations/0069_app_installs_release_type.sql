-- Record HOW a build was distributed, so the install count can be reconciled
-- against App Store Connect.
--
-- The question this answers: on 2026-09-23 app_installs had two rows and App
-- Store Connect reported one first-time download. One of the two produced no
-- events at all, and there was no way to tell whether it was a real user, a
-- reinstall, or a build launched from Xcode — the install id is a random uuid
-- that deliberately carries nothing about the device.
--
-- WHAT THIS CAN AND CANNOT SEPARATE. expo-application derives the release type
-- from `embedded.mobileprovision` (ios/EXApplication/EXProvisioningProfile.m).
-- App Store *and* TestFlight builds are both shipped WITHOUT that profile, so
-- both report app_store. This therefore splits:
--
--   simulator / development / ad_hoc / enterprise   <- our own launches
--   app_store                                       <- App Store AND TestFlight
--
-- which removes the main source of noise (three installs nine minutes apart on
-- 2026-09-18, two with zero events) but still will not make the number equal
-- Apple's. Splitting TestFlight out needs the receipt path
-- (Bundle.main.appStoreReceiptURL ends in "sandboxReceipt"), which
-- expo-application does not expose — that would be a native addition.
--
-- Null for every install recorded before this, and for any client older than the
-- build that starts sending it.

begin;

alter table public.app_installs add column if not exists release_type text;

alter table public.app_installs drop constraint if exists app_installs_release_type_ck;
alter table public.app_installs add constraint app_installs_release_type_ck
  check (release_type is null or release_type in (
    'app_store', 'ad_hoc', 'enterprise', 'development', 'simulator', 'unknown'
  ));

comment on column public.app_installs.release_type is
  'How the build was distributed, from expo-application getIosApplicationReleaseTypeAsync. NOTE app_store covers TestFlight too — both ship without an embedded provisioning profile, so they are indistinguishable here. Null for installs recorded before 2026-09-25.';

commit;
