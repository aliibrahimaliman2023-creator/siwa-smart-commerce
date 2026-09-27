import {corsHeaders,json} from '../_shared/http.ts';
Deno.serve(async(req)=>{
 if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders});
 if(req.method!=='POST')return json({code:'METHOD_NOT_ALLOWED'},405);
 try{const payload=await req.json();return json({ok:true,adapter:'shipping-webhook',accepted:true,payload});}
 catch{return json({code:'INVALID_JSON'},400);}
});