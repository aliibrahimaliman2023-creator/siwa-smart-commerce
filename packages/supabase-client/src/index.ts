import { createClient } from '@supabase/supabase-js';
export function getSupabase(){
 const url=import.meta.env.VITE_SUPABASE_URL; const key=import.meta.env.VITE_SUPABASE_ANON_KEY;
 if(!url||!key) throw new Error('Missing VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY');
 return createClient(url,key);
}