import React,{useEffect,useState}from'react';
import{createClient}from'@supabase/supabase-js';

const url=import.meta.env.VITE_SUPABASE_URL;
const key=import.meta.env.VITE_SUPABASE_ANON_KEY;
const catalog=createClient(url,key,{db:{schema:'catalog'}});
const inventory=createClient(url,key,{db:{schema:'inventory'}});
const logistics=createClient(url,key,{db:{schema:'logistics'}});

type Props={onChanged:()=>Promise<void>};

export function AdminDataManager({onChanged}:Props){
 const[products,setProducts]=useState<any[]>([]),[variants,setVariants]=useState<any[]>([]),[prices,setPrices]=useState<any[]>([]),[items,setItems]=useState<any[]>([]);
 const[carriers,setCarriers]=useState<any[]>([]),[areas,setAreas]=useState<any[]>([]),[methods,setMethods]=useState<any[]>([]),[rules,setRules]=useState<any[]>([]);
 const[msg,setMsg]=useState(''),[busy,setBusy]=useState(false);
 const[p,setP]=useState({name_ar:'',name_en:'',slug:'',description_ar:'',description_en:'',product_type:'physical',brand_name:'',status:'draft'});
 const[v,setV]=useState({product_id:'',sku:'',name_ar:'',name_en:'',status:'active'});
 const[pr,setPr]=useState({product_variant_id:'',amount:'',currency:'EGP',channel:'storefront',priority:'0'});
 const[adj,setAdj]=useState({item_id:'',quantity:'',reason:''});
 const[c,setC]=useState({code:'',name:'',is_active:true});
 const[a,setA]=useState({governorate:'',area:'',postal_code:'',status:'active'});
 const[m,setM]=useState({code:'',name_ar:'',name_en:'',status:'active'});
 const[r,setR]=useState({code:'',name_ar:'',name_en:'',price:'0',currency:'EGP',eta_min_days:'',eta_max_days:'',free_shipping_threshold:'',priority:'0',status:'draft'});
 async function load(){setMsg('');const[pp,vv,px,ii,cc,aa,mm,rr]=await Promise.all([
  catalog.from('products').select('id,name_ar,name_en,slug,status,product_type').order('created_at',{ascending:false}).limit(100),
  catalog.from('product_variants').select('id,product_id,sku,name_ar,name_en,status').order('created_at',{ascending:false}).limit(100),
  catalog.from('prices').select('id,product_variant_id,amount,currency,channel,priority,is_active').order('created_at',{ascending:false}).limit(100),
  inventory.from('items').select('id,product_variant_id,location_id,on_hand,reserved,reorder_point').order('updated_at',{ascending:false}).limit(100),
  logistics.from('carriers').select('*').order('created_at',{ascending:false}).limit(100),
  logistics.from('shipping_areas').select('*').order('governorate').limit(100),
  logistics.from('shipping_methods').select('*').order('code').limit(100),
  logistics.from('shipping_rules').select('*').order('priority').limit(100)
 ]);const failed=[pp,vv,px,ii,cc,aa,mm,rr].find(x=>x.error);if(failed){setMsg(failed.error?.message||'تعذر تحميل بيانات الإدارة');return}setProducts(pp.data||[]);setVariants(vv.data||[]);setPrices(px.data||[]);setItems(ii.data||[]);setCarriers(cc.data||[]);setAreas(aa.data||[]);setMethods(mm.data||[]);setRules(rr.data||[])}
 useEffect(()=>{load()},[]);
 async function run(fn:()=>any,ok:string){setBusy(true);setMsg('');try{const x=await fn();if(x?.error)throw new Error(x.error.message);setMsg(ok);await load();await onChanged()}catch(x:any){setMsg(x?.message||'حدث خطأ')}finally{setBusy(false)}}
 const input=(value:string,onChange:(v:string)=>void,placeholder:string)=><input value={value} onChange={e=>onChange(e.target.value)} placeholder={placeholder}/>;
 return <section className="panel">{msg&&<div className={msg.startsWith('تم')?'ok':'error'}>{msg}</div>}<div className="admin-grid">
  <div className="card"><h3>إضافة منتج</h3>{input(p.name_ar,x=>setP({...p,name_ar:x}),'اسم المنتج بالعربي')}{input(p.name_en,x=>setP({...p,name_en:x}),'Product name')}{input(p.slug,x=>setP({...p,slug:x}),'slug')}{input(p.description_ar,x=>setP({...p,description_ar:x}),'الوصف العربي')}<select value={p.status} onChange={e=>setP({...p,status:e.target.value})}><option value="draft">Draft</option><option value="active">Active</option></select><button disabled={busy} onClick={()=>{if(!p.name_ar.trim()||!p.slug.trim()){setMsg('اسم المنتج والـslug مطلوبان');return}if(products.some(x=>x.slug===p.slug.trim())){setMsg('الـslug مستخدم بالفعل');return}run(()=>catalog.from('products').insert({...p,slug:p.slug.trim()}),'تم إنشاء المنتج')}}>حفظ المنتج</button></div>
  <div className="card"><h3>إضافة Variant</h3><select value={v.product_id} onChange={e=>setV({...v,product_id:e.target.value})}><option value="">اختر المنتج</option>{products.map(x=><option key={x.id} value={x.id}>{x.name_ar}</option>)}</select>{input(v.sku,x=>setV({...v,sku:x}),'SKU')}{input(v.name_ar,x=>setV({...v,name_ar:x}),'اسم الـVariant')}{input(v.name_en,x=>setV({...v,name_en:x}),'Variant name')}<button disabled={busy||!v.product_id} onClick={()=>run(()=>catalog.from('product_variants').insert(v),'تم إنشاء الـVariant')}>حفظ Variant</button></div>
  <div className="card"><h3>إضافة سعر</h3><select value={pr.product_variant_id} onChange={e=>setPr({...pr,product_variant_id:e.target.value})}><option value="">اختر Variant</option>{variants.map(x=><option key={x.id} value={x.id}>{x.sku}</option>)}</select>{input(pr.amount,x=>setPr({...pr,amount:x}),'السعر')}<select value={pr.currency} onChange={e=>setPr({...pr,currency:e.target.value})}><option>EGP</option><option>USD</option></select><button disabled={busy||!pr.product_variant_id} onClick={()=>{if(!pr.amount.trim()||!/^-?\d+(?:\.\d{1,4})?$/.test(pr.amount.trim())){setMsg('السعر يجب أن يكون رقمًا صحيحًا حتى 4 منازل عشرية');return}run(()=>catalog.from('prices').insert({...pr,amount:pr.amount.trim(),priority:Number(pr.priority)}),'تم حفظ السعر')}}>حفظ السعر</button></div>
  <div className="card"><h3>تعديل المخزون</h3><select value={adj.item_id} onChange={e=>setAdj({...adj,item_id:e.target.value})}><option value="">اختر عنصر المخزون</option>{items.map(x=><option key={x.id} value={x.id}>{x.product_variant_id} · متاح {Number(x.on_hand)-Number(x.reserved)}</option>)}</select>{input(adj.quantity,x=>setAdj({...adj,quantity:x}),'كمية (+ للإضافة / - للخصم)')}{input(adj.reason,x=>setAdj({...adj,reason:x}),'سبب التعديل')}<button disabled={busy||!adj.item_id} onClick={()=>{if(!adj.quantity.trim()||!/^[-+]?\d+(?:\.\d+)?$/.test(adj.quantity.trim())||Number(adj.quantity)===0){setMsg('كمية التعديل يجب أن تكون رقمًا غير صفري');return}run(()=>inventory.rpc('adjust_stock',{p_item_id:adj.item_id,p_quantity:adj.quantity,p_adjustment_type:Number(adj.quantity)>=0?'receive':'adjust',p_reason:adj.reason||'Admin dashboard adjustment'}),'تم تعديل المخزون وتسجيل الحركة')}}>تنفيذ التعديل</button></div>
  <div className="card"><h3>شركة شحن</h3>{input(c.code,x=>setC({...c,code:x}),'code')}{input(c.name,x=>setC({...c,name:x}),'اسم الشركة')}<button disabled={busy} onClick={()=>run(()=>logistics.from('carriers').insert(c),'تمت إضافة شركة الشحن')}>إضافة شركة</button></div>
  <div className="card"><h3>منطقة شحن</h3>{input(a.governorate,x=>setA({...a,governorate:x}),'المحافظة')}{input(a.area,x=>setA({...a,area:x}),'المنطقة')}{input(a.postal_code,x=>setA({...a,postal_code:x}),'Postal code')}<button disabled={busy} onClick={()=>run(()=>logistics.from('shipping_areas').insert(a),'تمت إضافة المنطقة')}>إضافة منطقة</button></div>
  <div className="card"><h3>طريقة شحن</h3>{input(m.code,x=>setM({...m,code:x}),'code')}{input(m.name_ar,x=>setM({...m,name_ar:x}),'الاسم العربي')}{input(m.name_en,x=>setM({...m,name_en:x}),'English name')}<button disabled={busy} onClick={()=>run(()=>logistics.from('shipping_methods').insert(m),'تمت إضافة طريقة الشحن')}>إضافة طريقة</button></div>
  <div className="card"><h3>قاعدة شحن</h3>{input(r.code,x=>setR({...r,code:x}),'code')}{input(r.name_ar,x=>setR({...r,name_ar:x}),'اسم القاعدة')}{input(r.price,x=>setR({...r,price:x}),'السعر')}{input(r.eta_min_days,x=>setR({...r,eta_min_days:x}),'أقل مدة بالأيام')}{input(r.eta_max_days,x=>setR({...r,eta_max_days:x}),'أقصى مدة بالأيام')}<button disabled={busy} onClick={()=>run(()=>logistics.from('shipping_rules').insert({...r,price:r.price,eta_min_days:r.eta_min_days||null,eta_max_days:r.eta_max_days||null,priority:Number(r.priority),conditions:{}}),'تمت إضافة قاعدة الشحن')}>إضافة قاعدة</button></div>
 </div><div className="muted">الكتالوج والشحن يعتمدان على صلاحيات الموظف في RBAC. لا توجد أي كتابة عامة أو service-role في المتصفح.</div></section>
}
