import {corsHeaders,json} from '../_shared/http.ts';
async function authorized(req:Request){const expected=Deno.env.get('WEBHOOK_SHARED_SECRET'); const provided=req.headers.get('x-webhook-secret'); return !!expected && !!provided && expected===provided;}
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders});
 if(req.method!=='POST')return json({code:'METHOD_NOT_ALLOWED'},405);
 if(!(await authorized(req)))return json({code:'WEBHOOK_NOT_CONFIGURED_OR_UNAUTHORIZED'},401);
 try{const payload=await req.json();return json({ok:true,adapter:'payment-webhook',accepted:true,mode:'contract'});}
 catch{return json({code:'INVALID_JSON'},400);}
});