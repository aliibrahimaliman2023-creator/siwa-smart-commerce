insert into identity.role_permissions(role_id,permission_id)
select r.id,p.id
from identity.roles r
cross join identity.permissions p
where r.code in ('manager','super_admin')
  and p.code='catalog.manage'
on conflict do nothing;
