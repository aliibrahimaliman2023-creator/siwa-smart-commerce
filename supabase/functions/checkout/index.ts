import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders,json} from '../_shared/http.ts';
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS') return new Response('ok',{headers:corsHeaders});
 if(req.method!=='POST') return json({code:'METHOD_NOT_ALLOWED'},405);
 try{
  const body=await req.json(); const key=req.headers.get('idempotency-key')??body.idempotencyKey;
  if(!key||key.length<16)return json({code:'INVALID_IDEMPOTENCY_KEY'},400);
  const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:req.headers.get('Authorization')??''}}});
  const {data,error}=await supabase.rpc('checkout_atomic_v2',{p_idempotency_key:key,p_currency:body.currency,p_location_id:body.locationId,p_items:body.items,p_shipping_address:body.shippingAddress??{},p_customer_snapshot:body.customerSnapshot??{},p_coupon_code:body.couponCode??null});
  if(error)return json({code:error.code??'CHECKOUT_FAILED',message:error.message},400);
  return json(data);
 }catch(error){return json({code:'CHECKOUT_BAD_REQUEST',message:String(error)},400);}
});