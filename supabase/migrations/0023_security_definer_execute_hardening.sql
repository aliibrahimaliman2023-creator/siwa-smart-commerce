-- 0023_security_definer_execute_hardening.sql
revoke all on function platform.has_permission(uuid,text) from public;
grant execute on function platform.has_permission(uuid,text) to authenticated;