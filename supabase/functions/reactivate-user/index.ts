import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(JSON.stringify({ status: 'ok' }), { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing Authorization header' }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
    const supabaseAnonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';

    // Caller client enforcing permissions via auth header
    const supabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: authError } = await supabaseClient.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized: Invalid caller session' }), {
        status: 401,
        headers: corsHeaders,
      });
    }

    const body = await req.json();
    const { user_id, reason } = body;

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'Missing required user_id parameter' }), {
        status: 400,
        headers: corsHeaders,
      });
    }

    // Step 1: Call admin_reactivate_user_account via caller's client to enforce Owner/RBAC rules
    const { data: rpcData, error: rpcError } = await supabaseClient.rpc('admin_reactivate_user_account', {
      p_user_id: user_id,
      p_reason: reason ?? 'Account reactivated by authorized administrator',
    });

    if (rpcError) {
      return new Response(JSON.stringify({ error: rpcError.message }), {
        status: 403,
        headers: corsHeaders,
      });
    }

    // Step 2: Unban in auth.users ONLY AFTER the RPC succeeds
    const supabaseAdmin = createClient(supabaseUrl, supabaseServiceKey);
    const { error: adminError } = await supabaseAdmin.auth.admin.updateUserById(user_id, {
      ban_duration: 'none',
    });

    if (adminError) {
      // Revert database state through matching RPC so DB and auth never disagree
      await supabaseClient.rpc('deactivate_user_account', {
        p_user_id: user_id,
        p_reason: 'Automatic rollback: Auth unban sync failed (' + adminError.message + ')',
      });

      return new Response(JSON.stringify({
        error: 'Failed to synchronize authentication unban state. Database reactivation was safely rolled back.',
        details: adminError.message,
      }), {
        status: 502,
        headers: corsHeaders,
      });
    }

    return new Response(JSON.stringify({
      success: true,
      action: 'reactivated_and_unbanned',
      user_id,
      rpcData,
    }), {
      status: 200,
      headers: corsHeaders,
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message ?? 'Internal Server Error' }), {
      status: 500,
      headers: corsHeaders,
    });
  }
});
