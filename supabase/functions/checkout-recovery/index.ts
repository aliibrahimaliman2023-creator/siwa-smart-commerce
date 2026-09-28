import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json } from '../_shared/http.ts';

Deno.serve(async (req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders});
  if(req.method!=='POST')return json({code:'METHOD_NOT_ALLOWED'},405);
  const authorization=req.headers.get('Authorization');
  if(!authorization) return json({code:'UNAUTHENTICATED'},401);
  const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{
    global:{headers:{Authorization:authorization}}
  });
  const body=await req.json().catch(()=>({}));
  const {data,error}=await supabase.rpc('upsert_checkout_session',{
    p_session_key:body.sessionKey,p_cart:body.cart??[],p_pricing:body.pricing??{},
    p_shipping:body.shipping??{},p_last_step:body.lastStep??null,p_failure_code:body.failureCode??null
  });
  if(error)return json({code:'RECOVERY_SESSION_FAILED',message:error.message},400);
  return json(data);
});