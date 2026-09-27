-- 0013_release_reservation_security.sql
-- Reservation expiry cleanup is an internal/service operation only.

revoke all on function inventory.release_expired_reservations(timestamptz) from public;
revoke all on function inventory.release_expired_reservations(timestamptz) from anon;
revoke all on function inventory.release_expired_reservations(timestamptz) from authenticated;
grant execute on function inventory.release_expired_reservations(timestamptz) to service_role;
