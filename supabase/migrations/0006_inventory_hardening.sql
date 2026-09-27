alter table inventory.transactions add constraint inventory_transactions_batch_fk foreign key(batch_id) references production.batches(id);
create index if not exists idx_inventory_reservations_order on inventory.reservations(order_id,status);
create index if not exists idx_orders_customer_created on commerce.orders(customer_id,created_at desc);
create index if not exists idx_order_items_order on commerce.order_items(order_id);
create index if not exists idx_prices_variant_active_window on catalog.prices(product_variant_id,is_active,valid_from desc);
create unique index if not exists idx_one_active_price_per_window on catalog.prices(product_variant_id,currency,channel,valid_from) where is_active;