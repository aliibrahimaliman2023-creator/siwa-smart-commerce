import {createClient} from 'https://esm.sh/@supabase/supabase-js@2';
import {corsHeaders,json} from '../_shared/http.ts';
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders});
 if(req.method!=='POST')return json({code:'METHOD_NOT_ALLOWED'},405);
 try{
  const payload=await req.json();
  const auth=req.headers.get('Authorization')??'';
  const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:auth}}});
  if(!payload.event_id)return json({code:'EVENT_ID_REQUIRED'},400);
  const {data,error}=await supabase.rpc('enqueue_automation_for_event',{p_event_id:payload.event_id});
  if(error)return json({code:'AUTOMATION_ENQUEUE_FAILED',message:error.message},400);
  return json({ok:true,queued:data??0,write_policy:'actions_execute_only_through_approved_runtime'});
 }catch{return json({code:'INVALID_JSON'},400);}
});