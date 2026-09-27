create index if not exists idx_finance_payments_provider_reference on finance.payments(provider_code,provider_reference);
create index if not exists idx_finance_settlements_status_date on finance.settlements(status,settlement_date);
create or replace function finance.record_payment(p_order_id uuid,p_provider text,p_reference text,p_amount numeric,p_currency text,p_status text,p_payload jsonb default '{}') returns uuid language plpgsql security definer set search_path=finance,commerce,public as $$
declare v_id uuid;
begin
 if p_order_id is null or p_amount is null or p_amount<0 or coalesce(p_currency,'')='' then raise exception 'INVALID_PAYMENT'; end if;
 insert into finance.payments(order_id,provider_code,provider_reference,amount,currency,status,payload) values(p_order_id,p_provider,p_reference,p_amount,p_currency,p_status,coalesce(p_payload,'{}')) returning id into v_id;
 insert into finance.financial_transactions(transaction_type,order_id,payment_id,amount,currency,description) values('payment',p_order_id,v_id,p_amount,p_currency,'provider payment');
 return v_id;
end; $$;
revoke all on function finance.record_payment(uuid,text,text,numeric,text,text,jsonb) from public;