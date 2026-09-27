import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders,json} from '../_shared/http.ts';

Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders});
 if(req.method!=='POST')return json({code:'METHOD_NOT_ALLOWED'},405);
 try{
  const payload=await req.json();
  const action=String(payload.action??'search');
  const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:req.headers.get('Authorization')??''}}});
  if(action==='search'){
   const {data,error}=await supabase.rpc('search_products',{p_query:payload.query??null,p_min_price:payload.min_price??null,p_max_price:payload.max_price??null,p_available_only:payload.available_only??true,p_limit:payload.limit??12});
   if(error)return json({code:'SEARCH_FAILED',message:error.message},400);
   return json({ok:true,mode:'deterministic_assistant',action,write_policy:'approval_required',data:data??[]});
  }
  if(action==='product_feed'){
   const q=supabase.from('machine_commerce_feed').select('*');
   const {data,error}=payload.slug?q.eq('slug',payload.slug).maybeSingle():await q.limit(Math.min(Number(payload.limit??12),50));
   if(error)return json({code:'PRODUCT_FEED_FAILED',message:error.message},400);
   return json({ok:true,mode:'deterministic_assistant',action,data});
  }
  if(action==='business_snapshot'){
   const {data,error}=await supabase.from('executive_command_center').select('*').maybeSingle();
   if(error)return json({code:'BUSINESS_SNAPSHOT_FAILED',message:error.message},400);
   return json({ok:true,mode:'business_tool',action,write_policy:'approval_required',data});
  }
  if(action==='recommend'){
   const {data,error}=await supabase.from('recommendation_candidates').select('*').order('score',{ascending:false}).limit(Math.min(Number(payload.limit??12),50));
   if(error)return json({code:'RECOMMENDATION_FAILED',message:error.message},400);
   return json({ok:true,mode:'deterministic_assistant',action,write_policy:'approval_required',data:data??[]});
  }
  return json({code:'UNSUPPORTED_ACTION',supported:['search','product_feed','business_snapshot','recommend']},400);
 }catch{return json({code:'INVALID_JSON'},400);}
});