import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    // Caller client to enforce user RBAC permissions
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized: Invalid caller session' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const { user_id, action = 'deactivate', reason } = body;

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'Missing required user_id parameter' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    let rpcData: any;
    let isBan = true;

    if (action === 'reactivate') {
      isBan = false;
      const { data, error: rpcError } = await supabaseClient.rpc('admin_reactivate_user_account', {
        p_user_id: user_id,
        p_reason: reason ?? 'Reactivated by administrative authority',
      });
      if (rpcError) {
        return new Response(JSON.stringify({ error: rpcError.message }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      rpcData = data;
    } else {
      isBan = true;
      const { data, error: rpcError } = await supabaseClient.rpc('deactivate_user_account', {
        p_user_id: user_id,
        p_reason: reason ?? 'Deactivated by administrative authority',
      });
      if (rpcError) {
        return new Response(JSON.stringify({ error: rpcError.message }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
      rpcData = data;
    }

    // Service role admin client to update auth.users ban_duration
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const { error: adminError } = await supabaseAdmin.auth.admin.updateUserById(user_id, {
      ban_duration: isBan ? '876000h' : 'none',
    });

    if (adminError) {
      return new Response(JSON.stringify({
        warning: 'Database account status updated, but auth ban sync failed.',
        admin_error: adminError.message,
        rpcData,
      }), {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({
      success: true,
      action: isBan ? 'deactivated_and_banned' : 'reactivated_and_unbanned',
      user_id,
      rpcData,
    }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message ?? 'Internal Server Error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
