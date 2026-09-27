create or replace function customer.handle_new_auth_customer() returns trigger language plpgsql security definer set search_path=customer,public as $$
begin insert into customer.customers(auth_user_id,email,first_name,last_name) values(new.id,new.email,new.raw_user_meta_data->>'first_name',new.raw_user_meta_data->>'last_name') on conflict(auth_user_id) do nothing; return new; end; $$;
drop trigger if exists on_auth_user_created_customer on auth.users;
create trigger on_auth_user_created_customer after insert on auth.users for each row execute function customer.handle_new_auth_customer();