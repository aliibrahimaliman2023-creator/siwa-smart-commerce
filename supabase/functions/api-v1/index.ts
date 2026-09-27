import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json } from '../_shared/http.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok',{headers:corsHeaders});
  if (req.method !== 'GET') return json({code:'METHOD_NOT_ALLOWED'},405);
  const url=new URL(req.url);
  const path=url.pathname.replace(/^.*\/api-v1\/?/,'').replace(/^\/+/,'');
  const supabase=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_ANON_KEY')!,{global:{headers:{Authorization:req.headers.get('Authorization')??''}}});
  if(path==='products'){
    const limit=Math.min(Math.max(Number(url.searchParams.get('limit')??24),1),100);
    const {data,error}=await supabase.from('machine_commerce_feed').select('*').order('name_en').limit(limit);
    if(error)return json({code:'PRODUCTS_READ_FAILED',message:error.message},400);
    return json({api_version:'v1',data:data??[]});
  }
  if(path==='product'){
    const slug=url.searchParams.get('slug');
    if(!slug)return json({code:'SLUG_REQUIRED'},400);
    const {data,error}=await supabase.from('machine_commerce_feed').select('*').eq('slug',slug).maybeSingle();
    if(error)return json({code:'PRODUCT_READ_FAILED',message:error.message},400);
    if(!data)return json({code:'NOT_FOUND'},404);
    return json({api_version:'v1',data});
  }
  return json({code:'NOT_FOUND'},404);
});