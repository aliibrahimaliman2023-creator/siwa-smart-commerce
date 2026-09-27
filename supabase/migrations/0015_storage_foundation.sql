-- Storage foundation: public catalog assets, private customer assets, private documents.
-- Bucket metadata is managed by Supabase Storage; policies scope object access.
insert into storage.buckets (id,name,public)
values
 ('product-media','product-media',true),
 ('customer-uploads','customer-uploads',false),
 ('documents','documents',false),
 ('avatars','avatars',false),
 ('marketing-assets','marketing-assets',true)
on conflict (id) do update set public=excluded.public;

drop policy if exists "product media public read" on storage.objects;
create policy "product media public read" on storage.objects for select to public using (bucket_id='product-media');

drop policy if exists "marketing assets public read" on storage.objects;
create policy "marketing assets public read" on storage.objects for select to public using (bucket_id='marketing-assets');

drop policy if exists "customer uploads owner read" on storage.objects;
create policy "customer uploads owner read" on storage.objects for select to authenticated using (bucket_id='customer-uploads' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "customer uploads owner insert" on storage.objects;
create policy "customer uploads owner insert" on storage.objects for insert to authenticated with check (bucket_id='customer-uploads' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "customer uploads owner update" on storage.objects;
create policy "customer uploads owner update" on storage.objects for update to authenticated using (bucket_id='customer-uploads' and (storage.foldername(name))[1]=auth.uid()::text) with check (bucket_id='customer-uploads' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "customer uploads owner delete" on storage.objects;
create policy "customer uploads owner delete" on storage.objects for delete to authenticated using (bucket_id='customer-uploads' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "avatars owner read" on storage.objects;
create policy "avatars owner read" on storage.objects for select to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);

drop policy if exists "avatars owner write" on storage.objects;
create policy "avatars owner write" on storage.objects for all to authenticated using (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text) with check (bucket_id='avatars' and (storage.foldername(name))[1]=auth.uid()::text);
