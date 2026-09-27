import React,{useEffect,useState}from'react';
import{createRoot}from'react-dom/client';
import{createClient}from'@supabase/supabase-js';
import'./styles.css';
const db=createClient(import.meta.env.VITE_SUPABASE_URL,import.meta.env.VITE_SUPABASE_ANON_KEY);
type Order={id:string;order_number:string;status:string;currency:string;grand_total:number;created_at:string};
const transitions:Record<string,string[]>={
 pending:['payment_pending','cancelled'],payment_pending:['paid','cancelled'],paid:['processing','cancelled'],processing:['shipped','cancelled'],shipped:['delivered','returned'],delivered:['returned']
};
function App(){
 const[s,setS]=useState({products:0,variants:0,orders:0}),[orders,setOrders]=useState<Order[]>([]),[e,setE]=useState(''),[busy,setBusy]=useState('');
 async function load(){setE('');const[p,v,o]=await Promise.all([db.from('catalog.products').select('*',{count:'exact',head:true}),db.from('catalog.product_variants').select('*',{count:'exact',head:true}),db.from('commerce.orders').select('id,order_number,status,currency,grand_total,created_at').order('created_at',{ascending:false}).limit(50)]);const bad=[p,v,o].find(r=>r.error);if(bad){setE(bad.error!.message);return}setS({products:p.count||0,variants:v.count||0,orders:o.data?.length||0});setOrders((o.data||[]) as Order[])}
 useEffect(()=>{load()},[]);
 async function transition(id:string,status:string){setBusy(id+status);setE('');const{error}=await db.rpc('transition_order',{p_order_id:id,p_to_status:status,p_reason:'admin_dashboard'});if(error)setE(error.message);else await load();setBusy('')}
 return <main dir="rtl"><header><div><span>SIWA OPERATIONS</span><h1>لوحة التشغيل</h1><p>كتالوج وطلبات ودورة حالة الطلب متصلة مباشرة بـ Supabase.</p></div><button onClick={load}>تحديث</button></header>
 {e&&<div className="error">{e}</div>}
 <section className="stats"><div><b>{s.products}</b><span>منتج</span></div><div><b>{s.variants}</b><span>نسخة / SKU</span></div><div><b>{s.orders}</b><span>طلب</span></div></section>
 <section className="panel"><div className="panel-head"><h2>الطلبات</h2><span>آخر 50 طلب</span></div>{orders.length===0?<p className="muted">لا توجد طلبات بعد.</p>:<div className="orders">{orders.map(o=><article className="order" key={o.id}><div><b>{o.order_number}</b><small>{new Date(o.created_at).toLocaleString('ar-EG')}</small></div><div><strong>{Number(o.grand_total).toFixed(2)} {o.currency}</strong><span className="status">{o.status}</span></div><div className="actions">{(transitions[o.status]||[]).map(next=><button key={next} disabled={!!busy} onClick={()=>transition(o.id,next)}>{busy===o.id+next?'...':next}</button>)}</div></article>)}</div>}</section>
 <section className="panel"><h2>قواعد التشغيل الحالية</h2><p className="muted">الانتقال يتم عبر الدالة المؤمّنة في قاعدة البيانات، وليس بتعديل الحالة مباشرة من الواجهة.</p></section>
 </main>}
createRoot(document.getElementById('root')!).render(<App/>);